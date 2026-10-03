# Exchange-style candle interaction

The owner rejected the static chart as unusable and requested normal exchange behavior, continuing the already-approved market reference scope.

- Replace static full-series projection with a bounded, pannable and zoomable viewport. Touch pinch, pointer wheel, and accessible controls operate on the same view state.
- Select real candles with hover/tap/long press, expose crosshair/date and exact OHLCV in the owning screen. UTC time axis and readable price axis; current-price line/tag and return-to-latest.
- Preserve Decimal models, gaps, open-bucket markers, source provenance, read-only gateway and existing five supported periods. No unsupported interval or transaction capability.
- Moving averages use full history before viewport clipping; default inline chart receives more vertical space. Full-screen inherits identical interactions.
- Verify gesture behavior and boundary cases in widget tests, selected-OHLC integration, existing candle and market regressions, harness and browser at 390px. Keep the existing feature branch and do not merge.
