import AppKit
import ApplicationServices
import InputSourcePolicy

/// Use the same activation path as choosing a source from the macOS input menu.
/// TISSelectInputSource alone can leave the front app translating Korean as ABC.
final class NativeInputMenu: Sendable {
    enum Failure: Error, CustomStringConvertible {
        case unavailable(String)
        case action(AXError)

        var description: String {
            switch self {
            case let .unavailable(reason): return reason
            case let .action(result): return "input-menu AXPress failed: \(result.rawValue)"
            }
        }
    }

    init() {
        // Bound IPC waits on every element, including freshly returned children.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)
    }

    /// Reading the closed menu starts macOS's lazy IME-menu construction. In
    /// particular, the first Japanese menu can initially contain "Loading…".
    /// Prepare on source notifications, without opening or choosing anything.
    func prepare() {
        guard AXIsProcessTrusted(),
              let agent = NSWorkspace.shared.runningApplications.first(where: {
                  $0.bundleIdentifier == "com.apple.TextInputMenuAgent"
              }),
              let bar = element(AXUIElementCreateApplication(agent.processIdentifier), "AXExtrasMenuBar") else { return }
        for statusItem in children(bar) where string(statusItem, kAXRoleAttribute) == kAXMenuBarItemRole {
            for menu in children(statusItem) { _ = children(menu) }
        }
    }

    func select(localizedName: String, foregroundPID: pid_t) throws {
        guard AXIsProcessTrusted() else {
            throw Failure.unavailable("grant Accessibility to the installed input-source-switcher")
        }
        guard let agent = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.TextInputMenuAgent"
        }) else {
            throw Failure.unavailable("macOS input-menu agent is unavailable")
        }
        let application = AXUIElementCreateApplication(agent.processIdentifier)
        // The agent can briefly replace its menu bar while a source changes.
        var statusItems: [AXUIElement] = []
        let resolutionDeadline = Date().addingTimeInterval(0.1)
        repeat {
            if let bar = element(application, "AXExtrasMenuBar") {
                statusItems = children(bar).filter { string($0, kAXRoleAttribute) == kAXMenuBarItemRole }
            }
            if statusItems.count == 1 { break }
            Thread.sleep(forTimeInterval: 0.005)
        } while Date() < resolutionDeadline
        guard statusItems.count == 1, let statusItem = statusItems.first else {
            throw Failure.unavailable("macOS input menu is missing or ambiguous")
        }
        guard isForeground(foregroundPID) else {
            throw Failure.unavailable("foreground changed before input-menu selection")
        }

        var opened = false
        defer {
            if opened {
                for menu in children(statusItem) where string(menu, kAXRoleAttribute) == kAXMenuRole {
                    _ = AXUIElementPerformAction(menu, kAXCancelAction as CFString)
                }
            }
        }

        var targets = items(named: localizedName, in: statusItem)
        if targets.isEmpty {
            // Give a lazily constructed closed menu time to populate before
            // resorting to opening it. Do not intercept or synthesize typing.
            let deadline = Date().addingTimeInterval(0.25)
            repeat {
                Thread.sleep(forTimeInterval: 0.005)
                guard isForeground(foregroundPID) else {
                    throw Failure.unavailable("foreground changed while input menu was loading")
                }
                targets = items(named: localizedName, in: statusItem)
                if !targets.isEmpty { break }
            } while Date() < deadline
        }
        if targets.isEmpty {
            // Closed menus can expose only ABC. AXPress starts menu tracking and
            // may time out even when it opened successfully. Inspect the result
            // once; never toggle or select an intermediate source to repair it.
            AXUIElementSetMessagingTimeout(statusItem, 0.025)
            _ = AXUIElementPerformAction(statusItem, kAXPressAction as CFString)
            AXUIElementSetMessagingTimeout(statusItem, 0.2)
            opened = true
            let deadline = Date().addingTimeInterval(0.5)
            repeat {
                targets = items(named: localizedName, in: statusItem)
                if !targets.isEmpty { break }
                Thread.sleep(forTimeInterval: 0.005)
            } while Date() < deadline
        }
        guard targets.count == 1, let target = targets.first else {
            throw Failure.unavailable("input-menu source is missing or ambiguous: \(localizedName) count=\(targets.count)")
        }
        guard isForeground(foregroundPID) else {
            throw Failure.unavailable("foreground changed while resolving input menu")
        }
        let result = AXUIElementPerformAction(target, kAXPressAction as CFString)
        guard result == .success else { throw Failure.action(result) }
    }

    private func isForeground(_ pid: pid_t) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
    }

    private func items(named name: String, in statusItem: AXUIElement) -> [AXUIElement] {
        children(statusItem).compactMap { menu in
            let entries = children(menu)
            guard let index = InputSourcePolicy.nativeMenuSourceIndex(
                itemTitles: entries.map { string($0, kAXTitleAttribute) },
                localizedName: name
            ), string(entries[index], kAXRoleAttribute) == kAXMenuItemRole else { return nil }
            return entries[index]
        }
    }

    private func attribute(_ item: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func element(_ item: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(item, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func children(_ item: AXUIElement) -> [AXUIElement] {
        attribute(item, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private func string(_ item: AXUIElement, _ name: String) -> String {
        attribute(item, name) as? String ?? ""
    }
}
