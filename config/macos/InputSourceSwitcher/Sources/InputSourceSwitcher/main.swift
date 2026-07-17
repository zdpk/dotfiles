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
            return UInt32(kVK_F19)
        }
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

private final class InputSourceStore {
    private let sourcesByID: [String: TISInputSource]

    init() throws {
        let requestedIDs = Set(
            PrimaryInputSource.allCases.map(\.rawValue)
                + [InputSourcePolicy.japaneseSourceID]
        )
        let allSources = TISCreateInputSourceList(nil, true).takeRetainedValue()
            as! [TISInputSource]
        var sourcesByID: [String: TISInputSource] = [:]

        for source in allSources {
            guard let sourceID = Self.stringProperty(
                source,
                key: kTISPropertyInputSourceID
            ), requestedIDs.contains(sourceID), Self.isEnabled(source) else {
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
        return Self.stringProperty(source, key: kTISPropertyInputSourceID) ?? ""
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

    private static func stringProperty(
        _ source: TISInputSource,
        key: CFString
    ) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    private static func isEnabled(_ source: TISInputSource) -> Bool {
        guard let value = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceIsEnabled
        ) else {
            return false
        }
        return Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue()
            == kCFBooleanTrue
    }
}

private final class InputSourceSwitcher {
    private static let hotKeySignature: OSType = 0x49535357 // ISSW
    private static let defaultsSuite = "dev.undervars.input-source-switcher"
    private static let lastPrimaryKey = "lastPrimarySourceID"

    private let sourceStore: InputSourceStore
    private let defaults: UserDefaults
    private var lastPrimary: PrimaryInputSource
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var pressedHotKeys: Set<HotKey> = []

    init() throws {
        sourceStore = try InputSourceStore()
        defaults = UserDefaults(suiteName: Self.defaultsSuite)!
        lastPrimary = defaults.string(forKey: Self.lastPrimaryKey)
            .flatMap(PrimaryInputSource.init(rawValue:)) ?? .english
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

        for hotKey in [HotKey.primary, .japanese] {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(
                signature: Self.hotKeySignature,
                id: hotKey.rawValue
            )
            let status = RegisterEventHotKey(
                hotKey.virtualKeyCode,
                0,
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
        print("current=\(sourceStore.currentSourceID)")
        print("lastPrimary=\(lastPrimary.rawValue)")
        print("english=\(PrimaryInputSource.english.rawValue)")
        print("korean=\(PrimaryInputSource.korean.rawValue)")
        print("japanese=\(InputSourcePolicy.japaneseSourceID)")
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
                    currentSourceID: sourceStore.currentSourceID,
                    lastPrimary: lastPrimary
                )
                try sourceStore.select(sourceID: target.rawValue)
                remember(target)
            case .japanese:
                let remembered = InputSourcePolicy.primaryToRememberBeforeJapanese(
                    currentSourceID: sourceStore.currentSourceID,
                    lastPrimary: lastPrimary
                )
                remember(remembered)
                try sourceStore.select(sourceID: InputSourcePolicy.japaneseSourceID)
            }
        } catch {
            FileHandle.standardError.write(
                Data("input-source-switcher: \(error)\n".utf8)
            )
        }
    }

    private func remember(_ source: PrimaryInputSource) {
        guard source != lastPrimary else {
            return
        }
        lastPrimary = source
        defaults.set(source.rawValue, forKey: Self.lastPrimaryKey)
    }
}

do {
    let switcher = try InputSourceSwitcher()
    if CommandLine.arguments.dropFirst() == ["--check"] {
        switcher.printCheck()
        exit(EXIT_SUCCESS)
    }
    guard CommandLine.arguments.count == 1 else {
        FileHandle.standardError.write(
            Data("usage: input-source-switcher [--check]\n".utf8)
        )
        exit(EX_USAGE)
    }
    try switcher.installHotKeys()
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.run()
} catch {
    FileHandle.standardError.write(
        Data("input-source-switcher: \(error)\n".utf8)
    )
    exit(EXIT_FAILURE)
}
