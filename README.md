# rn-native-ios-charts

> Native SwiftUI Charts for React Native / Expo. **iOS-only.** No SVG, no
> Skia, no canvas approximations — every line and slice is drawn by Apple's
> own `Charts` framework.

<p align="center">
  <img src="https://raw.githubusercontent.com/abdallaemadeldin/rn-native-ios-charts/HEAD/docs/demo.gif" alt="rn-native-ios-charts demo" width="360" />
</p>

> [▶ Watch HD version](https://github.com/abdallaemadeldin/rn-native-ios-charts/raw/HEAD/docs/demo.mp4) — every chart type, native gradients, interactive tooltips, and pie center-label snapping.

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

For pie / donut charts there's no visual callout — `onSelect` fires
on slice taps via `chartAngleSelection`, and the natural place to
display the info is the `centerLabel`:

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
- `animate`: toggle SwiftUI's native ease-in-out on data changes.

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
