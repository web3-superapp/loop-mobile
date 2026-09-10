# 0071 · State blocks become lines, and the tab indicator slides

## Status

Accepted 2026-09-10. Presentation and motion only. No transport, request,
route, capability, contract or state machine moves; the 93-route manifest is
unchanged, and no colour or type size is added — every value here comes from
`lib/core/theme/loop_theme.dart` and the frozen prototype's own
`style-v2.css`.

Part of S16 (`docs/modules/S16-ux-polish.md`, stream C). Streams A (type scale)
and B (copy) own `LoopTypography` and the user-visible strings respectively;
this decision touches neither.

## Context

The 2026-09-10 simulator run produced four presentation complaints that are all
the same mistake in different places — the interface reserving room, colour or
motion for something it does not actually have to say.

1. **Tab switching read as a stutter.** Each of the five cells owned its own
   Lime gradient, so a switch was one ground disappearing and another one
   appearing, 180 ms apart, with Material's grey highlight briefly under the
   finger in between. Three grounds were visible during one tap: the pressed
   cell's grey, the old cell's Lime, the new cell's Lime.
2. **The chat header ate the first screen.** `在线人数` and `置顶公告` were two
   full-width `LoopEmpty` panels stating that neither fact had a source. With
   the keyboard up they were the part of the conversation that stayed on screen
   while the messages went under it.
3. **Empty states were "a sentence in a big box".** `.empty` in the prototype is
   `padding:56px 30px` centred, and the refined page adds a dashed 20px frame at
   `34px 22px`. That is a page-sized gesture. It was being used for 190 block-
   sized answers, most of them one short sentence, so a list with three empty
   sections spent most of its height on three empty frames.
4. **Loading looked wrong.** Every block loaded as the same generic list
   skeleton whatever it was about to render, and a re-read over data the page
   already held could not be told from a first load.

## Decision

### 1. One indicator, and it moves

The Lime ground is a single widget owned by `LoopTabBar`, not a background on
five cells. `AnimatedAlign` slides it between cell centres in 200 ms on
`Curves.easeOutCubic`; `LoopTabItem` crossfades its own glyph and label over the
same interval, from Ink 62% to Ink, so the ink darkens exactly while the pill
arrives. Nothing is created or destroyed during a switch, which is what made
the old transition read as a stutter.

Under `MediaQuery.disableAnimationsOf` the bar uses a plain `Align`, so the
indicator is at the destination in the same frame — a jump, not a fast slide —
and the colour tween's duration is zero.

Material's ripple and press wash are removed from the cells
(`NoSplash.splashFactory`, transparent highlight and hover). A grey block under
the finger is a second, contradicting statement about which tab is selected. The
`InkWell` itself stays, so the cell keeps its focus semantics and its 44px
target.

### 2. A state block is a line of copy

`LoopEmpty` is now a strip: a 17px Text3 glyph (`.ico-sm`), one line of copy,
an optional second line, an optional action, and 10px of padding. No border, no
card ground, no 34px mark, and no height beyond what those parts need. All 190
call sites keep their arguments, their `loop-empty` key and their semantics —
only the presentation changed, so every one of them got shorter without being
edited. `LoopUnavailableCard`, `CommunityUnavailableCard` and both
`…StateBlock` widgets render through it and inherit the same shape; the two
unavailable cards additionally gained an optional `action`, for the cases where
one real next step exists.

Whole-page unavailability is a different job and keeps the room it earns:
`LoopPageBlock` centres the brand mark, a heading, one explanation and at most
one action. It is for a page that has nothing to show, never for a block inside
one.

The prototype's framed `.empty` is therefore deliberately not reproduced at
block level. Its sizes still hold where the gesture is page-sized, which is what
`LoopPageBlock` is.

### 3. A skeleton is the shape of what is arriving

`LoopSkeleton` keeps `list`, `detail` and `chart` unchanged and gains three
inline shapes with their own constructors: `LoopSkeleton.row` (list rows with no
page padding, for a block that already sits inside some), `LoopSkeleton.card`
(label line, figure line, meta line inside a card outline) and
`LoopSkeleton.figure` (a number and its caption). A block loads as itself, so
nothing jumps when the data lands, and a small block no longer borrows the whole
page's shape.

### 4. Cached data is never replaced by a placeholder

`LoopChainResourceState.loading()` and `CommunityResourceState.loading()`
already kept the value they held and stayed `ready`. They now also record
`refreshing: true` for that case, and `false` when there was nothing to keep.
`ready()` and `failed()` clear it.

A block that is re-reading data it already shows keeps the data and wears
`LoopUpdatingBadge` — 更新中, a mute pill, non-blocking, which disables nothing
and claims nothing about the new answer. `LoopTopbar.updating` puts it on the
page as a whole, threaded through the three page scaffolds; `market`, `token`
and `wallet` adopt it in this step. A block with no value at all still loads as
a skeleton, which is the only case where a skeleton is honest.

The five reviewed states are untouched: this adds a mark to `ready`, and does
not widen, narrow or merge loading, empty, error, offline or permission.

### 5. The chat header is one line, or nothing

`LoopChatHeaderStrip` states the segments the server actually gave — `在线 N`,
`公告 …` — joined by `·` on one ellipsised line above the message list. With no
stated segment it renders nothing at all: an absent fact does not earn a card
explaining its own absence. `community-chat` passes it nothing today, because
`onlineCount` and `announcements` are both `{status: unavailable}` projections
in this step, so the two panels are simply gone.

`LoopChatHeaderFold` does the same folding for the group and DM header notices,
whose copy is unchanged.

Both fold away while the keyboard is up, and both sit above the list in the same
column, so neither can ever cover a message. The keyboard reading has to be
taken from the screen's own context, above its `Scaffold`: with
`resizeToAvoidBottomInset` the Scaffold hands its body a `MediaQuery` whose
`viewInsets.bottom` is already zero, so a widget under one would always answer
"the keyboard is down". `loopChatKeyboardIsUp(context)` is that reading, and the
three chat screens pass it in.

## Consequences

- 190 empty and unavailable blocks became inline strips with no call-site edit.
  A page whose layout depended on an empty block filling space now reads as a
  line of copy — that is the intended change, and no test relied on the frame.
- `LoopTabItem` no longer carries a decoration, so the selection is asserted
  against the indicator's position rather than a per-cell gradient.
- `refreshing` is additive on both resource states and defaults to `false`, so
  every existing construction, `busy` write and `working()` transition behaves
  exactly as before.
- `LoopSkeletonType` gained three values; the two `switch`es over it are
  exhaustive, so a fourth shape has to be drawn rather than fall through.
- The chat page states less than it used to. That is the point: it stated only
  that it had nothing to state.

## Evidence

`test/s16_component_polish_test.dart` covers the inline strip (no frame, the
17px glyph, height following content, the action reachable), `LoopPageBlock`,
the three new skeleton shapes and their semantics labels, the `refreshing`
transitions on both resource states with and without a cached value, the 更新中
mark on a ready block and on the topbar, and the header strip with data, with
no data, with blank segments, with the keyboard up and back down — plus the
`Scaffold` reading itself, which is the part that is easy to get wrong.

`test/loop_shell_test.dart` covers the single indicator: it exists once, it is
not inside a cell, it starts centred on the selected tab, it is mid-travel one
frame after a tap and settled on the destination after, the cells carry no
splash or highlight, the labels swap Ink and Ink 62%, and under reduced motion
there is no `AnimatedAlign` at all and the indicator is at the destination after
a single frame with no elapsed time.

The existing suites are unchanged and still pass, including
`test/system_loading_truthfulness_test.dart`, which keeps the three original
skeleton layouts and their bounds, and `test/loop_components_test.dart`, which
keeps the five-state contract.
