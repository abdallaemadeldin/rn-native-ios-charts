/**
 * DemoScreen — every chart, every feature, in one scrollable view.
 *
 * Drop this file into any Expo app, import the component, and render
 * it as a route. Requires `react-native-reanimated` because the
 * scroll-aware section uses it; the rest of the charts work without
 * Reanimated.
 *
 * Used as:
 *   - Visual regression sweep for new releases (tap every slice,
 *     swipe every tooltip, switch every tab).
 *   - Marketing material for the README's screenshots.
 *   - A working starting point for downstream apps — feel free to
 *     copy/paste sections.
 *
 * Self-contained: no external deps beyond `react`, `react-native`,
 * `react-native-reanimated`, and `rn-native-ios-charts`. No theme
 * libraries, no style systems — bare RN styling, easy to read.
 */
import * as React from "react";
import { useCallback, useMemo, useRef, useState } from "react";
import {
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  type ColorValue,
  type ViewStyle,
} from "react-native";
import Animated, {
  useAnimatedScrollHandler,
  useSharedValue,
} from "react-native-reanimated";
import {
  AreaChart,
  BarChart,
  Chart,
  LineChart,
  PieChart,
  RangeBarChart,
  ScatterChart,
  ScrollAwareChart,
  isChartSupported,
  type ChartHandle,
  type SelectedPoint,
} from "rn-native-ios-charts";

// ─── Color palette (dark theme) ───
const C = {
  bg: "#0E0E10",
  surface: "#161618",
  surfaceHigh: "#1F1F23",
  border: "#2A2A2D",
  text: "#FFFFFF",
  subtext: "#9BA1A6",
  green: "#1FA92E",
  blue: "#3B82F6",
  amber: "#F59E0B",
  purple: "#8B5CF6",
  red: "#EF4444",
  pink: "#EC4899",
};

// ─── Sample data ───

// Multi-asset portfolio for pies + bars.
const portfolio = [
  { label: "Cash", value: 24, color: C.green },
  { label: "Stocks", value: 58, color: C.blue },
  { label: "Bonds", value: 18, color: C.amber },
  { label: "Real Estate", value: 32, color: C.purple },
  { label: "Crypto", value: 14, color: C.red },
];

// Alternate split for tab-switch redraw testing — same labels, different values.
const portfolioAlt = [
  { label: "Cash", value: 12, color: C.green },
  { label: "Stocks", value: 78, color: C.blue },
  { label: "Bonds", value: 8, color: C.amber },
  { label: "Real Estate", value: 24, color: C.purple },
  { label: "Crypto", value: 22, color: C.red },
];

// Yet another split — different label set, different counts (stress-test).
const portfolioByGeo = [
  { label: "US", value: 60, color: C.blue },
  { label: "EU", value: 22, color: C.green },
  { label: "Asia", value: 14, color: C.amber },
  { label: "Other", value: 4, color: C.purple },
];

// Monthly revenue (categorical x).
const monthly = [
  { x: "Jan", y: 12000 },
  { x: "Feb", y: 15800 },
  { x: "Mar", y: 14200 },
  { x: "Apr", y: 19600 },
  { x: "May", y: 22100 },
  { x: "Jun", y: 26400 },
  { x: "Jul", y: 24800 },
  { x: "Aug", y: 28900 },
  { x: "Sep", y: 32400 },
  { x: "Oct", y: 35100 },
  { x: "Nov", y: 38600 },
  { x: "Dec", y: 42000 },
];

// Date-axis daily price (24 points across two years).
const daily: { x: Date; y: number }[] = (() => {
  const out: { x: Date; y: number }[] = [];
  const base = new Date(2025, 0, 1).getTime();
  let v = 100;
  for (let i = 0; i < 24; i++) {
    const t = base + i * 30 * 86400 * 1000;
    v = v * (1 + (Math.sin(i * 0.7) * 0.08 + (i % 4 === 0 ? 0.05 : -0.02)));
    out.push({ x: new Date(t), y: Math.round(v * 100) / 100 });
  }
  return out;
})();

// Log-scale-friendly long-horizon growth.
const decadalGrowth = [
  { x: "2000", y: 1000 },
  { x: "2005", y: 3200 },
  { x: "2010", y: 9800 },
  { x: "2015", y: 38000 },
  { x: "2020", y: 142000 },
  { x: "2025", y: 520000 },
];

// Multi-series for legend + multi-tooltip.
const multiSeries = [
  {
    name: "Revenue",
    color: C.green,
    data: monthly,
    area: { startOpacity: 0.4, endOpacity: 0 } as const,
  },
  {
    name: "Expenses",
    color: C.amber,
    data: monthly.map((p) => ({ x: p.x, y: p.y * 0.62 + 4000 })),
    dashArray: [6, 4],
  },
  {
    name: "Forecast",
    color: C.blue,
    data: monthly.map((p) => ({ x: p.x, y: p.y * 0.85 + 2000 })),
    showPoints: true,
    symbol: "diamond" as const,
  },
];

// Grouped bars by category.
const quarterly = [
  { x: "Q1", y: 24, category: "Revenue" },
  { x: "Q1", y: 18, category: "Expenses" },
  { x: "Q2", y: 31, category: "Revenue" },
  { x: "Q2", y: 22, category: "Expenses" },
  { x: "Q3", y: 38, category: "Revenue" },
  { x: "Q3", y: 26, category: "Expenses" },
  { x: "Q4", y: 42, category: "Revenue" },
  { x: "Q4", y: 28, category: "Expenses" },
];

// Top-N horizontal bars.
const topAssets = [
  { x: "AAPL", y: 38500 },
  { x: "MSFT", y: 32100 },
  { x: "NVDA", y: 28700 },
  { x: "GOOGL", y: 21900 },
  { x: "AMZN", y: 18400 },
];

// Scatter — risk vs return scatter.
const scatter = Array.from({ length: 18 }, (_, i) => ({
  x: `A${i}`,
  y: 5 + Math.sin(i * 0.9) * 8 + (i % 3) * 2,
  category: i % 3 === 0 ? "High" : i % 3 === 1 ? "Med" : "Low",
}));

// OHLC-style range bars.
const ohlc = Array.from({ length: 10 }, (_, i) => ({
  x: `D${i + 1}`,
  yStart: 90 + Math.sin(i * 0.8) * 6,
  yEnd: 100 + Math.sin(i * 0.8 + 0.4) * 8,
}));

// ─── Sub-components ───

function Section({
  title,
  description,
  children,
  style,
}: {
  title: string;
  description?: string;
  children: React.ReactNode;
  style?: ViewStyle;
}) {
  return (
    <View style={[styles.section, style]}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {description ? (
        <Text style={styles.sectionDescription}>{description}</Text>
      ) : null}
      <View style={styles.sectionBody}>{children}</View>
    </View>
  );
}

function Pill({
  label,
  active,
  onPress,
  color = C.blue,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
  color?: ColorValue;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.pill,
        active && { backgroundColor: color, borderColor: color },
      ]}
    >
      <Text
        style={[
          styles.pillText,
          active && { color: C.bg, fontWeight: "700" },
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}

// ─── Individual chart demos ───

function PieDemoSection() {
  // Three tabs swap data sets so we can stress-test the redraw bug
  // path: same labels / different values, AND different label sets.
  const tabs = ["By Asset", "Alt Split", "By Geo"] as const;
  const datasets = [portfolio, portfolioAlt, portfolioByGeo];
  const [tab, setTab] = useState(0);
  const data = datasets[tab];

  const total = data.reduce((s, x) => s + x.value, 0);
  const [selected, setSelected] = useState<SelectedPoint>(null);
  const centerValue = selected ? `${selected.y}%` : `${total}%`;
  const centerLabel = selected ? selected.x : "Total";

  // The ref drives `clearSelection()` — wired to a parent Pressable
  // for tap-outside dismiss.
  const chartRef = useRef<ChartHandle>(null);

  return (
    <Section
      title="PieChart — tooltip, highlight, dismiss, redraw"
      description="Tap a slice to highlight + show the tooltip. Tap the donut hole or empty area to dismiss. Tap the same slice to toggle. Switch tabs to verify the redraw across different data shapes."
    >
      <View style={styles.row}>
        {tabs.map((t, i) => (
          <Pill
            key={t}
            label={t}
            active={tab === i}
            onPress={() => {
              setTab(i);
              setSelected(null);
              chartRef.current?.clearSelection();
            }}
          />
        ))}
      </View>
      <View style={styles.pieFrame}>
        <PieChart
          ref={chartRef}
          style={{ width: 240, height: 240 }}
          data={data}
          innerRadius={0.62}
          angularInset={2}
          cornerRadius={6}
          centerLabel={{
            value: centerValue,
            label: centerLabel,
            valueColor: C.text,
            labelColor: C.subtext,
            valueFontSize: 22,
            labelFontSize: 11,
          }}
          tooltip={{
            enabled: true,
            valueSuffix: "%",
            valueDecimals: 0,
            backgroundColor: C.surfaceHigh,
            textColor: C.text,
            borderColor: C.border,
            dimOpacity: 0.3,
            sliceScale: 1.06,
          }}
          animation={{
            enabled: true,
            duration: 450,
            curve: "easeInOut",
            entrance: true,
          }}
          onSelect={(p) => {
            // Trace log: confirms whether the native chart is
            // emitting selection events at all. If you tap a slice
            // and don't see this log, the chart isn't capturing
            // taps — likely a parent gesture handler (Pressable
            // wrapping, ScrollView, etc.) stealing them, or a
            // native rebuild that hasn't happened yet.
            console.log("[PieDemo] onSelect:", JSON.stringify(p));
            setSelected(p);
          }}
        />
      </View>
      <Pressable
        onPress={() => {
          console.log("[PieDemo] clear button pressed");
          chartRef.current?.clearSelection();
          setSelected(null);
        }}
        style={styles.clearButton}
      >
        <Text style={styles.clearButtonText}>Clear selection</Text>
      </Pressable>
      <Text style={styles.caption}>
        Tap a slice to highlight + show the tooltip. Tap the same
        slice to dismiss (toggle), or use the Clear button for the
        imperative `ref.current?.clearSelection()` path. Deliberately
        not wrapping the chart in a Pressable — RN's responder chain
        would hijack slice taps before SwiftUI's `chartAngleSelection`
        sees them.
      </Text>
    </Section>
  );
}

function PieTooltipDemoSection() {
  // Pie tooltip in isolation — no center label, no tab switcher.
  // The leader line + callout + slice scale + dim-others animation
  // should be the only thing your eye lands on. Tap a slice; tap
  // the same slice (or empty area) to dismiss. The ref is wired so
  // taps on the surrounding Pressable also clear the selection.
  const chartRef = useRef<ChartHandle>(null);
  return (
    <Section
      title="PieChart — tooltip with leader line, no center label"
      description="The pure tooltip experience: tap a slice, get a leader line + callout anchored at the slice midpoint, with the selected slice bumping outward and the others dimming to 0.3. No donut hole readout to distract."
    >
      <View style={styles.pieFrame}>
        <PieChart
          ref={chartRef}
          style={{ width: 260, height: 260 }}
          data={portfolio}
          // Smaller inner radius — closer to a full pie, less donut.
          innerRadius={0}
          angularInset={2}
          cornerRadius={4}
          tooltip={{
            enabled: true,
            // Show the title (the slice label) above the value.
            showTitle: true,
            valuePrefix: "$",
            valueSuffix: "k",
            valueDecimals: 0,
            backgroundColor: C.surfaceHigh,
            textColor: C.text,
            borderColor: C.border,
            // The two pie-specific knobs.
            dimOpacity: 0.25,
            sliceScale: 1.07,
          }}
          animation={{
            enabled: true,
            duration: 400,
            curve: "easeInOut",
            entrance: true,
          }}
          onSelect={(p) => {
            console.log(
              "[PieTooltipDemo] onSelect:",
              JSON.stringify(p)
            );
          }}
        />
      </View>
      <Pressable
        onPress={() => {
          console.log("[PieTooltipDemo] clear button pressed");
          chartRef.current?.clearSelection();
        }}
        style={styles.clearButton}
      >
        <Text style={styles.clearButtonText}>Clear selection</Text>
      </Pressable>
      <Text style={styles.caption}>
        Tap a slice to highlight + see the leader-line callout. Tap
        the same slice again or use the Clear button above to
        dismiss. Watch the Metro console for `[PieTooltipDemo]` logs
        — if `onSelect` fires on tap, the native chart is capturing
        the gesture and the tooltip render path is the suspect.
      </Text>
    </Section>
  );
}

function LineDemoSection() {
  return (
    <Section
      title="LineChart — single series with area + tooltip"
      description="Catmull-Rom interpolation, gradient area fill, currency Y-axis, scrubber tooltip."
    >
      <LineChart
        style={{ height: 220 }}
        data={monthly}
        color={C.green}
        lineWidth={3}
        interpolation="catmullRom"
        area={{ startOpacity: 0.4, endOpacity: 0 }}
        showPoints
        symbol="circle"
        symbolSize={28}
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valueFormat: "abbreviated",
          valuePrefix: "$",
        }}
        tooltip={{
          enabled: true,
          valuePrefix: "$",
          valueDecimals: 0,
          backgroundColor: C.surfaceHigh,
          textColor: C.text,
          borderColor: C.border,
        }}
        animation={{ enabled: true, duration: 400, curve: "easeOut", entrance: true }}
      />
    </Section>
  );
}

function TightXDemoSection() {
  return (
    <Section
      title="LineChart — tightX trading-chart preset"
      description="Edge-to-edge line, no axes, deep gradient. Robinhood / Apple Stocks aesthetic."
    >
      <LineChart
        style={{ height: 200 }}
        data={monthly}
        color={C.green}
        lineWidth={3}
        interpolation="catmullRom"
        area={{ startOpacity: 0.55, endOpacity: 0 }}
        tightX
        xAxis={{ hidden: true }}
        yAxis={{ hidden: true }}
        tooltip={{
          enabled: true,
          valuePrefix: "$",
          backgroundColor: C.surfaceHigh,
          textColor: C.text,
          borderColor: C.border,
        }}
      />
    </Section>
  );
}

function MultiLineDemoSection() {
  return (
    <Section
      title="LineChart — multi-series + multi-row tooltip + dim-on-select"
      description="Three series with different styling. The scrubber dims the non-active series via `animation.cartesianDimOnSelect`."
    >
      <LineChart
        style={{ height: 240 }}
        series={multiSeries}
        lineWidth={2.5}
        interpolation="catmullRom"
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valueFormat: "abbreviated",
          valuePrefix: "$",
        }}
        legend={{ placement: "bottom" }}
        tooltip={{
          enabled: true,
          multiSeries: true,
          valuePrefix: "$",
          valueDecimals: 0,
          backgroundColor: C.surfaceHigh,
          textColor: C.text,
          borderColor: C.border,
        }}
        animation={{
          enabled: true,
          curve: "easeInOut",
          cartesianDimOnSelect: true,
        }}
      />
    </Section>
  );
}

function DateAxisDemoSection() {
  return (
    <Section
      title="LineChart — Date axis with annotations"
      description="`x` accepts `Date`. Tick labels format via `xAxis.dateFormat`. Two annotations overlayed — one datum-anchored, one range band."
    >
      <LineChart
        style={{ height: 240 }}
        data={daily}
        color={C.blue}
        lineWidth={2.5}
        interpolation="catmullRom"
        area={{ startOpacity: 0.3, endOpacity: 0 }}
        xAxis={{
          labelColor: C.subtext,
          gridLines: false,
          valueFormat: "date",
          dateFormat: "MMM yy",
          labelFontSize: 10,
        }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valueFormat: "currency",
          currencyCode: "USD",
          valueDecimals: 0,
        }}
        tooltip={{
          enabled: true,
          valuePrefix: "$",
          valueDecimals: 2,
          backgroundColor: C.surfaceHigh,
          textColor: C.text,
          borderColor: C.border,
        }}
        annotations={[
          {
            x: daily[6].x,
            text: "Earnings",
            color: C.green,
            position: "top",
            fontSize: 10,
          },
          {
            xRange: [daily[14].x, daily[18].x],
            text: "Q4 hold",
            color: C.purple,
            position: "inside",
            fontSize: 11,
          },
        ]}
        animation={{ enabled: true, duration: 500, curve: "easeOut" }}
      />
    </Section>
  );
}

function LogScaleDemoSection() {
  return (
    <Section
      title="LineChart — log Y scale for long-horizon growth"
      description={'`yAxis.scaleType: "log"` keeps the early years visible when later years dwarf them.'}
    >
      <LineChart
        style={{ height: 220 }}
        data={decadalGrowth}
        color={C.amber}
        lineWidth={3}
        showPoints
        symbol="circle"
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          scaleType: "log",
          domainMin: 100,
          valueFormat: "abbreviated",
          valuePrefix: "$",
        }}
        animation={{ enabled: true, duration: 600, curve: "easeOut" }}
      />
    </Section>
  );
}

function AreaDemoSection() {
  return (
    <Section
      title="AreaChart — gradient fill"
      description="Native `LinearGradient` on `AreaMark.foregroundStyle` — no SVG, no Skia approximation."
    >
      <AreaChart
        style={{ height: 200 }}
        data={monthly}
        color={C.purple}
        gradient={{ startOpacity: 0.55, endOpacity: 0.02 }}
        interpolation="catmullRom"
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valueFormat: "abbreviated",
          valuePrefix: "$",
        }}
        tooltip={{
          enabled: true,
          valuePrefix: "$",
          backgroundColor: C.surfaceHigh,
          textColor: C.text,
          borderColor: C.border,
        }}
      />
    </Section>
  );
}

function BarDemoSection() {
  // Tooltip config reused across all three bar variants. Long-press
  // a bar (or any vertical column for stacked/grouped) to start
  // the scrubber, then drag.
  const barTooltip = {
    enabled: true,
    multiSeries: true,
    valuePrefix: "$",
    valueSuffix: "k",
    valueDecimals: 0,
    backgroundColor: C.surfaceHigh,
    textColor: C.text,
    borderColor: C.border,
  } as const;

  return (
    <Section
      title="BarChart — grouped, stacked, horizontal"
      description="Three modes: grouped multi-series (side-by-side), stacked, and horizontal for Top-N. All three support the long-press scrubber tooltip; grouped/stacked use the multi-series row callout."
    >
      <Text style={styles.caption}>Grouped — position: "grouped"</Text>
      <BarChart
        style={{ height: 180 }}
        data={quarterly}
        position="grouped"
        cornerRadius={6}
        categoryColors={{ Revenue: C.green, Expenses: C.amber }}
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valuePrefix: "$",
          valueSuffix: "k",
        }}
        legend={{ placement: "bottom" }}
        tooltip={barTooltip}
      />

      <Text style={[styles.caption, { marginTop: 16 }]}>
        Stacked — same data, position: "stacked"
      </Text>
      <BarChart
        style={{ height: 180 }}
        data={quarterly}
        position="stacked"
        cornerRadius={4}
        categoryColors={{ Revenue: C.green, Expenses: C.amber }}
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valuePrefix: "$",
          valueSuffix: "k",
        }}
        legend={{ placement: "bottom" }}
        tooltip={barTooltip}
      />

      <Text style={[styles.caption, { marginTop: 16 }]}>
        Horizontal Top-N — `horizontal: true`
      </Text>
      <BarChart
        style={{ height: 200 }}
        data={topAssets}
        color={C.blue}
        horizontal
        cornerRadius={4}
        xAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valueFormat: "abbreviated",
          valuePrefix: "$",
        }}
        yAxis={{ labelColor: C.subtext, gridLines: false }}
        // Single-series, no multi-row needed — the default
        // single-row callout shows ticker + value. TooltipConfig
        // doesn't support `valueFormat: "abbreviated"` (only the
        // axis does), so we render the raw thousands-separated
        // value with a prefix.
        tooltip={{
          enabled: true,
          valuePrefix: "$",
          valueDecimals: 0,
          backgroundColor: C.surfaceHigh,
          textColor: C.text,
          borderColor: C.border,
        }}
      />
    </Section>
  );
}

function ScatterDemoSection() {
  return (
    <Section
      title="ScatterChart — symbols + categories"
      description="Per-category colors via `categoryColors`."
    >
      <ScatterChart
        style={{ height: 220 }}
        data={scatter}
        symbol="circle"
        symbolSize={64}
        categoryColors={{ High: C.red, Med: C.amber, Low: C.green }}
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{ labelColor: C.subtext, gridColor: C.border }}
        legend={{ placement: "bottom" }}
        tooltip={{
          enabled: true,
          backgroundColor: C.surfaceHigh,
          textColor: C.text,
          borderColor: C.border,
        }}
      />
    </Section>
  );
}

function RangeBarDemoSection() {
  return (
    <Section
      title="RangeBarChart — OHLC-style ranges"
      description="`yStart` / `yEnd` per datum. Useful for candlesticks, Gantt-ish timelines, low/high bands."
    >
      <RangeBarChart
        style={{ height: 200 }}
        data={ohlc}
        color={C.green}
        cornerRadius={3}
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{ labelColor: C.subtext, gridColor: C.border }}
      />
    </Section>
  );
}

function MixedMarksDemoSection() {
  // Generic <Chart> with a mix of marks to demonstrate the
  // composable primitive.
  return (
    <Section
      title="<Chart> — mixed marks (area + line + reference rule)"
      description="The generic primitive every wrapper delegates to. Mix any combination of marks in one chart."
    >
      <Chart
        style={{ height: 220 }}
        marks={[
          {
            type: "area",
            data: monthly,
            color: C.blue,
            gradient: { startOpacity: 0.3, endOpacity: 0 },
            interpolation: "catmullRom",
          },
          {
            type: "line",
            data: monthly,
            color: C.blue,
            lineWidth: 2.5,
            interpolation: "catmullRom",
            showPoints: true,
            symbol: "circle",
            symbolSize: 32,
          },
          {
            type: "rule",
            data: [],
            ruleValue: 25000,
            color: C.amber,
            dashArray: [4, 4],
            lineWidth: 1.5,
          },
        ]}
        xAxis={{ labelColor: C.subtext, gridLines: false }}
        yAxis={{
          labelColor: C.subtext,
          gridColor: C.border,
          valueFormat: "abbreviated",
          valuePrefix: "$",
        }}
        annotations={[
          {
            x: "Jun",
            text: "Target",
            color: C.amber,
            position: "top",
            fontSize: 10,
          },
        ]}
      />
    </Section>
  );
}

function ScrollAwareDemoSection({
  scrollY,
}: {
  scrollY: ReturnType<typeof useSharedValue<number>>;
}) {
  return (
    <Section
      title="ScrollAwareChart — scroll-driven scale"
      description="Wrap any chart in <ScrollAwareChart scrollY={...} /> to scale + fade as it leaves the viewport center. Worklet-driven, no JS bridge crossings."
    >
      <ScrollAwareChart
        scrollY={scrollY}
        minScale={0.88}
        maxScale={1.0}
        fadeOut
        range={260}
      >
        <AreaChart
          style={{ height: 200 }}
          data={monthly}
          color={C.pink}
          gradient={{ startOpacity: 0.5, endOpacity: 0 }}
          interpolation="catmullRom"
          xAxis={{ labelColor: C.subtext, gridLines: false }}
          yAxis={{
            labelColor: C.subtext,
            gridColor: C.border,
            valueFormat: "abbreviated",
            valuePrefix: "$",
          }}
        />
      </ScrollAwareChart>
      <Text style={styles.caption}>
        Scroll the page up/down — this card scales down + fades as it
        approaches the screen edges and returns to full at center.
      </Text>
    </Section>
  );
}

// ─── Main demo ───

export function DemoScreen() {
  if (!isChartSupported()) {
    return (
      <SafeAreaView style={[styles.container, styles.fallbackContainer]}>
        <Text style={styles.fallbackTitle}>iOS 17+ required</Text>
        <Text style={styles.fallbackText}>
          `rn-native-ios-charts` uses SwiftUI Charts' unified API,
          which is iOS-17-only. On iOS 15.1–16.x and on non-iOS
          platforms, charts render a transparent placeholder. Use
          `isChartSupported()` to swap in a fallback renderer like
          `react-native-gifted-charts`.
        </Text>
      </SafeAreaView>
    );
  }

  const scrollY = useSharedValue(0);
  const onScroll = useAnimatedScrollHandler({
    onScroll: (e) => {
      scrollY.value = e.contentOffset.y;
    },
  });

  return (
    <SafeAreaView style={styles.container}>
      <Animated.ScrollView
        onScroll={onScroll}
        scrollEventThrottle={16}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <Text style={styles.headerTitle}>rn-native-ios-charts</Text>
          <Text style={styles.headerSubtitle}>
            Every chart, every feature. Tap, drag, switch tabs — this
            is the visual regression sweep.
          </Text>
        </View>

        <PieDemoSection />
        <PieTooltipDemoSection />
        <LineDemoSection />
        <TightXDemoSection />
        <MultiLineDemoSection />
        <DateAxisDemoSection />
        <LogScaleDemoSection />
        <AreaDemoSection />
        <BarDemoSection />
        <ScatterDemoSection />
        <RangeBarDemoSection />
        <MixedMarksDemoSection />
        <ScrollAwareDemoSection scrollY={scrollY} />

        <View style={{ height: 40 }} />
      </Animated.ScrollView>
    </SafeAreaView>
  );
}

// ─── Styles ───

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: C.bg,
  },
  fallbackContainer: {
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
  },
  fallbackTitle: {
    color: C.text,
    fontSize: 22,
    fontWeight: "700",
    marginBottom: 12,
    textAlign: "center",
  },
  fallbackText: {
    color: C.subtext,
    fontSize: 14,
    textAlign: "center",
    maxWidth: 360,
    lineHeight: 22,
  },
  scrollContent: {
    paddingHorizontal: 16,
    paddingBottom: 32,
  },
  header: {
    paddingVertical: 24,
    paddingHorizontal: 4,
  },
  headerTitle: {
    color: C.text,
    fontSize: 28,
    fontWeight: "800",
    letterSpacing: -0.6,
  },
  headerSubtitle: {
    color: C.subtext,
    fontSize: 14,
    marginTop: 6,
    lineHeight: 20,
  },
  section: {
    marginBottom: 20,
    backgroundColor: C.surface,
    borderRadius: 16,
    padding: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: C.border,
  },
  sectionTitle: {
    color: C.text,
    fontSize: 16,
    fontWeight: "700",
    letterSpacing: -0.3,
  },
  sectionDescription: {
    color: C.subtext,
    fontSize: 12,
    marginTop: 4,
    lineHeight: 18,
  },
  sectionBody: {
    marginTop: 14,
  },
  row: {
    flexDirection: "row",
    gap: 6,
    flexWrap: "wrap",
    marginBottom: 12,
  },
  pill: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: C.border,
    backgroundColor: C.surfaceHigh,
  },
  pillText: {
    color: C.subtext,
    fontSize: 12,
    fontWeight: "600",
  },
  pieFrame: {
    alignItems: "center",
    paddingVertical: 8,
  },
  clearButton: {
    alignSelf: "center",
    marginTop: 10,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: C.border,
    backgroundColor: C.surfaceHigh,
  },
  clearButtonText: {
    color: C.text,
    fontSize: 12,
    fontWeight: "600",
  },
  caption: {
    color: C.subtext,
    fontSize: 11,
    marginTop: 8,
    lineHeight: 16,
    fontStyle: "italic",
  },
});

export default DemoScreen;
