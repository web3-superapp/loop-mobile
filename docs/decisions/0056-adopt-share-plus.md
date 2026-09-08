# 0056 · Adopt share_plus for the on-device merged-image export

## Status

Accepted 2026-09-08. Completes the export half of decision 0055.

## Context

`chat-merge-preview` renders an anonymous transcript of the messages a viewer
selected. Producing it was the point of the page, but the locked stack had no
way to hand an image to another application: there was no share plugin and no
image encoder beyond `dart:ui`. The page therefore shipped with the export
action explicitly unavailable, which is honest but not the product.

Two facts made the dependency cheap:

- `share_plus` 12.0.2 was **already in the resolved graph** as a transitive
  dependency of `stream_chat_flutter` 10.3.0. Promoting it to a direct
  dependency changes one line of `pubspec.lock` and no version anywhere.
- Flutter already encodes PNG in the framework: `RenderRepaintBoundary.toImage`
  plus `ui.Image.toByteData(format: ImageByteFormat.png)`. No image package is
  needed.

## Decision

1. **Pin `share_plus: 12.0.2` exactly**, matching the repository's exact-pin
   rule, and register it in `harness.json` and `PINNED_DEPENDENCIES`.
2. **The export is a capture of the rendered anonymous card.** The merged
   transcript sits inside a `RepaintBoundary`; the button captures exactly that
   subtree at `pixelRatio: 3` and encodes it to PNG with `dart:ui`. Because the
   card renders only `匿名成员`, a timestamp and the text, no alias, LOOP ID,
   Stream user ID or wallet address can be in the pixels.
3. **The bytes go straight to the operating system.** `SystemChatMergeExportSink`
   passes an in-memory `XFile` to `SharePlus.instance.share`. Nothing is
   uploaded to a LOOP service, nothing is written to a location the app keeps,
   and LOOP learns only whether the sheet was used — never the destination.
4. **`lib/features/` depends on a port, not the plugin.**
   `ChatMergeExportSink` lives with the feature; the `share_plus` adapter lives
   in `lib/integrations/sharing/`. The production default is
   `UnavailableChatMergeExportSink`, and both composition roots override it, so
   a run without the adapter says so instead of failing silently.
5. **Every outcome is stated, none is assumed.** `shared`, `dismissed`,
   `failed` and `unavailable` each carry their own copy; a platform failure is
   never reported as a partial success.

## Lockfile diff

Resolving with the new direct dependency changed exactly one line — the
classification of an already-resolved package. No version moved, and no new
package entered the graph:

```diff
--- pubspec.lock (before)
+++ pubspec.lock (after)
@@ -1601 +1601 @@
   share_plus:
-    dependency: transitive
+    dependency: "direct main"
```

`share_plus_platform_interface`, `cross_file`, `url_launcher` and the other
packages `share_plus` needs were already resolved for Stream Chat and are
untouched.

## Consequences

- Android and iOS gain no new permission: `share_plus` uses the system share
  sheet, which requires none. No native build configuration changed.
- The capture runs on the raster thread, so a widget test must drive it inside
  `tester.runAsync`; the suites do.
- The merged image is still bounded by decision 0055's 50-row cap and its
  truncation notice, so an export cannot become an unbounded transcript dump.
- Sharing is a device action LOOP cannot observe. The success copy says the
  sheet was opened, never that anything was delivered.

## Evidence

- `test/communication_pages_test.dart` — the export encodes a real PNG (checked
  by its signature) from a card that renders only the anonymous label, shares
  it exactly once under a fixed file name, and reports the unavailable outcome
  when no adapter is composed.
- `scripts/check_harness.py` — `share_plus 12.0.2` is a pinned dependency and
  `pubspec.yaml` must keep the exact pin.
