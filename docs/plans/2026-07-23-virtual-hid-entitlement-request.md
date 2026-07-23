# Virtual HID development entitlement request

## Request status

- Date prepared: 2026-07-23
- Status: Drafted in the Apple Developer form, not submitted
- Request form: https://developer.apple.com/contact/request/system-extension/
- Team: `seungho choi - 8UDBP4JUZ5`
- Capability: `Virtual HID`
- Entitlement: `com.apple.developer.hid.virtual.device`
- Product: `keyon`
- Bundle ID: `dev.undervars.keyon`
- Product URL: https://github.com/zdpk/dotfiles
- Requested scope: Development and testing on registered Macs
- Intended profile: Mac App Development

The request is for the CoreHID app entitlement. It is not a request for the
DriverKit entitlement
`com.apple.developer.driverkit.family.hid.virtual.device`, and the app does not
contain a DriverKit extension.

## Product rationale

Korean and Japanese users frequently switch between Latin text and their local
input methods. macOS provides built-in input-source shortcuts such as
Control-Space, but many users prefer a dedicated language key that behaves like
the language keys on familiar Korean and Japanese hardware keyboards.

Configuring Right Command as a language key currently often involves several
advanced steps:

1. Install a separate remapping utility such as Karabiner-Elements or
   Hammerspoon.
2. Remap Right Command to an otherwise unused key such as F18 or F19.
3. Assign that key to the previous-input-source action in macOS Keyboard
   settings.
4. Grant and maintain the required permissions and background components.

This setup was manageable for technically experienced Mac users, but Mac
adoption has broadened to users who should not need to understand HID usages,
function-key indirection, launch agents, or low-level keyboard permissions just
to obtain a convenient language key.

keyon provides the same workflow through a guided,
user-facing interface:

- Right Command invokes the configured primary-language toggle.
- Option+1, Option+2, Option+3, and subsequent number keys invoke
  user-configured language slots.
- Settings remain local to the Mac.
- No separate keyboard remapper is required.

## Technical scope

The virtual HID portion is deliberately narrower than a general-purpose
virtual keyboard.

- The first development version targets Korean/English and Japanese input modes
  for which standard HID input-method usages exist.
- A Korean-localized virtual device emits the standard Hangul/English language
  usage.
- A Japanese-localized virtual device emits only the applicable Kana,
  alphanumeric, or Hiragana language usage.
- A configured language slot without a corresponding standard HID input-method
  usage does not use virtual HID.
- The exact LANG1, LANG2, and LANG4 behavior will be verified on a registered
  development Mac after the entitlement is provisioned.

CoreHID cannot directly select every arbitrary macOS input source using a
dedicated HID usage. The product UI may expose numbered language slots, but the
Virtual HID entitlement is used only where a standard hardware-equivalent
language usage exists.

## Why Virtual HID is required

The existing prototype uses `TISSelectInputSource`. During live testing, the
menu-bar input-source indicator could change while the active text-input client
continued to process input using a different composition state. This produces
the visible failure where the menu bar reports Korean but the focused
application still types English.

A hardware-equivalent language-key report follows the normal macOS keyboard and
input-method path. The app therefore needs `CoreHID.HIDVirtualDevice` to model
the same narrow language-key behavior as a localized physical keyboard.

## Privacy and abuse prevention

- The report descriptor is limited to required input-method usages.
- The app does not emit letters, numbers, pointer events, or arbitrary
  shortcuts through Virtual HID.
- The app does not monitor, record, store, or transmit typed content.
- The app has no key-logging feature and no network service.
- Every generated report is caused by an explicit local key press.
- Configuration remains on device.
- The initial entitlement request is limited to development and testing on
  registered Macs.

## Apple request text

The following text is intended for the Apple Developer request form and must
remain within its 2,000-character limit.

- Portal character count: 1,951

> We are developing keyon, a macOS utility for people who frequently switch between Roman-alphabet input and local input methods, especially Korean and Japanese. They may switch languages repeatedly within one message or document.
>
> macOS provides Control-Space and, on some localized keyboards, dedicated language keys. However, creating an easy one-key workflow on a standard keyboard commonly requires several steps: installing Karabiner-Elements or Hammerspoon, remapping Right Command to an unused key such as F18 or F19, and assigning that key to an input-source shortcut in macOS Keyboard settings. This is difficult to discover, configure, and maintain for non-technical users.
>
> Our app replaces that multi-tool setup with a simple interface. Right Command toggles the user's primary language pair. Option+1, Option+2, Option+3, and later slots invoke user-registered input sources. The app resolves those slots from enabled sources; Virtual HID is used only to reproduce a native language-key event, never to encode arbitrary input-source IDs.
>
> We request the Virtual HID entitlement for development and testing of a narrowly scoped virtual keyboard. It will emit only standard HID input-method usages needed for explicit language-switch actions, such as LANG1 and LANG4; it will not emit ordinary character keys. In our testing, TISSelectInputSource can change the source shown by macOS while the target app continues using the previous IME composition state. Virtual HID lets us test the OS-supported HID language-key path used by physical localized keyboards.
>
> The app does not log, record, store, analyze, or transmit keystrokes. It does not expose arbitrary keystroke injection, scripting, or automation. A permitted language usage is emitted only in direct response to a user-configured shortcut. Initial use is limited to development builds on registered test Macs while we validate reliability and safety. Bundle ID: dev.undervars.keyon.

## Korean summary

영어 입력이 중심인 환경과 달리 한국어와 일본어 사용자는 로마자 입력과
현지 입력기를 한 문서 안에서도 반복해서 전환한다. macOS는 Control-Space와
일부 현지화 키보드의 전용 언어 키를 지원하지만, 일반 키보드의 Right
Command를 편리한 언어 키로 만들려면 여러 설정이 필요하다.

현재 널리 알려진 방법은 Karabiner-Elements나 Hammerspoon을 별도로
설치하고, Right Command를 F18/F19 같은 미사용 키로 변환한 뒤, macOS
Keyboard 설정에서 해당 키를 이전 입력 소스 전환에 다시 연결하는 것이다.
숙련된 사용자는 이 과정을 수행할 수 있지만, 키 리매핑과 권한, 백그라운드
구성요소를 이해해야 하므로 일반 사용자에게는 발견과 설정, 유지 모두
부담스럽다. Mac 사용자층이 넓어질수록 이러한 저수준 설정을 전제로 하지
않는 인터페이스가 필요하다.

keyon은 이 다단계 구성을 하나의 안내형 인터페이스로
제공한다. Right Command는 사용자가 정한 주 언어 쌍을 전환하고,
Option+1, Option+2, Option+3 이후의 숫자 슬롯은 사용자가 등록한 언어를
호출한다.

Virtual HID는 한국어·일본어 키보드에 정의된 표준 언어 usage가 있는
경우에만 사용한다. 일반 문자, 숫자, 마우스 이벤트나 임의 단축키를
생성하지 않는다. 키 입력을 기록·분석·저장·전송하지 않으며, 사용자가
설정한 단축키를 직접 누른 경우에만 허용된 언어 usage를 출력한다.

## Local verification recorded before submission

- macOS: 26.5.1
- Xcode: 26.6
- A valid Apple Development signing identity is installed.
- Three local provisioning profiles were inspected.
- None currently contains
  `com.apple.developer.hid.virtual.device`.
- A probe based on Apple's CoreHID keyboard descriptor compiled successfully.
- `HIDVirtualDevice(properties:)` returned `nil` without the managed
  entitlement.

## After submission

Record the result here.

- Submitted at:
- Apple request or case ID:
- Request status:
- Apple response:
- Capability enabled for App ID:
- Development provisioning profile:
- Signed probe verification:
- Korean LANG1 result:
- Japanese LANG1/LANG2/LANG4 result:

## Related design

See
[2026-07-18-macos-input-source-switcher-design.md](./2026-07-18-macos-input-source-switcher-design.md)
for the current prototype and
[2026-07-23-keyon-prd.md](./2026-07-23-keyon-prd.md) for the target product.

## References

- [Creating virtual devices](https://developer.apple.com/documentation/corehid/creatingvirtualdevices)
- [Virtual HID entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.hid.virtual.device)
- [Apple keyboard HID usages](https://developer.apple.com/documentation/uikit/uikeyboardhidusage)
- [HID device localization codes](https://developer.apple.com/documentation/corehid/hiddevicelocalizationcode)
- [Request access to managed capabilities](https://developer.apple.com/help/account/capabilities/capability-requests)
