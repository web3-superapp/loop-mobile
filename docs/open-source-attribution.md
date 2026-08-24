# Open-Source Attribution and Dependency Register

Review date: 2026-08-24. Versions are locked by `pubspec.yaml` and `pubspec.lock`; bundled license texts in resolved packages remain the legal source of truth.

## Direct Flutter dependencies

| Package | Version | License observed in resolved package | Purpose |
| --- | ---: | --- | --- |
| cupertino_icons | 1.0.8 | MIT | Apple-style icon font |
| decimal | 3.2.6 | Apache-2.0 | Decimal-safe market and trading values |
| dio | 5.11.0 | MIT | HTTP client |
| firebase_core | 4.13.0 | BSD-3-Clause-style Flutter license | Firebase bootstrap, gated until configs exist |
| firebase_messaging | 16.5.0 | BSD-3-Clause-style Flutter license | Central push router, gated until configs exist |
| flutter_lints | 6.0.0 | BSD-3-Clause-style Flutter license | Development lint rules |
| flutter_riverpod | 3.4.2 | MIT | State management |
| go_router | 17.5.0 | BSD-3-Clause-style Flutter license | Navigation |
| privy_flutter | 0.10.1 | MIT | Identity and embedded wallets |
| stream_chat_flutter | 10.3.0 | Stream Source Code License Agreement | Chat SDK and UI |
| stream_chat_persistence | 10.3.0 | Stream Source Code License Agreement | Official bounded chat persistence |
| stream_video_flutter | 1.4.3 | Stream Source Code License Agreement | Video/audio calling SDK |
| stream_video_push_notification | 1.4.3 | Stream Source Code License Agreement | Incoming-call push integration |
| uuid | 4.6.0 | MIT | Fresh call and idempotency identifiers |

Flutter, Dart, `flutter_test`, and their SDK artifacts are governed by the licenses distributed with the pinned Flutter SDK.

Stream's resolved packages contain a vendor source-code agreement rather than a standard permissive OSS license. Product/legal owners must confirm the applicable Stream commercial terms and ship required notices before distribution.

## Inspiration register

| Reference | License | Current use |
| --- | --- | --- |
| [Ajaxy/telegram-tt](https://github.com/Ajaxy/telegram-tt) at `8b63941b230b3870accc442b5ef5ac95fc53c719` | GPL-3.0 | Product brief inspiration only; no source or assets copied into Loop. |
| `reference/legacy-prototype/` | Repository history | Frozen product/prototype reference; not a dependency or authority over current decisions. |

## Operating rule

Before external code, assets, fonts, or close translations enter the worktree, record the exact source, revision, license, copied material, modifications, and required notices. Inspiration is not permission to copy implementation or brand assets.
