import InputSourcePolicy
import Testing

@Test("Native input-source section excludes Korean's separate ABC command")
func nativeSourceSection() {
    // Captured from TextInputMenuAgent during a failed native-menu trial.
    let menu = ["ABC", "Japanese", "2-Set Korean", "", "ABC", "Edit Hanja Dictionary"]
    #expect(InputSourcePolicy.nativeMenuSourceIndex(itemTitles: menu, localizedName: "ABC") == 0)
    #expect(InputSourcePolicy.nativeMenuSourceIndex(itemTitles: menu, localizedName: "2-Set Korean") == 2)
    #expect(InputSourcePolicy.nativeMenuSourceIndex(
        itemTitles: ["Loading…", "", "ABC"], localizedName: "ABC"
    ) == nil)
    #expect(InputSourcePolicy.nativeMenuSourceIndex(
        itemTitles: ["ABC", "ABC", ""], localizedName: "ABC"
    ) == nil)
    #expect(InputSourcePolicy.nativeMenuSourceIndex(
        itemTitles: ["ABC", "일본어", "두벌식", "", "ABC"], localizedName: "두벌식"
    ) == 2)
}

@Test("Korean selection requires the Korean physical-key layout")
func koreanLayoutAgreement() {
    #expect(!InputSourcePolicy.selectionMatches(
        .korean,
        sourceID: PrimaryInputSource.korean.rawValue,
        layoutID: PrimaryInputSource.english.rawValue
    ))
    #expect(InputSourcePolicy.selectionMatches(
        .korean,
        sourceID: PrimaryInputSource.korean.rawValue,
        layoutID: "com.apple.keylayout.2SetHangul"
    ))
    #expect(InputSourcePolicy.selectionMatches(
        .english,
        sourceID: PrimaryInputSource.english.rawValue,
        layoutID: PrimaryInputSource.english.rawValue
    ))
    #expect(!InputSourcePolicy.selectionMatches(
        .english,
        sourceID: PrimaryInputSource.korean.rawValue,
        layoutID: PrimaryInputSource.english.rawValue
    ))
}

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
