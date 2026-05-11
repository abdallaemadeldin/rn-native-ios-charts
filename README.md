# rn-native-ios-charts

> Native SwiftUI Charts for React Native / Expo. **iOS-only.** No SVG, no
> Skia, no canvas approximations — every line and slice is drawn by Apple's
> own `Charts` framework.

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
onSelect?: (point: { x: string; y: number } | null) => void;
```

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
- `animate`: toggle SwiftUI's native ease-in-out on data changes.

## Platform support

- **iOS 17+** — full rendering. SwiftUI Charts unified API,
  `chartBackground`, `SectorMark`, `chartXSelection`,
  `chartAngleSelection`.
- **iOS 15.1–16.x** — the pod installs cleanly so this library can
  be a dependency of any modern Expo app, but `<Chart />` renders an
  empty `UIHostingController` on these versions. The SwiftUI Charts
  unified API isn't available pre-17, so there's nothing to draw.
- **Other platforms** — the components render a transparent placeholder
  `View` so consuming code doesn't need to feature-detect. Use
  `Platform.OS === "ios"` to mount alternative renderers (e.g.
  `react-native-gifted-charts`) on Android.

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
