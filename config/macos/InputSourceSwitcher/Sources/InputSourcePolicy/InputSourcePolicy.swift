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
    public static let koreanKeyboardLayoutID = "com.apple.keylayout.2SetHangul"
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

    public static func keyboardLayoutID(for source: PrimaryInputSource) -> String {
        source == .korean ? koreanKeyboardLayoutID : PrimaryInputSource.english.rawValue
    }

    /// A Korean mode ID can be selected while physical keys still use ABC.
    public static func selectionMatches(
        _ target: PrimaryInputSource,
        sourceID: String,
        layoutID: String
    ) -> Bool {
        sourceID == target.rawValue && layoutID == keyboardLayoutID(for: target)
    }

    /// macOS appends IME commands after the first menu separator. Korean's
    /// commands can include another "ABC" that is not the ABC input source.
    /// Empty AX titles represent separators in the native input menu.
    public static func nativeMenuSourceIndex(
        itemTitles: [String],
        localizedName: String
    ) -> Int? {
        let sourceTitles = itemTitles.prefix { !$0.isEmpty }
        let matches = sourceTitles.indices.filter { sourceTitles[$0] == localizedName }
        return matches.count == 1 ? matches.first : nil
    }

    /// Right Command can never select Japanese. Japanese/unknown -> Korean.
    public static func primaryKeyTarget(currentSourceID: String) -> PrimaryInputSource {
        currentSourceID == PrimaryInputSource.korean.rawValue ? .english : .korean
    }
}
