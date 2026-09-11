public enum PrimaryInputSource: String, CaseIterable, Sendable {
    case english = "com.apple.keylayout.ABC"
    case korean = "com.apple.inputmethod.Korean.2SetKorean"
}

/// Both modes use the same deterministic switcher; Japanese is opt-in.
public enum InputMode: String, CaseIterable, Sendable {
    case koreanEnglish = "ko-en"
    case koreanEnglishJapanese = "ko-en-ja"

    public var includesJapanese: Bool {
        self == .koreanEnglishJapanese
    }

    public var usesResidentHelper: Bool {
        true
    }
}

public enum InputSourcePolicy {
    public static let koreanInputMethodID = "com.apple.inputmethod.Korean"
    public static let japaneseInputMethodID =
        "com.apple.inputmethod.Kotoeri.RomajiTyping"
    public static let japaneseSourceID =
        "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"

    /// Every keyboard source the mode owns, in the order macOS should enable
    /// them. An input method needs its parent bundle enabled alongside the mode
    /// entry for the result to match adding the source in System Settings.
    public static func requiredSourceIDs(for mode: InputMode) -> [String] {
        var sourceIDs = [
            PrimaryInputSource.english.rawValue,
            koreanInputMethodID,
            PrimaryInputSource.korean.rawValue,
        ]

        if mode.includesJapanese {
            sourceIDs.append(japaneseInputMethodID)
            sourceIDs.append(japaneseSourceID)
        }
        return sourceIDs
    }

    /// The sources a switch can land on, as opposed to the parent bundles.
    public static func selectableSourceIDs(for mode: InputMode) -> [String] {
        var sourceIDs = PrimaryInputSource.allCases.map(\.rawValue)

        if mode.includesJapanese {
            sourceIDs.append(japaneseSourceID)
        }
        return sourceIDs
    }

    /// dotfiles owns the keyboard source list, so anything enabled that the mode
    /// does not declare is removed. Callers pass keyboard-category sources only;
    /// palette sources such as the character viewer are never considered.
    public static func sourceIDsToDisable(
        enabledKeyboardSourceIDs: [String],
        mode: InputMode
    ) -> [String] {
        let required = Set(requiredSourceIDs(for: mode))
        return enabledKeyboardSourceIDs.filter { !required.contains($0) }
    }

    public static func primarySource(for sourceID: String) -> PrimaryInputSource? {
        PrimaryInputSource(rawValue: sourceID)
    }

    /// Right Command can never select Japanese. Japanese/unknown -> Korean.
    public static func primaryKeyTarget(currentSourceID: String) -> PrimaryInputSource {
        currentSourceID == PrimaryInputSource.korean.rawValue ? .english : .korean
    }
}
