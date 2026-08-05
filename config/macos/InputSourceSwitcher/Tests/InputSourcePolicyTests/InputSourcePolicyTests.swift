import InputSourcePolicy
import Testing

@Test("Right Command toggles English and Korean")
func primaryToggle() {
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: PrimaryInputSource.english.rawValue,
            lastPrimary: .english
        ) == .korean
    )
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: PrimaryInputSource.korean.rawValue,
            lastPrimary: .korean
        ) == .english
    )
}

@Test("Right Command returns from Japanese to the remembered primary source")
func japaneseReturn() {
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: InputSourcePolicy.japaneseSourceID,
            lastPrimary: .korean
        ) == .korean
    )
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: InputSourcePolicy.japaneseSourceID,
            lastPrimary: .english
        ) == .english
    )
}

@Test("Right Option remembers only a primary source")
func japaneseMemory() {
    #expect(
        InputSourcePolicy.primaryToRememberBeforeJapanese(
            currentSourceID: PrimaryInputSource.korean.rawValue,
            lastPrimary: .english
        ) == .korean
    )
    #expect(
        InputSourcePolicy.primaryToRememberBeforeJapanese(
            currentSourceID: InputSourcePolicy.japaneseSourceID,
            lastPrimary: .korean
        ) == .korean
    )
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
    #expect(InputMode.koreanEnglish.usesResidentHelper == false)
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

@Test("Unknown sources use the remembered primary source")
func unknownSourceFallback() {
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: "example.unknown.input-source",
            lastPrimary: .english
        ) == .english
    )
}
