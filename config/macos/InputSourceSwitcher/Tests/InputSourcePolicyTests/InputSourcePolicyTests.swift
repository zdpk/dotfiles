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

@Test("Unknown sources use the remembered primary source")
func unknownSourceFallback() {
    #expect(
        InputSourcePolicy.primaryKeyTarget(
            currentSourceID: "example.unknown.input-source",
            lastPrimary: .english
        ) == .english
    )
}
