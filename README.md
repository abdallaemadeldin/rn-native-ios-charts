# rn-native-ios-charts

> Native SwiftUI Charts for React Native / Expo. **iOS-only.** No SVG, no
> Skia, no canvas approximations — every line and slice is drawn by Apple's
> own `Charts` framework.

<p align="center">
  <img src="https://raw.githubusercontent.com/abdallaemadeldin/rn-native-ios-charts/HEAD/docs/demo-v1.gif" alt="rn-native-ios-charts 1.0 demo" width="360" />
</p>

> [▶ Watch HD version](https://github.com/abdallaemadeldin/rn-native-ios-charts/raw/HEAD/docs/demo-v1.mp4) — 1.0 walkthrough: pie tooltip + slice highlight + dismiss, date axis with annotations, log scale, multi-series stacked tooltip, scroll-aware scale, and every other chart type. ([0.x demo](https://github.com/abdallaemadeldin/rn-native-ios-charts/raw/HEAD/docs/demo.mp4) is still archived for reference.)

Cross-platform RN chart libraries (Victory, Skia, gifted-charts, etc.) all
hit the same iOS ceilings:

- Pie / donut charts can't put a label inside the hole that actually
  tracks the chart's plot frame.
- Line and area charts can't use a real `LinearGradient` for the fill —
  they either solid-fill or fake it with `<defs><linearGradient>`.
- Tooltips, when they exist, are JS overlays that flicker and lag
  behind the gesture — instead of SwiftUI's native `chartXSelection`
  that snaps to data points with zero JS round-trips.
- iOS 17+ Charts features (`chartBackground`, `chartXScale`, mixed
  marks in a single Chart, native interpolation methods, etc.) aren't
  exposed at all.

This module is a thin Expo wrapper over SwiftUI `Charts` that exposes
every mark type and every modifier we've needed in production. iOS-only
by design — Android / web mount a no-op `<View />` so consuming code
doesn't need to feature-detect.

## See it all in one place — `examples/DemoScreen.tsx`

The package ships a comprehensive demo screen at
[`examples/DemoScreen.tsx`](./examples/DemoScreen.tsx) that
exercises every chart type and every feature in this README:

- Pie with tooltip + slice highlight + tap-outside dismiss, plus
  tab-switching across three data shapes (same labels, different
  labels, different counts) so you can verify the redraw fix.
- Line — single series with area, multi-series with stacked
  tooltip + cartesian dim-on-select, `tightX` trading-chart preset.
- Date axis with annotations + range bands.
- Log Y-scale for long-horizon growth.
- Area with native gradient fill.
- Bar — grouped, stacked, horizontal Top-N.
- Scatter with per-category palette.
- Range bar (OHLC-style).
- Generic `<Chart>` with mixed marks (area + line + reference rule
  + annotation).
- `<ScrollAwareChart>` wrapping a chart at the bottom — scroll the
  page to feel the scale + fade interpolation.

Drop it into any Expo route to use as a regression sweep or as a
copy-paste-friendly starting point:

```tsx
// app/charts-demo.tsx
import { DemoScreen } from "rn-native-ios-charts/examples/DemoScreen";
export default function ChartsDemoRoute() {
  return <DemoScreen />;
}
```

Self-contained — no theme system, no parent-project deps beyond
`react`, `react-native`, `react-native-reanimated`, and this
package.

## Components

### `<Chart />` — the generic, composable view

Render any combination of marks in a single chart. This is what every
convenience wrapper below delegates to.

```tsx
import { Chart } from "rn-native-ios-charts";

<Chart
  style={{ width: "100%", height: 240 }}
  marks={[
    {
      type: "area",
      data: yearTotals,
      color: "#1FA92E",
      gradient: { startOpacity: 0.35, endOpacity: 0.02 },
      interpolation: "catmullRom",
    },
    {
      type: "line",
      data: yearTotals,
      color: "#1FA92E",
      lineWidth: 2.5,
      interpolation: "catmullRom",
      showPoints: true,
      symbol: "circle",
    },
    {
      type: "rule",
      data: [],
      ruleValue: 0,
      color: "#9BA1A6",
      dashArray: [4, 4],
    },
  ]}
  xAxis={{ hidden: false, gridLines: true }}
  yAxis={{ hidden: false, gridLines: true }}
  legend={{ hidden: true }}
  animate
/>
```

### Convenience wrappers

| Component         | What it renders                                                       |
| ----------------- | --------------------------------------------------------------------- |
| `<PieChart />`    | `sector` marks. Donut hole + optional center label slot.              |
| `<LineChart />`   | `line` mark, optionally with `area` underneath (the `area` prop).     |
| `<AreaChart />`   | `area` mark with native linear gradient fill.                         |
| `<BarChart />`    | `bar` marks. Single series or multi-series via `category`.            |
| `<ScatterChart />`| `point` marks with configurable symbol + size.                        |
| `<RangeBarChart />`| `rectangle` marks between `yStart` and `yEnd` (candles, ranges, etc).|

### Runtime helper

| Export                | Returns                                                          |
| --------------------- | ---------------------------------------------------------------- |
| `isChartSupported()`  | `true` only on iOS 17+. Use to mount a fallback renderer on iOS 15–16 and on Android / web. See [Feature-detecting at runtime](#feature-detecting-at-runtime). |

Example — pie with center label:

```tsx
import { PieChart } from "rn-native-ios-charts";

<PieChart
  style={{ width: 240, height: 240 }}
  data={[
    { label: "Cash", value: 86, color: "#1FA92E" },
    { label: "Stocks", value: 50, color: "#3B82F6" },
  ]}
  innerRadius={0.62}
  angularInset={2}
  centerLabel={{
    value: "$136",
    label: "Total",
    valueColor: "#FFFFFF",
    labelColor: "#9BA1A6",
  }}
/>
```

The center label is rendered **inside the chart's plot frame** via
SwiftUI's `chartBackground` + `ChartProxy.plotFrame`, so it tracks the
donut's actual center and scales with the chart automatically. No JS
overlays, no `onLayout` tricks.

Example — gradient line:

```tsx
import { LineChart } from "rn-native-ios-charts";

<LineChart
  style={{ width: "100%", height: 200 }}
  data={[
    { x: "2024", y: 12000 },
    { x: "2025", y: 38000 },
    { x: "2026", y: 86000 },
  ]}
  color="#1FA92E"
  area={{ startOpacity: 0.35, endOpacity: 0.02 }}
  interpolation="catmullRom"
  showPoints
/>
```

## Trading-chart preset — `tightX` + hidden axes

For the Robinhood / Apple Stocks aesthetic — line flush against
both screen edges, no axes, no grid, deep gradient fill. The `tightX`
prop zeros out SwiftUI Charts' default plot-dimension padding so the
first and last points sit at the chart's left and right edges.

```tsx
import { LineChart } from "rn-native-ios-charts";

<LineChart
  style={{ width: "100%", height: 260 }}
  data={dailyPrice}
  color="#1FA92E"
  lineWidth={3}
  interpolation="catmullRom"
  area={{ startOpacity: 0.55, endOpacity: 0 }}
  tightX
  xAxis={{ hidden: true }}
  yAxis={{ hidden: true }}
  tooltip={{ enabled: true, valuePrefix: "$" }}
/>
```

## Multi-line charts — `<LineChart series={…} />`

Render multiple lines on the same plot by passing a `series` array
instead of a single `data` array. Each series has its own color and
its own line config (width, dash, interpolation, points, symbol,
area) — chart-level props act as fallbacks.

```tsx
import { LineChart } from "rn-native-ios-charts";

<LineChart
  // Chart-level defaults
  lineWidth={2}
  interpolation="catmullRom"
  series={[
    {
      name: "Revenue",
      color: "#1FA92E",
      data: revenueByMonth,
      area: { startOpacity: 0.4, endOpacity: 0 },  // shaded under this one
    },
    {
      name: "Expenses",
      color: "#F59E0B",
      data: expensesByMonth,
      lineWidth: 3,
      dashArray: [6, 4],     // dashed
    },
    {
      name: "Forecast",
      color: "#3B82F6",
      data: forecastByMonth,
      interpolation: "linear",
      showPoints: true,
      symbol: "diamond",
    },
  ]}
  tooltip={{ enabled: true, multiSeries: true, valuePrefix: "$" }}
/>
```

Each series' `name` becomes:

- the `category` key on every point (so SwiftUI groups them into one
  continuous line),
- the legend label, and
- the row label in the multi-series tooltip (see below).

The single-series `data` prop still works for one-line charts — pass
either `data` **or** `series`, not both. If both, `series` wins.

## Multi-series tooltip

Pair multi-line charts with `tooltip.multiSeries` to get a stacked-row
callout: one row per cartesian mark at the selected X, each with the
series' color dot, name, and formatted value.

```tsx
<LineChart
  series={[ /* multiple series as above */ ]}
  tooltip={{
    enabled: true,
    multiSeries: true,         // <-- enables the stacked-row callout
    valuePrefix: "$",
    backgroundColor: "#161618",
    textColor: "#FFFFFF",
    borderColor: "#2A2A2D",
  }}
/>
```

When the chart has only one cartesian mark, `multiSeries` silently
falls back to the regular single-row tooltip — safe to leave on.

## Scroll-aware scale — `<ScrollAwareChart>`

Native-iOS feel for "card scales up when centered in the viewport"
dashboards. The scale (and optional fade) interpolates against
the chart's distance from viewport center, driven by your
`Animated.ScrollView`'s scroll position — all frame computation
stays on the UI thread via Reanimated worklets, so no JS bridge
crossings and no jank.

```tsx
import Animated, {
  useAnimatedScrollHandler,
  useSharedValue,
} from "react-native-reanimated";
import { ScrollAwareChart, LineChart } from "rn-native-ios-charts";

const scrollY = useSharedValue(0);
const onScroll = useAnimatedScrollHandler({
  onScroll: (e) => { scrollY.value = e.contentOffset.y; },
});

<Animated.ScrollView onScroll={onScroll} scrollEventThrottle={16}>
  <ScrollAwareChart scrollY={scrollY} fadeOut>
    <LineChart {...} tooltip={{ enabled: true }} />
  </ScrollAwareChart>
  {/* …other cards… */}
</Animated.ScrollView>
```

### Options

| Field | Default | Effect |
| --- | --- | --- |
| `scrollY` | required | `SharedValue<number>` driven by the parent scroll handler. |
| `minScale` | `0.92` | Scale when the chart sits at the edges of `range`. |
| `maxScale` | `1.0` | Scale when centered in the viewport. |
| `fadeOut` | `false` | Also interpolate opacity. |
| `minOpacity` | `0.5` | Opacity at the edges of `range` when `fadeOut: true`. |
| `range` | `320` | Distance from viewport center (px) at which scale reaches `minScale`. Larger = gentler ramp. |
| `viewportHeight` | window height | Override if your ScrollView is inset (modal sheet, behind a tab bar). |

### Just the hook

If you want to compose the scroll-scale style with your own
animated transforms (shadows, tilt, parallax), use the hook
directly:

```tsx
import { useChartScrollScale } from "rn-native-ios-charts";

const { onLayout, style } = useChartScrollScale(scrollY, { fadeOut: true });

<Animated.View onLayout={onLayout} style={[style, myCardShadow]}>
  <LineChart {...} />
</Animated.View>
```

### Requirements

- **`react-native-reanimated >= 3.0.0`** as a peer dependency.
  Declared optional, but importing `<ScrollAwareChart>` without it
  installed will throw at module load — install it.
- **For 120Hz on ProMotion devices**, add to your app's `Info.plist`:
  ```xml
  <key>CADisableMinimumFrameDurationOnPhone</key>
  <true/>
  ```
  iOS caps third-party apps at 60Hz on ProMotion without this
  flag, regardless of what Reanimated does. With it set and a UI-
  thread-only worklet (the default for `useAnimatedStyle`), you
  get 120Hz "for free."
- In Reanimated 4+, `useScrollOffset(scrollRef)` is a cleaner
  one-liner alternative to `useAnimatedScrollHandler` when you
  don't need momentum/drag callbacks — feel free to use it as
  the `scrollY` source instead.

### Don't use inside recycled list cells

`FlatList`/`FlashList` reuse cell instances, which keeps the
shared values bound to the old row's layout. The result is
stale scale values on the new row. Either:

1. Wrap each chart at the screen level (outside the list), or
2. Key your row component on the item id to force a fresh mount.

For per-row scroll animation inside a recycled list, prefer
Reanimated's `useAnimatedRef` + `measure()` worklet pattern with
per-row shared values.

## Animation config — `animation`

Every wrapper (and `<Chart>`) accepts an `animation` prop that
controls both data-change transitions and an optional entrance
animation:

```tsx
<LineChart
  data={monthlyRevenue}
  animation={{
    enabled: true,
    duration: 400,          // ms
    curve: "easeInOut",     // or "easeIn" | "easeOut" | "linear" | "spring"
    entrance: true,         // fade + scale 0.96→1 on first mount
    cartesianDimOnSelect: true,  // dim non-active marks when scrubber engages
  }}
  tooltip={{ enabled: true }}
/>
```

| Field | Default | Effect |
| --- | --- | --- |
| `enabled` | `true` | Master toggle. `false` kills every animation including entrance and selection feedback. |
| `duration` | `400` | Milliseconds for data-change transitions. Ignored when `curve` is `"spring"`. |
| `curve` | `"easeInOut"` | One of `"easeInOut" \| "easeIn" \| "easeOut" \| "linear" \| "spring"`. |
| `entrance` | `false` | Scale-from-0.96 + fade-in on first mount. Capped at 600ms regardless of `duration`. |
| `cartesianDimOnSelect` | `false` | When the scrubber tooltip is active, fade non-active cartesian marks to `tooltip.dimOpacity`. Pie always dims when `tooltip.enabled` — this only affects line/area/bar/point. |

The legacy `animate?: boolean` shorthand still works
(`animate: false` disables everything, same as `animation: { enabled: false }`).
When both `animate` and `animation` are passed, `animation` wins.

Selection animations (pie slice scale + dim, cartesian dim-on-select)
use a fixed spring tuned for tap feedback rather than the
data-change curve — taps shouldn't feel as slow as redraws.

## Date axis — pass `Date` objects for `x`

Time-series charts can pass `Date` objects directly as the `x`
value. The chart serializes them to ISO-8601 on the bridge and
formats tick labels via `xAxis.valueFormat: "date"`:

```tsx
<LineChart
  data={[
    { x: new Date("2025-01-01"), y: 12000 },
    { x: new Date("2025-06-01"), y: 38000 },
    { x: new Date("2026-01-01"), y: 86000 },
  ]}
  xAxis={{
    valueFormat: "date",
    dateFormat: "MMM yy",   // → "Jan 25", "Jun 25", "Jan 26"
  }}
  tooltip={{ enabled: true, valuePrefix: "$" }}
/>
```

| `dateFormat` | Output |
| --- | --- |
| `"MMM yy"` (default) | `Jan 26` |
| `"MMM d"` | `Jan 15` |
| `"yyyy"` | `2026` |
| `"MMM d, yyyy"` | `Jan 15, 2026` |
| `"HH:mm"` | `14:30` |

Apple `DateFormatter` syntax (UTS #35) — see
[nsdateformatter.com](https://nsdateformatter.com) for a live
preview. Tooltip X labels honor the same format automatically.

**Scope note.** The chart's internal scale stays categorical —
each date you pass becomes one tick. For multi-year ranges with
daily data you'll want to thin the input array yourself (e.g.
"first business day of each month") rather than relying on
auto-aggregation. A true `Date`-domain `chartXScale` with
auto-tick aggregation is on the roadmap.

## Log scale — `yAxis.scaleType`

For long-horizon growth charts (where linear flattens the early
years into nothing), set `yAxis.scaleType: "log"`:

```tsx
<LineChart
  data={networthSince2010}     // [{ x: new Date(...), y: 10000 }, ... { y: 1_500_000 }]
  yAxis={{
    scaleType: "log",
    domainMin: 1000,           // log scales require y > 0; clamp out outliers
    valueFormat: "abbreviated",
  }}
  xAxis={{ valueFormat: "date" }}
/>
```

Y-only for this release. Log scales require strictly positive
values — set a positive `domainMin` to clip zeros / negatives.

## Annotations & range bands

Annotations are commentary layered on top of the marks —
datum-anchored labels (a "Q1 earnings" callout above one bar) or
shaded vertical bands (a "Q4" shaded region across a date range).
They live outside `marks` so toggling commentary doesn't touch
the data:

```tsx
<LineChart
  data={pricesByDate}
  xAxis={{ valueFormat: "date" }}
  annotations={[
    // Datum-anchored — floats near the top of the plot at this X.
    {
      x: new Date("2025-03-15"),
      text: "Earnings",
      color: "#1FA92E",
      position: "top",
    },
    // Range band — shaded vertical region between two dates.
    {
      xRange: [new Date("2025-10-01"), new Date("2025-12-31")],
      text: "Q4",
      color: "#3B82F6",
      position: "inside",
    },
    // Range band constrained to a Y window.
    {
      xRange: [new Date("2025-04-01"), new Date("2025-06-30")],
      yRange: [40, 60],
      text: "target zone",
      color: "#F59E0B",
    },
  ]}
/>
```

| Field | Notes |
| --- | --- |
| `x` | Datum anchor (use **either** `x` or `xRange`, not both). Accepts `Date`. |
| `xRange: [from, to]` | Range band endpoints. Accepts `Date`. |
| `yRange?: [lo, hi]` | Optional vertical extent (data coords). Defaults to full plot. |
| `text?` | Optional label. Omit for marker-only bands. |
| `color?` | Band fill / label color. Defaults to system blue (bands) / label (labels). |
| `position?` | `"top" \| "bottom" \| "inside"`. Default `"top"`. |
| `fontSize?` | Label font size in pt. Default 11. |

Drawn under the tooltip so the active callout always paints on
top.

## Axis value formatters

Format the tick labels on either axis without writing custom Swift.
Supports four common formats plus optional prefix/suffix; works on
numeric axes (in practice: the Y axis, since X is `String`).

```tsx
<LineChart
  data={annualRevenue}
  yAxis={{ valueFormat: "currency", currencyCode: "USD" }}
/>

<LineChart
  data={percentReturns}
  yAxis={{ valueFormat: "percent" }}    // 0.5 → "50%"
/>

<LineChart
  data={networthOverTime}
  yAxis={{ valueFormat: "abbreviated" }} // 1K, 1.2M, 3.4B
/>

<LineChart
  data={returns}
  yAxis={{ valuePrefix: "$", valueDecimals: 0 }}  // symbol-only "$50,000"
/>
```

| `valueFormat` | Output (en-US)            | Notes                                  |
| ------------- | ------------------------- | -------------------------------------- |
| `"raw"` (default) | `50000`               | Plain number with `valueDecimals`.     |
| `"currency"`  | `$50,000.00`              | Locale-aware. Uses `currencyCode`.     |
| `"percent"`   | `50%`                     | SwiftUI multiplies by 100 — pass `0.5` to render `"50%"`. For pre-scaled (0–100) values, use `valueSuffix: "%"` instead. |
| `"abbreviated"` | `50K`, `1.2M`, `3.4B`   | Compact notation.                      |
| `"decimal"`   | `50,000.00`               | Plain decimal with thousands separators. |

`valuePrefix` / `valueSuffix` are applied after the format style, so
`valueFormat: "decimal" + valuePrefix: "$"` gives you symbol-only
currency without locale code lookups.

## Category color palettes — `categoryColors`

When your data has `category` values, set a chart-level palette
instead of repeating `color` on every datum. Translates to SwiftUI's
`chartForegroundStyleScale`.

```tsx
<LineChart
  series={[
    { name: "Cash", data: cashData },
    { name: "Stocks", data: stocksData },
    { name: "Bonds", data: bondsData },
  ]}
  categoryColors={{
    Cash:   "#1FA92E",
    Stocks: "#3B82F6",
    Bonds:  "#F59E0B",
  }}
/>
```

Per-series `color` (or per-point `color`) always overrides
`categoryColors` when both are set.

## Bar charts — stacking & horizontal

`<BarChart>` (and `bar` marks on the generic `<Chart>`) accept two
extra fields for multi-series layouts:

```tsx
// Stacked bars
<BarChart
  data={[
    { x: "Q1", y: 24, category: "Revenue" },
    { x: "Q1", y: 18, category: "Expenses" },
    { x: "Q2", y: 31, category: "Revenue" },
    { x: "Q2", y: 22, category: "Expenses" },
  ]}
  position="stacked"
  categoryColors={{ Revenue: "#1FA92E", Expenses: "#F59E0B" }}
/>

// Grouped (side-by-side)
<BarChart
  data={/* same data */}
  position="grouped"
  categoryColors={{ Revenue: "#1FA92E", Expenses: "#F59E0B" }}
/>

// Horizontal bars — Top-N / ranked leaderboards
<BarChart
  data={topAssetsByValue}      // [{ x: "AAPL", y: 38000 }, ...]
  horizontal
  cornerRadius={4}
/>
```

| Prop         | Effect                                                                 |
| ------------ | ---------------------------------------------------------------------- |
| `position: "auto"`    | SwiftUI's default — multiple bars at the same X stack.        |
| `position: "stacked"` | Same as `"auto"`. SwiftUI Charts already stacks by default — this label is an explicit alias for readability. |
| `position: "grouped"` | Applies `.position(by: .value("Series", category))`.          |
| `horizontal: true`    | Swaps X and Y on `BarMark` — labels on the Y axis.            |

## Horizontal scrolling for long time series

When you have more data points than fit on screen, use SwiftUI's
native `chartScrollableAxes(.horizontal)` instead of wrapping the
chart in an RN `<ScrollView horizontal>` — that wrapper would steal
the scrubber's pan gesture and shift the tooltip's touch coordinates.

```tsx
<LineChart
  data={twoYearsOfDailyData}      // ~730 points
  scrollableX                     // enables native horizontal scroll
  visibleXCount={30}              // show ~30 days per "page"
  tooltip={{ enabled: true }}     // scrubber + tooltip still work
/>
```

`visibleXCount` is optional — omit it (or pass 0) to let SwiftUI
auto-decide.

## Interactivity — native tooltips & selection

All cartesian charts (line, area, bar, point, rectangle) support
SwiftUI's native `chartXSelection` scrubber. Long-press + drag and
the tooltip follows your finger, snapping to the nearest data point.
No JS frame round-trips — the highlight, scrubber rule and callout
are all drawn inside the SwiftUI view hierarchy.

```tsx
import { LineChart } from "rn-native-ios-charts";

<LineChart
  data={monthlyRevenue}
  color="#1FA92E"
  area={{ startOpacity: 0.35, endOpacity: 0.02 }}
  tooltip={{
    enabled: true,
    valuePrefix: "$",
    valueDecimals: 0,
    backgroundColor: "#161618",
    textColor: "#FFFFFF",
    borderColor: "#2A2A2D",
  }}
  onSelect={(point) => {
    if (point) console.log(`${point.x}: $${point.y}`);
  }}
/>
```

### `tooltip` config

| Field             | Default                | Notes                                                  |
| ----------------- | ---------------------- | ------------------------------------------------------ |
| `enabled`         | `false`                | Opt-in — charts stay static unless you set this.       |
| `showRule`        | `true`                 | Dashed vertical line at the selected X.                |
| `showDot`         | `true`                 | Filled dot at the active point, ringed in `backgroundColor`. |
| `showTitle`       | `true`                 | Show the `x` label above the value in the callout.     |
| `backgroundColor` | system background      | Callout fill.                                          |
| `textColor`       | system label           | Callout text.                                          |
| `borderColor`     | system separator       | Callout border + scrubber rule.                        |
| `valuePrefix`     | `""`                   | Prepended to the y value, e.g. `"$"`.                  |
| `valueSuffix`     | `""`                   | Appended, e.g. `"%"`.                                  |
| `valueDecimals`   | `0`                    | Decimal places. Numbers always get thousands separators. |

The callout is positioned above the active point and **auto-clamped
to the plot frame** — it never overflows the chart's bounds, even at
the leftmost / rightmost / topmost data points.

### `onSelect` event

Fires every time the selection changes (including when it clears):

```ts
type SelectedPoint = {
  x: string;
  y: number;
  /** Index of the mark this point belongs to (0-based). */
  markIndex: number;
  /** Index of the point within that mark's data (0-based). */
  pointIndex: number;
} | null;

onSelect?: (point: SelectedPoint) => void;
```

The `markIndex` + `pointIndex` pair locates the datum in the caller's
`marks` array deterministically — value-only matching is fragile
when two slices or points share the same y. Pies emit the slice
index on tap; cartesian charts emit the first cartesian mark's
index for the selected X.

For pie / donut charts, `onSelect` fires on slice taps via
`chartAngleSelection`. As of 1.0, you can either:

1. **Drive `centerLabel` from the selection** — classic donut-hole
   readout pattern (still the right call for compact dashboards):

```tsx
import { useState } from "react";
import { PieChart } from "rn-native-ios-charts";

const [center, setCenter] = useState({ value: "$148K", label: "Total" });

<PieChart
  data={portfolio}
  innerRadius={0.62}
  centerLabel={{ ...center, valueColor: "#FFFFFF", labelColor: "#9BA1A6" }}
  onSelect={(point) => {
    setCenter(
      point
        ? { value: `$${point.y}K`, label: point.x }
        : { value: "$148K", label: "Total" }
    );
  }}
/>
```

2. **Enable the visual callout** with `tooltip.enabled` — see
   [Pie tooltip & slice highlight](#pie-tooltip--slice-highlight)
   below. The callout, slice bump, and dim-others animation are all
   native-drawn; you don't have to write any of it.

## Pie tooltip & slice highlight

Pass `tooltip` to `<PieChart>` and the chart will:

1. **Bump the selected slice** outward (`tooltip.sliceScale`,
   default `1.05`). Implemented by shrinking the unselected slices
   in tandem so the bump can't overflow the chart frame.
2. **Dim unselected slices** to `tooltip.dimOpacity` (default
   `0.3`).
3. **Draw a leader line + callout** from the slice's outer edge to
   a bubble anchored just outside the chart's outer radius at the
   slice's midpoint angle. The callout is clamped to the chart's
   bounds so it never spills past the host view.
4. **Toggle on re-tap** — tapping the same slice again clears the
   selection.
5. **Dismiss on miss** — tapping empty area inside the chart frame
   (the donut hole, corners, gaps) clears too.

```tsx
import { useRef } from "react";
import { Pressable, Text, View } from "react-native";
import { PieChart, type PieChartHandle } from "rn-native-ios-charts";

const chartRef = useRef<PieChartHandle>(null);

<View style={{ alignItems: "center" }}>
  <PieChart
    ref={chartRef}
    style={{ width: 240, height: 240 }}
    data={portfolio}
    innerRadius={0.62}
    angularInset={2}
    cornerRadius={4}
    tooltip={{
      enabled: true,
      valuePrefix: "$",
      valueDecimals: 0,
      backgroundColor: "#161618",
      textColor: "#FFFFFF",
      borderColor: "#2A2A2D",
      // Pie-specific tuning:
      dimOpacity: 0.3,   // fade unselected slices
      sliceScale: 1.05,  // bump selected slice
    }}
    onSelect={(point) => {
      if (point) console.log(`${point.x}: $${point.y}`);
    }}
  />
  {/* External dismiss button — sits OUTSIDE the chart so it
      doesn't fight the chart's gestures. See the section below
      for why wrapping the chart in <Pressable> doesn't work. */}
  <Pressable onPress={() => chartRef.current?.clearSelection()}>
    <Text>Clear selection</Text>
  </Pressable>
</View>
```

### Dismissing the selection

| Action | What happens |
| --- | --- |
| **Tap a different slice** | Selection switches to that slice. |
| **Tap the same selected slice** | Selection clears (toggle). |
| **`chartRef.current?.clearSelection()`** | Selection clears programmatically. |

> **Note.** An earlier alpha had a "tap empty area inside the chart frame to clear" path via a transparent backdrop, but the backdrop's `.onTapGesture` competed with `chartAngleSelection`'s slice-tap gesture and made the tooltip flicker / fail to appear. It's been removed. A geometry-aware version that only fires on taps outside the pie's angular footprint is on the roadmap.

### Pitfall — don't wrap the chart in `<Pressable>`

Tempting pattern: `<Pressable onPress={clear}><PieChart /></Pressable>`.
Broken. RN's responder chain claims taps inside the Pressable
*before* SwiftUI's `chartAngleSelection` sees them, so every slice
tap fires `clear()` instead of selecting the slice. The chart
appears unresponsive to taps.

For tap-outside-the-chart dismiss, place the `<Pressable>` as a
**sibling** of the chart (above, below, or absolutely positioned
behind it with `pointerEvents="box-only"`), never wrapping it.
The chart already handles "tap empty area inside my own bounds"
via its internal backdrop — you only need the external Pressable
for clicks well away from the chart.

`clearSelection()` is the single method on the shared `ChartHandle`
type — every wrapper (`PieChart`, `LineChart`, `BarChart`,
`AreaChart`, `ScatterChart`, `RangeBarChart`) `forwardRef`s the
same interface. `PieChartHandle` is kept as a type alias for
`ChartHandle` so existing code keeps working:

```tsx
import { useRef } from "react";
import { LineChart, type ChartHandle } from "rn-native-ios-charts";

const chartRef = useRef<ChartHandle>(null);

<LineChart ref={chartRef} data={...} tooltip={{ enabled: true }} />

// Anywhere:
chartRef.current?.clearSelection();
```

For consumers building their own wrappers, `useChartHandle(ref)`
is exported — it returns the `clearSelectionToken` you pass to
`<Chart>` and wires up the imperative method on the ref.

### When `tooltip.enabled` is `false`

`onSelect` still fires on slice taps (so the `centerLabel` pattern
keeps working), but no leader line / callout / highlight is drawn.
This mirrors the cartesian charts' opt-in tooltip behavior — charts
stay static unless you explicitly enable the interactive layer.

## Supported marks

| Mark type     | What it draws                              |
| ------------- | ------------------------------------------ |
| `bar`         | Vertical bars                              |
| `line`        | Connected line                             |
| `area`        | Filled area under a line                   |
| `point`       | Discrete symbols at each datum             |
| `rectangle`   | Rectangle between `yStart` and `yEnd`      |
| `rule`        | Horizontal or vertical reference line      |
| `sector`      | Pie / donut wedge (iOS 17+)                |

## Supported per-mark config

- **Color:** solid `color` (any RN ColorValue) or `gradient` (linear,
  multi-stop, custom start/end points).
- **Line interpolation:** `linear`, `catmullRom`, `monotone`,
  `stepStart`, `stepEnd`, `stepCenter`.
- **Line stroke:** `lineWidth`, `dashArray`, `lineCap`.
- **Symbols:** `circle`, `square`, `triangle`, `diamond`, `pentagon`,
  `plus`, `cross`, `asterisk`. With `symbolSize` and `showPoints`.
- **Bar / rectangle:** `cornerRadius`, fixed `barWidth`.
- **Sector:** `innerRadius`, `outerRadius`, `angularInset`,
  `cornerRadius`.
- **Per-point overrides:** every datum can carry its own `color` and
  `category` (series key for auto-coloring + legend grouping).
- **Opacity** per mark.

## Supported chart-level config

- `xAxis` / `yAxis`: hidden, grid lines, tick labels, label color &
  font size, custom `[domainMin, domainMax]`.
- `legend`: hidden, placement (`top`, `bottom`, `leading`, `trailing`,
  `overlay`, `automatic`).
- `centerLabel`: the in-plot value + caption pair, rendered inside
  the chart's plot frame.
- `tooltip`: interactive scrubber tooltip with native
  `chartXSelection` — vertical rule + dot + auto-clamped callout. See
  [Interactivity](#interactivity--native-tooltips--selection) above.
- `onSelect(point)`: event fired when the user picks a point via the
  scrubber or taps a pie sector. Payload is `{ x, y }` or `null`.
- `tightX`: zero out plot-dimension X padding so the line / area
  bleeds to both edges. See [Trading-chart preset](#trading-chart-preset--tightx--hidden-axes).
- `scrollableX` + `visibleXCount`: enable SwiftUI's native horizontal
  scrolling. See [Horizontal scrolling](#horizontal-scrolling-for-long-time-series).
- `categoryColors`: map `category` strings → colors. See
  [Category color palettes](#category-color-palettes--categorycolors).
- `animate`: legacy boolean toggle. Use `animation` (below) for
  richer control; `animate` stays as a shorthand for
  `{ enabled: true }`.
- `animation`: chart-level animation config — `enabled`,
  `duration`, `curve`, `entrance`, `cartesianDimOnSelect`. See
  [Animation config](#animation-config--animation).
- `annotations`: datum-anchored labels and shaded range bands
  drawn over the marks. See
  [Annotations & range bands](#annotations--range-bands).

`xAxis` / `yAxis` honor every field — `labelColor`, `labelFontSize`,
`gridColor`, `gridLines`, `tickLabels`, plus optional `[domainMin,
domainMax]` and `valueFormat` / `currencyCode` / `valueDecimals` /
`valuePrefix` / `valueSuffix` for tick label formatting. See
[Axis value formatters](#axis-value-formatters). (Fully wired from
v0.2.0 onward — v0.1.0 silently ignored everything except `hidden`.)

Bar marks additionally accept `position: "auto" | "stacked" |
"grouped"` and `horizontal: boolean` — see
[Bar charts — stacking & horizontal](#bar-charts--stacking--horizontal).

Top-level utility:

- `isChartSupported()`: runtime feature-detection helper — `true` on
  iOS 17+, `false` elsewhere. Pair with a fallback chart library on
  older iOS or non-iOS platforms. See
  [Feature-detecting at runtime](#feature-detecting-at-runtime).

## Platform support

- **iOS 17+** — full rendering. SwiftUI Charts unified API,
  `chartBackground`, `SectorMark`, `chartXSelection`,
  `chartAngleSelection`.
- **iOS 15.1–16.x** — the pod installs cleanly so this library can
  be a dependency of any modern Expo app, but `<Chart />` renders an
  empty `UIHostingController` on these versions. The SwiftUI Charts
  unified API isn't available pre-17, so there's nothing to draw.
- **Other platforms** — the components render a transparent placeholder
  `View` so consuming code doesn't need to feature-detect.

### Feature-detecting at runtime

Use `isChartSupported()` to swap in an alternative renderer
(`react-native-gifted-charts`, Victory, your own placeholder, etc.)
on iOS < 17 and on Android / web:

```tsx
import { isChartSupported, LineChart } from "rn-native-ios-charts";
import { LineChart as GiftedLine } from "react-native-gifted-charts";

export function MyChart(props) {
  return isChartSupported()
    ? <LineChart {...props} />
    : <GiftedLine {...mapToGiftedProps(props)} />;
}
```

The check is a single integer parse of `Platform.Version` — cheap
enough to call inline on every render.

## Installation

```bash
npm install rn-native-ios-charts
cd ios && pod install
```

Rebuild the native app (Metro reload alone won't pick this up — it
ships a native module).

For local / monorepo development, place the package at
`modules/rn-native-ios-charts/` and reference it via the `link:`
protocol so edits propagate without reinstalling:

```json
// package.json
{
  "dependencies": {
    "rn-native-ios-charts": "link:./modules/rn-native-ios-charts"
  }
}
```

Expo autolinking picks up the symlinked module on the next
`pod install` automatically.
