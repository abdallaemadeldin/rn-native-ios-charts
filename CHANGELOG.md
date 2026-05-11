# Changelog

All notable changes to **rn-native-ios-charts** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-05-11

Production-grade upgrades: trading-chart props, multi-series support,
axis value formatters, richer tooltip + selection payloads, and an
axis-config bug fix that surfaced once people actually customized
their axes.

### Added

- **`tightX`** prop on `<Chart />` / `<LineChart />` / `<BarChart />`
  — zeros out SwiftUI Charts' default plot-dimension X padding so
  the first and last data points sit flush against the chart's left
  and right edges. The "Robinhood / Apple Stocks" look. Pair with
  `xAxis={{ hidden: true }}` for a clean trading-chart aesthetic.
- **`scrollableX`** + **`visibleXCount`** — enables SwiftUI's
  native `chartScrollableAxes(.horizontal)` plus
  `chartXVisibleDomain(length:)`. Use this instead of wrapping the
  chart in an RN `<ScrollView horizontal>` — native scrolling
  keeps tooltip coordinates correct and avoids gesture conflicts
  with the selection scrubber.
- **`categoryColors`** chart-level prop — maps `category` →
  `ColorValue`. Translates to SwiftUI's
  `chartForegroundStyleScale`. Define a palette once at the chart
  level instead of repeating `color` on every datum.
- **Axis value formatters.** `AxisConfig` now honors `valueFormat`
  (`"raw" | "currency" | "percent" | "abbreviated" | "decimal"`),
  `currencyCode`, `valueDecimals`, `valuePrefix`, and `valueSuffix`.
  Common patterns:
  ```tsx
  yAxis={{ valueFormat: "currency", currencyCode: "USD" }}
  yAxis={{ valuePrefix: "$", valueDecimals: 0 }}     // symbol-only
  yAxis={{ valueFormat: "abbreviated" }}             // 1K / 1.2M
  yAxis={{ valueFormat: "percent" }}                 // 0.5 → "50%"
  ```
- **Multi-series tooltip.** `tooltip.multiSeries` renders one row
  per cartesian mark at the selected X (color dot + series name +
  formatted value). Drops to a single-row callout automatically
  when only one mark is present. Useful for OHLC stock charts and
  side-by-side comparisons.
- **`markIndex` + `pointIndex` in the `onSelect` payload.** Lets
  consumers locate the datum in their `marks` array
  deterministically — value-only matching is fragile when two
  slices share the same y. Existing single-key consumers continue
  to work; the indices are additive.
- **Multi-line `<LineChart>` via the new `series` prop.** Pass an
  array of `{ name, color, data, ...overrides }` to draw multiple
  lines on the same plot. Each series' `name` becomes the
  `category` key, the legend label, and the row label in the
  multi-series tooltip. The existing `data` prop still works for
  single-series charts.
- **Bar chart enhancements.** Two new fields on `bar` marks (and
  the matching `<BarChart>` props):
    - `position: "auto" | "stacked" | "grouped"` — multi-series
      positioning. `"stacked"` applies SwiftUI's
      `positionAdjustment(.stacking)`; `"grouped"` applies
      `position(by: .value("Series", category))` so bars sit
      side-by-side.
    - `horizontal: boolean` — swaps the X and Y axes for `bar`
      marks. Use for Top-N lists and ranked leaderboards.

### Fixed

- **Axis customization fields now actually apply.** `xAxis` /
  `yAxis` config has supported `labelColor`, `labelFontSize`,
  `gridColor`, `gridLines`, and `tickLabels` since v0.1.0, but the
  Swift side only toggled `.hidden` vs `.automatic` and silently
  ignored the rest. Replaced the boolean toggle with a full
  `AxisMarks` builder so every field is honored.

  **Migration note:** if you were passing these fields and worked
  around the lack of effect (e.g. extra padding to hide the
  default label color), your chart will now render with the
  requested style. Visual diffs are possible.

## [0.1.0] — 2026-05-11

Initial public release. iOS-only Expo module that bridges every SwiftUI
`Charts` mark type to React Native with a single composable `<Chart />`
primitive plus convenience wrappers.

### Added

- **Generic `<Chart />`** — renders any combination of `bar`, `line`,
  `area`, `point`, `rectangle`, `rule`, and `sector` marks in a single
  view.
- **Convenience wrappers** — `<PieChart />`, `<LineChart />`,
  `<AreaChart />`, `<BarChart />`, `<ScatterChart />`, `<RangeBarChart />`.
  All delegate to the generic primitive.
- **Pie / donut `centerLabel`** — value + caption slot rendered inside
  the chart's plot frame via SwiftUI's `chartBackground` +
  `ChartProxy.plotFrame`. Tracks the donut centre natively, no JS
  overlays.
- **Native gradients** — `LinearGradient` on any mark's
  `foregroundStyle` with two-stop shorthand (`startOpacity` /
  `endOpacity`) or full multi-stop `stops`.
- **Per-point overrides** — every datum can carry its own `color` and
  `category` (series key for auto-coloring + legend grouping).
- **Interactive tooltips** — opt-in `tooltip` prop drives SwiftUI's
  native `chartXSelection` scrubber: vertical rule + highlighted dot +
  auto-clamped callout. All rendered inside the SwiftUI view hierarchy,
  no JS frame round-trips. Configurable colors, value prefix/suffix,
  decimal places.
- **`onSelect` event** — fires when the user picks a point via the
  scrubber or taps a pie sector. Pie uses native `chartAngleSelection`.
- **Line interpolation** — `linear`, `catmullRom`, `monotone`,
  `stepStart`, `stepEnd`, `stepCenter`.
- **Symbols** — `circle`, `square`, `triangle`, `diamond`, `pentagon`,
  `plus`, `cross`, `asterisk`. With `symbolSize` and `showPoints`.
- **Axis config** — hidden, grid lines, tick labels, label color & font
  size, custom `[domainMin, domainMax]`.
- **Legend config** — hidden, placement (`top`, `bottom`, `leading`,
  `trailing`, `overlay`, `automatic`).
- **`isChartSupported()`** — runtime feature-detection helper. Use it
  to mount a fallback chart library on iOS < 17 and on Android / web.

### Platform support

- **iOS 17+** — full rendering (SwiftUI Charts unified API).
- **iOS 15.1–16.x** — pod installs cleanly so the module can be a
  dependency of any modern Expo app, but `<Chart />` renders an empty
  view. The SwiftUI Charts unified API isn't available pre-17.
- **Android / web** — components render a transparent placeholder
  `View` so consuming code doesn't need to feature-detect. Pair with
  `isChartSupported()` to swap in an alternative renderer.

[Unreleased]: https://github.com/abdallaemadeldin/rn-native-ios-charts/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/abdallaemadeldin/rn-native-ios-charts/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/abdallaemadeldin/rn-native-ios-charts/releases/tag/v0.1.0
