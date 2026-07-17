public enum PrimaryInputSource: String, CaseIterable, Sendable {
    case english = "com.apple.keylayout.ABC"
    case korean = "com.apple.inputmethod.Korean.2SetKorean"
}

public enum InputSourcePolicy {
    public static let japaneseSourceID =
        "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"

    public static func primarySource(for sourceID: String) -> PrimaryInputSource? {
        PrimaryInputSource(rawValue: sourceID)
    }

    public static func primaryKeyTarget(
        currentSourceID: String,
        lastPrimary: PrimaryInputSource
    ) -> PrimaryInputSource {
        switch primarySource(for: currentSourceID) {
        case .english:
            return .korean
        case .korean:
            return .english
        case nil:
            return lastPrimary
        }
    }

    public static func primaryToRememberBeforeJapanese(
        currentSourceID: String,
        lastPrimary: PrimaryInputSource
    ) -> PrimaryInputSource {
        primarySource(for: currentSourceID) ?? lastPrimary
    }
}
