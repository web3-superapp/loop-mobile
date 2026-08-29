# Open-Source Attribution and Dependency Register

Review date: 2026-08-29. Versions are locked by `pubspec.yaml` and `pubspec.lock`; bundled license texts in resolved packages remain the legal source of truth.

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
| reown_appkit | 1.8.4 | Reown Community License Agreement | Ephemeral external EVM connection and `personal_sign` transport for Privy SIWE credentials only |
| shared_preferences | 2.5.5 | BSD-3-Clause | Non-sensitive device-local display preference |
| stream_chat_flutter | 10.3.0 | Stream Source Code License Agreement | Chat SDK and UI |
| stream_chat_persistence | 10.3.0 | Stream Source Code License Agreement | Official bounded chat persistence |
| stream_video_flutter | 1.4.3 | Stream Source Code License Agreement | Video/audio calling SDK |
| uuid | 4.6.0 | MIT | Fresh call and idempotency identifiers |

Flutter, Dart, `flutter_test`, and their SDK artifacts are governed by the licenses distributed with the pinned Flutter SDK.

Stream's resolved packages contain a vendor source-code agreement rather than a standard permissive OSS license. Product/legal owners must confirm the applicable Stream commercial terms and ship required notices before distribution.

The Reown graph is also source-available under vendor community terms rather than a standard permissive open-source license. `pubspec.lock` currently resolves `reown_core` 1.5.0 and `reown_sign` 1.4.0; their package licenses are the WalletConnect Community License Agreement. The direct AppKit 1.8.4 license requires the distribution notice `Portions © 2025 Reown, Inc. All Rights Reserved`, a copy of its license agreement, applicable branding, and connection to Reown infrastructure. Its recorded commercial-license thresholds are more than 500 monthly active users or more than 2,500,000 monthly RPCs; Reown reserves the right to change them. Before any App Store, Play Store, TestFlight, or external distribution, product/legal owners must re-check the then-current terms and verify that the notice, complete agreement, and applicable branding are actually shipped with the app; this register alone is not distribution compliance.

Reown also resolves provider-internal storage and wallet-transport packages, including `flutter_secure_storage`. LOOP does not adopt those transitive packages as an application credential, settings, PIN, identity, or transaction store; their presence is limited to the locked Reown credential transport graph.

`stream_video_push_notification` 1.4.3 was compatibility-tested in Phase 0 but is intentionally absent from the current resolved application. Its native plugin auto-registers Telecom/CallKit behavior before LOOP has approved push, VoIP, or incoming-call capabilities. Reintroducing it requires a new native/provider decision and an updated attribution review.

## Inspiration register

| Reference | License | Current use |
| --- | --- | --- |
| [Ajaxy/telegram-tt](https://github.com/Ajaxy/telegram-tt) at `8b63941b230b3870accc442b5ef5ac95fc53c719` | GPL-3.0 | Product brief inspiration only; no source or assets copied into Loop. |
| `reference/legacy-prototype/` | Repository history | Frozen product/prototype reference; not a dependency or authority over current decisions. |

## Operating rule

Before external code, assets, fonts, or close translations enter the worktree, record the exact source, revision, license, copied material, modifications, and required notices. Inspiration is not permission to copy implementation or brand assets.
