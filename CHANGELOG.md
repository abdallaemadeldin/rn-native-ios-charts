# Changelog

All notable changes to **rn-native-ios-charts** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/abdallaemadeldin/rn-native-ios-charts/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/abdallaemadeldin/rn-native-ios-charts/releases/tag/v0.1.0
