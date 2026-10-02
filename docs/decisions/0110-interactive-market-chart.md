# 0110 — Exchange-style market chart interactions

## Status
Approved scope: user rejected the static chart on 2026-10-02 and requested normal exchange-style chart usability, continuing decision 0109 market references.

## Context
The existing CustomPaint showed all candles at once with 7-pixel price-axis text, no time axis and no viewport, selection or zoom gestures. A visible candle drawing did not satisfy the requested usable market view.

## Decision
Keep the existing exact Decimal candle contract and five supported intervals. Add bounded historical pan, focal-point pinch/wheel zoom, accessible zoom controls, return-to-latest, hover/tap/long-press candle selection, crosshair, UTC times and readable price labels. Use the selected real candle for exact OHLCV readouts. Label separately displayed latest MA values explicitly. Compute MA using full delivered history before slicing and clip its geometry at the viewport instead of fabricating boundary values.

Give the inline chart more vertical space. Full-screen uses the same interactive component. Asset/interval changes reset selection and viewport; updates to the same series preserve a bounded historical view. Preserve gaps, open-bucket markings and source provenance. The chart remains read-only and introduces no dependency, external feed, unsupported interval or transaction path.

## Consequences
Local preview remains deterministic fake data. Production charts depend on delivered backend candles; panning is bounded by loaded history and never silently synthesizes older bars. Mobile and pointer interactions require explicit regression checks, along with flat/tiny/empty data and period changes. All work remains on the existing UI feature branch pending later merge.
