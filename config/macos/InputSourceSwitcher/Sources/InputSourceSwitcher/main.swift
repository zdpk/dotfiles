import AppKit
import ApplicationServices
import Carbon
import Foundation
import InputSourcePolicy
import OSLog

private let diagnostics = Logger(
    subsystem: "dev.undervars.dotfiles.input-source-switcher",
    category: "Switching"
)

private enum HotKey: UInt32 {
    case primary = 1

    var virtualKeyCode: UInt32 { UInt32(kVK_F18) }
    var modifiers: UInt32 { 0 }
    var name: String { "primary" }
}

private enum SwitcherError: Error, CustomStringConvertible {
    case missingInputSource(String)
    case carbonCall(String, OSStatus)
    case sourceSetup(String)

    var description: String {
        switch self {
        case let .missingInputSource(sourceID):
            return "required input source is not enabled: \(sourceID)"
        case let .carbonCall(name, status):
            return "\(name) failed with OSStatus \(status)"
        case let .sourceSetup(message):
            return message
        }
    }
}

private enum InputSourceCatalog {
    static func sourcesByID() -> [String: TISInputSource] {
        let allSources = TISCreateInputSourceList(nil, true).takeRetainedValue()
            as! [TISInputSource]
        var sourcesByID: [String: TISInputSource] = [:]

        for source in allSources {
            guard let sourceID = stringProperty(
                source,
                key: kTISPropertyInputSourceID
            ) else {
                continue
            }
            sourcesByID[sourceID] = source
        }
        return sourcesByID
    }

    /// Palette sources such as the character viewer live in their own category
    /// and are never part of the keyboard rotation, so they stay untouched.
    static func enabledKeyboardSourceIDs() -> [String] {
        let allSources = TISCreateInputSourceList(nil, false).takeRetainedValue()
            as! [TISInputSource]
        var sourceIDs: [String] = []

        for source in allSources {
            guard isKeyboardSource(source),
                  isEnabled(source),
                  let sourceID = stringProperty(
                      source,
                      key: kTISPropertyInputSourceID
                  ) else {
                continue
            }
            sourceIDs.append(sourceID)
        }
        return sourceIDs
    }

    /// TIS caches its includeAll catalog and can return inactive modes in a
    /// later includeAll=false query in the same process. Use a fresh client for
    /// each setup operation; the resident switching path never spawns processes.
    static func applySources(mode: InputMode) throws -> [String] {
        for sourceID in InputSourcePolicy.requiredSourceIDs(for: mode) {
            _ = try sourceTool(["_source", "enable", sourceID])
        }
        let data = Data(try sourceTool(["_source", "list"]).utf8)
        let enabled = try JSONDecoder().decode([String].self, from: data)
        let removable = InputSourcePolicy.sourceIDsToDisable(
            enabledKeyboardSourceIDs: enabled,
            mode: mode
        )
        for sourceID in removable {
            _ = try sourceTool(["_source", "disable", sourceID])
        }
        return removable
    }

    private static func sourceTool(_ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = Bundle.main.executableURL
        task.arguments = arguments
        let output = Pipe()
        task.standardOutput = output
        try task.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw SwitcherError.sourceSetup("input-source setup failed: \(arguments.joined(separator: " "))")
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func setEnabled(_ sourceID: String, enabled: Bool) throws {
        // Capture effective sources BEFORE asking TIS for its includeAll list.
        let active = Set(enabledKeyboardSourceIDs())
        guard let source = sourcesByID()[sourceID], isKeyboardSource(source) else {
            throw SwitcherError.missingInputSource(sourceID)
        }
        guard active.contains(sourceID) != enabled else { return }
        let status = enabled ? TISEnableInputSource(source) : TISDisableInputSource(source)
        guard status == noErr else {
            throw SwitcherError.carbonCall(enabled ? "TISEnableInputSource" : "TISDisableInputSource", status)
        }
    }

    static func stringProperty(
        _ source: TISInputSource,
        key: CFString
    ) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    static func isEnabled(_ source: TISInputSource) -> Bool {
        booleanProperty(source, key: kTISPropertyInputSourceIsEnabled)
    }

    static func isKeyboardSource(_ source: TISInputSource) -> Bool {
        stringProperty(source, key: kTISPropertyInputSourceCategory)
            == (kTISCategoryKeyboardInputSource as String)
    }

    static func booleanProperty(
        _ source: TISInputSource,
        key: CFString
    ) -> Bool {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return false
        }
        return Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue()
            == kCFBooleanTrue
    }
}

private extension InputSourceCatalog {
    static var currentKeyboardLayoutID: String {
        let layout = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        return stringProperty(layout, key: kTISPropertyInputSourceID) ?? ""
    }
    static var currentLayoutOverrideID: String {
        guard let layout = TISCopyInputMethodKeyboardLayoutOverride()?.takeRetainedValue() else { return "none" }
        return stringProperty(layout, key: kTISPropertyInputSourceID) ?? ""
    }
}

private final class InputSourceStore {
    private let sourcesByID: [String: TISInputSource]

    init(mode: InputMode) throws {
        let requestedIDs = Set(InputSourcePolicy.selectableSourceIDs(for: mode))
        let active = Set(InputSourceCatalog.enabledKeyboardSourceIDs())
        let allSources = InputSourceCatalog.sourcesByID()
        var sourcesByID: [String: TISInputSource] = [:]

        for (sourceID, source) in allSources {
            guard requestedIDs.contains(sourceID),
                  active.contains(sourceID) else {
                continue
            }
            sourcesByID[sourceID] = source
        }

        for sourceID in requestedIDs where sourcesByID[sourceID] == nil {
            throw SwitcherError.missingInputSource(sourceID)
        }
        self.sourcesByID = sourcesByID
    }

    var currentSourceID: String {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return InputSourceCatalog.stringProperty(
            source,
            key: kTISPropertyInputSourceID
        ) ?? ""
    }

    func localizedName(sourceID: String) throws -> String {
        guard let source = sourcesByID[sourceID],
              let name = InputSourceCatalog.stringProperty(source, key: kTISPropertyLocalizedName) else {
            throw SwitcherError.missingInputSource(sourceID)
        }
        return name
    }
}

private final class InputSourceSwitcher {
    private static let hotKeySignature: OSType = 0x49535357 // ISSW

    private let mode: InputMode
    private let sourceStore: InputSourceStore
    private let nativeMenu = NativeInputMenu()
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var pressedHotKeys: [HotKey: UInt64] = [:]
    private var eventSequence = 0
    private var sourceObserver: NSObjectProtocol?

    init(mode: InputMode) throws {
        self.mode = mode
        sourceStore = try InputSourceStore(mode: mode)
    }

    func installHotKeys() throws {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            ),
        ]
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let switcher = Unmanaged<InputSourceSwitcher>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return switcher.handle(event: event)
            },
            eventTypes.count,
            &eventTypes,
            userData,
            nil
        )
        guard handlerStatus == noErr else {
            throw SwitcherError.carbonCall("InstallEventHandler", handlerStatus)
        }

        // Globe/Fn stays with macOS and cycles the enabled sources. The helper
        // owns only F18 (right Command), so Option+1 remains an ordinary chord.
        for hotKey in [HotKey.primary] {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(
                signature: Self.hotKeySignature,
                id: hotKey.rawValue
            )
            let status = RegisterEventHotKey(
                hotKey.virtualKeyCode,
                hotKey.modifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &hotKeyRef
            )
            guard status == noErr, let hotKeyRef else {
                throw SwitcherError.carbonCall("RegisterEventHotKey", status)
            }
            hotKeyRefs.append(hotKeyRef)
        }

        // Observe macOS acknowledgements without polling or retrying a switch.
        let menu = nativeMenu
        sourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { _ in
            let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            let current = InputSourceCatalog.stringProperty(
                source, key: kTISPropertyInputSourceID
            ) ?? ""
            let layout = InputSourceCatalog.currentKeyboardLayoutID
            diagnostics.notice("source_changed current=\(current, privacy: .public) layout=\(layout, privacy: .public)")
            menu.prepare()
        }
        nativeMenu.prepare()
        diagnostics.notice("ready mode=\(self.mode.rawValue, privacy: .public) hotkeys=\(self.hotKeyRefs.count) mechanism=native_input_menu accessibility=\(AXIsProcessTrusted()) secure=\(IsSecureEventInputEnabled())")
    }

    func printCheck() {
        print("mode=\(mode.rawValue)")
        print("current=\(sourceStore.currentSourceID)")
        print("layout=\(InputSourceCatalog.currentKeyboardLayoutID)")
        print("inputMethodLayoutOverride=\(InputSourceCatalog.currentLayoutOverrideID)")
        print("secureInput=\(IsSecureEventInputEnabled())")
        print("selectionMechanism=native_input_menu")
        print("invokingProcessAccessibility=\(AXIsProcessTrusted())")
        print("modifierFlags=\(CGEventSource.flagsState(.combinedSessionState).rawValue)")
        print("english=\(PrimaryInputSource.english.rawValue)")
        print("korean=\(PrimaryInputSource.korean.rawValue)")
        if mode.includesJapanese {
            print("japanese=\(InputSourcePolicy.japaneseSourceID)")
        }
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr,
              hotKeyID.signature == Self.hotKeySignature,
              let hotKey = HotKey(rawValue: hotKeyID.id) else {
            return OSStatus(eventNotHandledErr)
        }

        let receivedAt = DispatchTime.now().uptimeNanoseconds
        let queueUS = Int(max(0, GetCurrentEventTime() - GetEventTime(event)) * 1_000_000)
        eventSequence += 1
        let sequence = eventSequence

        switch GetEventKind(event) {
        case UInt32(kEventHotKeyPressed):
            if let pressedAt = pressedHotKeys[hotKey] {
                let heldMS = (receivedAt - pressedAt) / 1_000_000
                diagnostics.notice("down_ignored seq=\(sequence) key=\(hotKey.name, privacy: .public) reason=already_pressed held_ms=\(heldMS) queue_us=\(queueUS) flags=\(CGEventSource.flagsState(.combinedSessionState).rawValue) secure=\(IsSecureEventInputEnabled())")
                return noErr
            }
            pressedHotKeys[hotKey] = receivedAt
            perform(hotKey, sequence: sequence, receivedAt: receivedAt, queueUS: queueUS)
        case UInt32(kEventHotKeyReleased):
            let pressedAt = pressedHotKeys.removeValue(forKey: hotKey)
            let heldMS = pressedAt.map { Int((receivedAt - $0) / 1_000_000) } ?? -1
            diagnostics.notice("up seq=\(sequence) key=\(hotKey.name, privacy: .public) held_ms=\(heldMS) queue_us=\(queueUS)")
        default:
            return OSStatus(eventNotHandledErr)
        }
        return noErr
    }

    private func perform(_ hotKey: HotKey, sequence: Int, receivedAt: UInt64, queueUS: Int) {
        let before = sourceStore.currentSourceID
        let target = InputSourcePolicy.primaryKeyTarget(currentSourceID: before)
        let selectionStarted = DispatchTime.now().uptimeNanoseconds
        do {
            guard let foregroundPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
                throw NativeInputMenu.Failure.unavailable("no foreground application")
            }
            try nativeMenu.select(
                localizedName: sourceStore.localizedName(sourceID: target.rawValue),
                foregroundPID: foregroundPID
            )
            let selectionFinished = DispatchTime.now().uptimeNanoseconds
            let apiUS = (selectionFinished - selectionStarted) / 1_000
            let handlerUS = (selectionFinished - receivedAt) / 1_000
            // Readback and logging happen after the immediate selection. A
            // matching ID is not proof that the front app accepted composition.
            let after = sourceStore.currentSourceID
            let layout = InputSourceCatalog.currentKeyboardLayoutID
            let matched = InputSourcePolicy.selectionMatches(target, sourceID: after, layoutID: layout)
            diagnostics.notice("switch seq=\(sequence) key=\(hotKey.name, privacy: .public) before=\(before, privacy: .public) target=\(target.rawValue, privacy: .public) after=\(after, privacy: .public) layout=\(layout, privacy: .public) matched=\(matched) api_us=\(apiUS) handler_us=\(handlerUS) queue_us=\(queueUS) flags=\(CGEventSource.flagsState(.combinedSessionState).rawValue) secure=\(IsSecureEventInputEnabled())")
        } catch {
            diagnostics.error("switch_failed seq=\(sequence) key=\(hotKey.name, privacy: .public) before=\(before, privacy: .public) target=\(target.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
            FileHandle.standardError.write(
                Data("input-source-switcher: \(error)\n".utf8)
            )
        }
    }
}

private func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data("input-source-switcher: \(message)\n".utf8))
    exit(code)
}

private func parseMode(_ rawValue: String) -> InputMode {
    guard let mode = InputMode(rawValue: rawValue) else {
        fail(
            "unknown input mode: \(rawValue) (expected "
                + InputMode.allCases.map(\.rawValue).joined(separator: " or ")
                + ")",
            code: EX_USAGE
        )
    }
    return mode
}

private let usage = """
usage: input-source-switcher [--apply-sources <mode>] [--check [<mode>]]
       input-source-switcher [--run <mode>]  run the resident helper
       modes: \(InputMode.allCases.map(\.rawValue).joined(separator: ", "))
"""

private func savedMode() -> InputMode {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/dotfiles/input-mode")
    guard FileManager.default.fileExists(atPath: path.path) else { return .koreanEnglish }
    guard let value = try? String(contentsOf: path, encoding: .utf8) else {
        fail("cannot read input mode: \(path.path)", code: EX_CONFIG)
    }
    return parseMode(value.trimmingCharacters(in: .whitespacesAndNewlines))
}
let arguments = Array(CommandLine.arguments.dropFirst())

do {
    switch arguments.first {
    case "_source":
        if arguments == ["_source", "list"] {
            let data = try JSONEncoder().encode(InputSourceCatalog.enabledKeyboardSourceIDs())
            print(String(decoding: data, as: UTF8.self))
        } else if arguments.count == 3, ["enable", "disable"].contains(arguments[1]) {
            try InputSourceCatalog.setEnabled(arguments[2], enabled: arguments[1] == "enable")
        } else {
            fail(usage, code: EX_USAGE)
        }
        exit(EXIT_SUCCESS)

    case "--apply-sources":
        guard arguments.count == 2 else {
            fail(usage, code: EX_USAGE)
        }
        let mode = parseMode(arguments[1])
        let disabled = try InputSourceCatalog.applySources(mode: mode)
        for sourceID in disabled {
            print("disabled=\(sourceID)")
        }
        try InputSourceSwitcher(mode: mode).printCheck()
        exit(EXIT_SUCCESS)

    case "--check":
        guard arguments.count <= 2 else {
            fail(usage, code: EX_USAGE)
        }
        let mode = arguments.count == 2
            ? parseMode(arguments[1])
            : savedMode()
        try InputSourceSwitcher(mode: mode).printCheck()
        exit(EXIT_SUCCESS)

    case nil, "--run":
        guard arguments.isEmpty || arguments.count == 2 else {
            fail(usage, code: EX_USAGE)
        }
        let mode = arguments.isEmpty ? savedMode() : parseMode(arguments[1])
        let switcher = try InputSourceSwitcher(mode: mode)
        try switcher.installHotKeys()
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.run()

    default:
        fail(usage, code: EX_USAGE)
    }
} catch {
    fail("\(error)", code: EXIT_FAILURE)
}
