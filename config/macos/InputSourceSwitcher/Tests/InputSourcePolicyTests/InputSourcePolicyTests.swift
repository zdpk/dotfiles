import InputSourcePolicy
import Testing

@Test("Right Command toggles English and Korean")
func primaryToggle() {
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: PrimaryInputSource.english.rawValue
        ) == .korean
    )
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: PrimaryInputSource.korean.rawValue
        ) == .english
    )
}

@Test("Right Command always returns from Japanese to Korean")
func japaneseReturn() {
    let fromJapanese = InputSourcePolicy.primaryKeyTarget(
        currentSourceID: InputSourcePolicy.japaneseSourceID
    )
    #expect(fromJapanese == .korean)
    let next = InputSourcePolicy.primaryKeyTarget(currentSourceID: fromJapanese.rawValue)
    #expect(next == .english)
    #expect(InputSourcePolicy.primaryKeyTarget(currentSourceID: next.rawValue) == .korean)
}

@Test("Each mode declares its own source set")
func declaredSources() {
    #expect(
        InputSourcePolicy.requiredSourceIDs(for: .koreanEnglish) == [
            PrimaryInputSource.english.rawValue,
            InputSourcePolicy.koreanInputMethodID,
            PrimaryInputSource.korean.rawValue,
        ]
    )
    #expect(
        InputSourcePolicy.requiredSourceIDs(for: .koreanEnglishJapanese) == [
            PrimaryInputSource.english.rawValue,
            InputSourcePolicy.koreanInputMethodID,
            PrimaryInputSource.korean.rawValue,
            InputSourcePolicy.japaneseInputMethodID,
            InputSourcePolicy.japaneseSourceID,
        ]
    )
    #expect(InputSourcePolicy.selectableSourceIDs(for: .koreanEnglish).count == 2)
    #expect(
        InputSourcePolicy.selectableSourceIDs(for: .koreanEnglishJapanese).count == 3
    )
    #expect(InputMode.koreanEnglish.usesResidentHelper)
    #expect(InputMode.koreanEnglishJapanese.usesResidentHelper)
}

@Test("Undeclared keyboard sources are removed, declared ones are kept")
func extraSourceRemoval() {
    let enabled = [
        PrimaryInputSource.english.rawValue,
        InputSourcePolicy.koreanInputMethodID,
        PrimaryInputSource.korean.rawValue,
        InputSourcePolicy.japaneseInputMethodID,
        InputSourcePolicy.japaneseSourceID,
        "com.apple.keylayout.Dvorak",
    ]

    #expect(
        InputSourcePolicy.sourceIDsToDisable(
            enabledKeyboardSourceIDs: enabled,
            mode: .koreanEnglish
        ) == [
            InputSourcePolicy.japaneseInputMethodID,
            InputSourcePolicy.japaneseSourceID,
            "com.apple.keylayout.Dvorak",
        ]
    )
    #expect(
        InputSourcePolicy.sourceIDsToDisable(
            enabledKeyboardSourceIDs: enabled,
            mode: .koreanEnglishJapanese
        ) == ["com.apple.keylayout.Dvorak"]
    )
    #expect(
        InputSourcePolicy.sourceIDsToDisable(
            enabledKeyboardSourceIDs: InputSourcePolicy.requiredSourceIDs(for: .koreanEnglish),
            mode: .koreanEnglish
        ).isEmpty
    )
}

@Test("Unknown sources return to Korean")
func unknownSourceFallback() {
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: "example.unknown.input-source"
        ) == .korean
    )
}
