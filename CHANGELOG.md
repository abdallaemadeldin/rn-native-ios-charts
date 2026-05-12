# Changelog

All notable changes to **rn-native-ios-charts** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — 1.0.0 (in progress)

The 1.0.0 release lands the production features the dashboard
charts have been waiting for: date axes (breaking — `x` becomes
`string | Date`), log scales, mark annotations + range bands,
chart-level animation modes, a JS-side scroll-driven scale wrapper
(uses `react-native-reanimated`), and the pie tooltip / highlight /
dismiss suite. Shipping incrementally on `master`; track this
section for what's already merged.

### Added (merged)

- **Pie tooltip with leader line + callout.** Enabling `tooltip`
  on `<PieChart>` now draws a short radial leader line from the
  selected slice's outer edge to a callout, anchored at the slice's
  midpoint angle just outside the chart's outer radius. The callout
  is clamped to the plot frame so it never overflows the chart's
  bounds, even at the topmost / bottommost slice angles. Mirrors
  the existing cartesian tooltip API — same `backgroundColor`,
  `textColor`, `borderColor`, `valuePrefix`, `valueSuffix`,
  `valueDecimals` fields.

- **Selected-slice highlight (animated).** When a slice is tapped
  and `tooltip.enabled` is true, the selected slice bumps outward
  slightly while unselected slices fade to `tooltip.dimOpacity`
  (default `0.3`). The scale-up is implemented by shrinking the
  unselected slices in tandem (configurable via
  `tooltip.sliceScale`, default `1.05`), so the effect can't
  overflow the chart frame. Animated with a spring (`response:
  0.32, dampingFraction: 0.72`) — independent of the slower data-
  change ease so taps feel snappier than redraws.

- **Tap-same-slice-to-toggle.** Tapping the currently-selected
  slice clears the selection instead of re-selecting it. Natural
  iOS feel — same as deselecting a row in a list.

- **In-chart miss dismisses selection.** A transparent backdrop
  layered behind the chart catches taps that miss every slice (the
  donut hole, corners of the bounding rect, gaps between bars),
  clearing both `selectedAngleY` (pie) and `selectedX` (cartesian).
  Slice / datum hits still go to `chartAngleSelection` /
  `chartXSelection` — only "misses" fall through.

- **`clearSelection()` imperative ref on `<PieChart>`.** New
  `PieChartHandle` type exposed via `React.forwardRef`. Call
  `chartRef.current?.clearSelection()` from a parent gesture
  handler (e.g. a `<Pressable>` covering the screen) to dismiss a
  sticky slice selection when the user taps outside the chart's
  host view — the case the in-chart backdrop can't reach.

- **`tooltip` prop on `<PieChart>`.** Previously absent; pies were
  selection-only with `onSelect` driving `centerLabel`. The
  centerLabel pattern still works; the new visual tooltip is opt-in
  via `tooltip.enabled`.

### Fixed

- **Pie chart didn't redraw / re-animate consistently on data
  prop changes** — the v0.x→1.0-alpha behavior had the chart
  animating new/exiting slices but skipping value updates on
  existing slices, and not animating color changes at all. Root
  cause: SwiftUI Charts doesn't reliably interpolate `SectorMark`
  angle and fill changes when the data binding lives directly on
  an `@ObservedObject` (`@Published`-driven updates bypass the
  framework's animation interpolator, and `AnyShapeStyle` fills
  don't always animate either). Fix: mirror `props.marks` into a
  local `@State` (`renderedMarks`) and drive every data change
  through an explicit `withAnimation { renderedMarks = props.marks }`
  inside `.onChange(of: marksFingerprint)`. SwiftUI Charts treats
  this as a single animated transaction and interpolates angle,
  position, AND fill consistently regardless of how small the
  value delta is. The fingerprint also now includes `color` so
  per-slice palette swaps trigger the animation. State-lookup
  helpers (`findActivePoint`, `selectedSliceData`, `emitSelect`)
  continue to read `props.marks` directly so taps reflect the
  latest data even mid-animation.

- **Pie chart redraw on data prop changes** (1.0.0-alpha.0 fix,
  re-stated). `ForEach(..., id: \.offset)` is now
  `\.element.identityKey` (`x|category`), stable across data
  swaps; slices get proper enter/exit transitions when label
  sets change.

### Added (merged in this push)

- **`animation` chart-level config.** New `AnimationConfig` type
  on every wrapper (and `<Chart>`) supersedes the boolean
  `animate` shorthand. Fields:
    - `enabled` (default true) — master toggle
    - `duration` (default 400ms) — data-change duration
    - `curve` — `"easeInOut" | "easeIn" | "easeOut" | "linear" |
      "spring"` (default `"easeInOut"`; spring tuning is fixed
      to a tap-feedback-friendly preset)
    - `entrance` (default false) — fade + scale 0.96→1.0 on first
      mount, capped at 600ms
    - `cartesianDimOnSelect` (default false) — dim non-active
      cartesian marks to `tooltip.dimOpacity` when the scrubber
      is engaged. Mirrors the pie's slice-dim for line / area /
      bar / point charts. Pie always dims when `tooltip.enabled`,
      regardless of this flag.

  The legacy `animate?: boolean` prop is still honored as a
  shorthand for `{ enabled: true }`; when both are passed,
  `animation` wins.

- **Date axis (breaking).** `DataPoint.x` is now `string | Date`,
  same for the per-wrapper `LinePoint`/`BarDatum`/`AreaDatum`/
  `ScatterDatum`/`RangeDatum`/`LineSeries.data` types and
  `Annotation.x` / `Annotation.xRange`. `Chart.tsx` normalizes
  `Date` instances to ISO-8601 strings before the Expo bridge;
  the SwiftUI side keeps a categorical X scale and reformats
  tick labels via `xAxis.valueFormat: "date"` + `xAxis.dateFormat`
  (default `"MMM yy"`, e.g. "Jan 26"). Pair with the date
  formatter for time-series:

  ```tsx
  <LineChart
    data={dailyPrices}   // [{ x: new Date(...), y: ... }, ...]
    xAxis={{ valueFormat: "date", dateFormat: "MMM yy" }}
    tooltip={{ enabled: true, valuePrefix: "$" }}
  />
  ```

  Tooltip X labels also honor `xAxis.dateFormat` automatically.

  **Note on scope.** This is the pragmatic version of date
  support — the chart's internal scale stays categorical, so
  you don't get SwiftUI's auto month/year tick aggregation for
  very long ranges. A true Date-domain `chartXScale` is on the
  roadmap for a follow-up. For typical 1–5y dashboards the
  visual output is identical.

- **Log scale (Y).** `AxisConfig.scaleType: "linear" | "log"`.
  Y-only — X stays categorical/date in this release.

  ```tsx
  <LineChart
    data={networthOverDecades}
    yAxis={{ scaleType: "log", domainMin: 1000, valueFormat: "abbreviated" }}
  />
  ```

  Log scales require all values strictly > 0. Set `domainMin` to
  clamp out zeros / negatives.

- **Annotations + range bands.** New `Annotation` type and
  `<Chart annotations={[]}>` prop. Two flavors:

    - **Datum-anchored** (set `x`) — floating label at that X.
    - **Range band** (set `xRange: [start, end]`) — shaded
      vertical band, optional centered/top/bottom label.

  `yRange?: [number, number]` constrains the vertical extent for
  bands (defaults to full plot height). Both styles accept
  `Date` for `x` / `xRange`, normalized identically to data.

  ```tsx
  <LineChart
    data={pricesByDate}
    xAxis={{ valueFormat: "date" }}
    annotations={[
      { x: new Date("2025-03-15"), text: "Earnings", position: "top" },
      {
        xRange: [new Date("2025-10-01"), new Date("2025-12-31")],
        text: "Q4",
        color: "#3B82F6",
        position: "inside",
      },
    ]}
  />
  ```

  Drawn in `chartOverlay` under the tooltip, so the active
  callout always paints on top.

- **`clearSelection()` ref on every wrapper.** `<LineChart>`,
  `<BarChart>`, `<AreaChart>`, `<ScatterChart>`, `<RangeBarChart>`
  now `forwardRef` the same `ChartHandle` interface as
  `<PieChart>`. The hook is also exported (`useChartHandle`)
  for consumers building their own wrappers. `PieChartHandle`
  remains as a type alias for `ChartHandle`.

### Added (scroll-driven animation)

- **`<ScrollAwareChart>` + `useChartScrollScale` hook.** JS-side
  scale + fade interpolation driven by a parent
  `Animated.ScrollView`'s scroll position. Runs entirely on the
  UI thread via Reanimated worklets — no bridge crossings. Adds
  `react-native-reanimated >= 3.0.0` as an **optional** peer
  dependency (only required if you import the scroll wrapper).
  Documented setup includes the `CADisableMinimumFrameDurationOnPhone`
  Info.plist flag needed for 120Hz on ProMotion. Compatible with
  Reanimated 4's `useScrollOffset` as an alternative scroll
  source. Hook + component are exported separately so consumers
  can compose the scroll-scale style with their own animated
  transforms.

### Added (docs & demo)

- **`examples/DemoScreen.tsx`** — comprehensive demo of every
  chart and every feature in one scrollable screen. Self-
  contained (no theme/parent deps beyond `react`, `react-native`,
  `react-native-reanimated`). Doubles as the visual regression
  sweep and the README's screenshot source. Now shipped inside
  the npm package via the `examples` files entry.

### Pending (still on the roadmap)

- **True Date-domain `chartXScale`** — auto month/year tick
  aggregation for multi-year time-series. The current date-axis
  feature gives nicely formatted ticks but stays categorical.

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
      positioning. SwiftUI Charts already stacks `BarMark`s that
      share an X value, so `"auto"` and `"stacked"` are equivalent
      (both lean on the framework default). `"grouped"` adds
      `position(by: .value("Series", category))` so the bars sit
      side-by-side, one column per series.
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

[Unreleased]: https://github.com/abdallaemadeldin/rn-native-ios-charts/compare/v0.2.3...HEAD
[0.2.0]: https://github.com/abdallaemadeldin/rn-native-ios-charts/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/abdallaemadeldin/rn-native-ios-charts/releases/tag/v0.1.0
