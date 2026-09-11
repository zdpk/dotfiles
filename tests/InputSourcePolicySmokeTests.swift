import Foundation

@main
enum InputSourcePolicySmokeTests {
    static func main() {
        precondition(
            InputSourcePolicy.primaryKeyTarget(
                currentSourceID: PrimaryInputSource.english.rawValue
            ) == .korean
        )
        precondition(
            InputSourcePolicy.primaryKeyTarget(
                currentSourceID: PrimaryInputSource.korean.rawValue
            ) == .english
        )
        precondition(
            InputSourcePolicy.primaryKeyTarget(
                currentSourceID: InputSourcePolicy.japaneseSourceID
            ) == .korean
        )
        precondition(
            InputSourcePolicy.primaryKeyTarget(
                currentSourceID: "example.unknown.input-source"
            ) == .korean
        )

        // Mode declarations: ko-en owns two selectable sources, ko-en-ja three,
        // and each input method is enabled alongside its parent bundle.
        precondition(
            InputSourcePolicy.requiredSourceIDs(for: .koreanEnglish) == [
                PrimaryInputSource.english.rawValue,
                InputSourcePolicy.koreanInputMethodID,
                PrimaryInputSource.korean.rawValue,
            ]
        )
        precondition(
            InputSourcePolicy.requiredSourceIDs(for: .koreanEnglishJapanese) == [
                PrimaryInputSource.english.rawValue,
                InputSourcePolicy.koreanInputMethodID,
                PrimaryInputSource.korean.rawValue,
                InputSourcePolicy.japaneseInputMethodID,
                InputSourcePolicy.japaneseSourceID,
            ]
        )
        precondition(
            InputSourcePolicy.selectableSourceIDs(for: .koreanEnglish).count == 2
        )
        precondition(
            InputSourcePolicy.selectableSourceIDs(for: .koreanEnglishJapanese).count == 3
        )
        precondition(InputMode.koreanEnglish.usesResidentHelper)
        precondition(InputMode.koreanEnglishJapanese.usesResidentHelper)
        precondition(InputMode(rawValue: "ko-en") == .koreanEnglish)
        precondition(InputMode(rawValue: "ko-jp") == nil)

        // dotfiles owns the keyboard source list: anything undeclared is removed.
        let enabled = [
            PrimaryInputSource.english.rawValue,
            InputSourcePolicy.koreanInputMethodID,
            PrimaryInputSource.korean.rawValue,
            InputSourcePolicy.japaneseInputMethodID,
            InputSourcePolicy.japaneseSourceID,
            "com.apple.keylayout.Dvorak",
        ]
        precondition(
            InputSourcePolicy.sourceIDsToDisable(
                enabledKeyboardSourceIDs: enabled,
                mode: .koreanEnglish
            ) == [
                InputSourcePolicy.japaneseInputMethodID,
                InputSourcePolicy.japaneseSourceID,
                "com.apple.keylayout.Dvorak",
            ]
        )
        precondition(
            InputSourcePolicy.sourceIDsToDisable(
                enabledKeyboardSourceIDs: enabled,
                mode: .koreanEnglishJapanese
            ) == ["com.apple.keylayout.Dvorak"]
        )
        precondition(
            InputSourcePolicy.sourceIDsToDisable(
                enabledKeyboardSourceIDs: InputSourcePolicy.requiredSourceIDs(
                    for: .koreanEnglish
                ),
                mode: .koreanEnglish
            ).isEmpty
        )

        print("input-source policy smoke tests passed")
    }
}
