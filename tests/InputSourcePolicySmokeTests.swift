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

        // Regression: a matching Korean mode with an ABC layout is not success.
        precondition(!InputSourcePolicy.selectionMatches(
            .korean,
            sourceID: PrimaryInputSource.korean.rawValue,
            layoutID: PrimaryInputSource.english.rawValue
        ))
        precondition(InputSourcePolicy.selectionMatches(
            .korean,
            sourceID: PrimaryInputSource.korean.rawValue,
            layoutID: "com.apple.keylayout.2SetHangul"
        ))
        precondition(InputSourcePolicy.selectionMatches(
            .english,
            sourceID: PrimaryInputSource.english.rawValue,
            layoutID: PrimaryInputSource.english.rawValue
        ))
        precondition(!InputSourcePolicy.selectionMatches(
            .english,
            sourceID: PrimaryInputSource.korean.rawValue,
            layoutID: PrimaryInputSource.english.rawValue
        ))

        // Captured native Korean menu: the second ABC is an IME command, not
        // the English input source. Never select commands after the separator.
        let koreanMenu = ["ABC", "Japanese", "2-Set Korean", "", "ABC", "Edit Hanja Dictionary"]
        precondition(InputSourcePolicy.nativeMenuSourceIndex(itemTitles: koreanMenu, localizedName: "ABC") == 0)
        precondition(InputSourcePolicy.nativeMenuSourceIndex(itemTitles: koreanMenu, localizedName: "2-Set Korean") == 2)
        precondition(InputSourcePolicy.nativeMenuSourceIndex(itemTitles: ["Loading…", "", "ABC"], localizedName: "ABC") == nil)
        precondition(InputSourcePolicy.nativeMenuSourceIndex(itemTitles: ["ABC", "ABC", ""], localizedName: "ABC") == nil)

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
