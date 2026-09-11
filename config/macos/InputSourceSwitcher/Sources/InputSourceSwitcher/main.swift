import AppKit
import Carbon
import Foundation
import InputSourcePolicy

private enum HotKey: UInt32 {
    case primary = 1
    case japanese = 2

    var virtualKeyCode: UInt32 {
        switch self {
        case .primary:
            return UInt32(kVK_F18)
        case .japanese:
            return UInt32(kVK_ANSI_1)
        }
    }

    var modifiers: UInt32 {
        self == .japanese ? UInt32(optionKey) : 0
    }
}

private enum SwitcherError: Error, CustomStringConvertible {
    case missingInputSource(String)
    case carbonCall(String, OSStatus)

    var description: String {
        switch self {
        case let .missingInputSource(sourceID):
            return "required input source is not enabled: \(sourceID)"
        case let .carbonCall(name, status):
            return "\(name) failed with OSStatus \(status)"
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

    /// Enables everything the mode declares, then removes any other enabled
    /// keyboard source. Enabling runs first so macOS always has a source to fall
    /// back on when the previous selection is disabled.
    static func applySources(mode: InputMode) throws -> [String] {
        let installedSources = sourcesByID()

        for sourceID in InputSourcePolicy.requiredSourceIDs(for: mode) {
            guard let source = installedSources[sourceID] else {
                throw SwitcherError.missingInputSource(sourceID)
            }
            guard !isEnabled(source) else {
                continue
            }
            let status = TISEnableInputSource(source)
            guard status == noErr else {
                throw SwitcherError.carbonCall("TISEnableInputSource", status)
            }
        }

        let removable = InputSourcePolicy.sourceIDsToDisable(
            enabledKeyboardSourceIDs: enabledKeyboardSourceIDs(),
            mode: mode
        )

        for sourceID in removable {
            guard let source = installedSources[sourceID] else {
                continue
            }
            let status = TISDisableInputSource(source)
            guard status == noErr else {
                throw SwitcherError.carbonCall("TISDisableInputSource", status)
            }
        }
        return removable
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

private final class InputSourceStore {
    private let sourcesByID: [String: TISInputSource]

    init(mode: InputMode) throws {
        let requestedIDs = Set(InputSourcePolicy.selectableSourceIDs(for: mode))
        let allSources = InputSourceCatalog.sourcesByID()
        var sourcesByID: [String: TISInputSource] = [:]

        for (sourceID, source) in allSources {
            guard requestedIDs.contains(sourceID),
                  InputSourceCatalog.isEnabled(source) else {
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

    func select(sourceID: String) throws {
        guard let source = sourcesByID[sourceID] else {
            throw SwitcherError.missingInputSource(sourceID)
        }
        let status = TISSelectInputSource(source)
        guard status == noErr else {
            throw SwitcherError.carbonCall("TISSelectInputSource", status)
        }
    }
}

private final class InputSourceSwitcher {
    private static let hotKeySignature: OSType = 0x49535357 // ISSW

    private let mode: InputMode
    private let sourceStore: InputSourceStore
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var pressedHotKeys: Set<HotKey> = []

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

        for hotKey in (mode.includesJapanese ? [HotKey.primary, .japanese] : [.primary]) {
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
    }

    func printCheck() {
        print("mode=\(mode.rawValue)")
        print("current=\(sourceStore.currentSourceID)")
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

        switch GetEventKind(event) {
        case UInt32(kEventHotKeyPressed):
            guard pressedHotKeys.insert(hotKey).inserted else {
                return noErr
            }
            perform(hotKey)
        case UInt32(kEventHotKeyReleased):
            pressedHotKeys.remove(hotKey)
        default:
            return OSStatus(eventNotHandledErr)
        }
        return noErr
    }

    private func perform(_ hotKey: HotKey) {
        do {
            switch hotKey {
            case .primary:
                let target = InputSourcePolicy.primaryKeyTarget(
                    currentSourceID: sourceStore.currentSourceID
                )
                try sourceStore.select(sourceID: target.rawValue)
            case .japanese:
                try sourceStore.select(sourceID: InputSourcePolicy.japaneseSourceID)
            }
        } catch {
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
