# Market and shared UI audit — 2026-10-02

User direction: inspect LOOP code paths first and adapt reference information hierarchy to existing capabilities. Fomo is a layout reference, not a new API contract. Existing Decimal facts, canonical asset identity, capability gates, source/time and trade boundaries are unchanged.

| Slug | Source review and treatment | Verification |
|---|---|---|
| market | Existing flat asset list, search/categories and source-backed quote rows retained. Shared row trailing text now wraps within available width. | Market page/fidelity suites; browser primary-tab check |
| token | Retain existing full-width price/candle presentation and data tray. No fabricated Fomo positions, holder comments or buy capability. | Market/chart selection tests; browser chart |
| chart-full | Existing native horizontal pan, zoom, exact OHLC selection and full-width canvas retained. | Chart selection suite |
| token-holders | Compact source-backed holder-count header, remove third repeated count card and developer explanation. Existing count and unavailable distribution remain distinct. No friend filter without holder/user mapping. | Market page/fidelity suites |
| token-trades | Compact summary and short venue label; keep original chain trade records, direction, ownership and confirmation. | Market page/fidelity suites |
| watchlist-edit | Compact header; preserve reorder/remove/group/save, CAS conflict logic and dirty state. | Fidelity and watchlist regression suites |
| alerts | Compact summary; preserve one-shot rule, pagination, editor and actual capability gate. | Fidelity and alert regression suites |
| new-pairs | Compact header; keep provider pool facts and canonical navigation gate. | Market page/fidelity suites |
| smart-money | Compact informational header; keep unavailable projection rather than invent wallets or profit. | Market page/fidelity suites |

## Shared interaction and layout

`LoopRecordRow` was allowing unrestricted trailing text to consume the row's width. The remaining row width is split into a 3:2 identity/value grid; tight trailing values wrap and align right, preserving the entire amount rather than ellipsizing it. This fixes a reproduced 12px overflow in the 360px wallet fixture. No navigation, theme palette, price precision or source model changed. Existing page archetypes, 44px targets, keyboard and Reduce Motion behavior remain.

GitNexus: LoopRecordRow CRITICAL (177 direct, 46 processes, 8 modules); warning provided before edits. Market screen owners LOW (2 direct/2 processes). Index is 3 commits stale; current source and tests used as authoritative supplement. LoopLayout impact was inspected, but no layout constants changed.

## Validation

- Shared components + market pages/fidelity + wallet narrow-layout: 83 passed.
- New shared long-value wrap test + chart selection + market fidelity: 30 passed.
- Every source-backed marker remains controlled by existing provider models.
- Browser and final analysis/harness outcomes recorded in the aggregate report.

- Review caught short-value drift in an initial loose-flex implementation; replaced with explicit tight aligned columns. Final short-value/right-edge, long-value and wallet geometry regressions: 5 passed.
