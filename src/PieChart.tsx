import * as React from "react";
import { forwardRef, type Ref } from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type { ChartHandle } from "./useChartHandle";
import { useChartHandle } from "./useChartHandle";
import type {
  AnimationConfig,
  Annotation,
  CenterLabel,
  DataPoint,
  LegendConfig,
  SelectedPoint,
  TooltipConfig,
} from "./types";

export type PieSlice = {
  label: string;
  value: number;
  color?: ColorValue;
};

/**
 * Imperative handle exposed via `ref`. Use `clearSelection()` to
 * dismiss a sticky slice selection programmatically — e.g. on tap
 * outside the chart's host view. Pair with a `<Pressable>` parent
 * that calls `chartRef.current?.clearSelection()` on press.
 *
 * Aliased to the shared `ChartHandle` so callers can swap a
 * `PieChart` for another wrapper without touching ref types.
 */
export type PieChartHandle = ChartHandle;

export type PieChartProps = {
  data: PieSlice[];
  /** Donut hole ratio, 0–1. 0 = full pie, 0.62 = thin donut. Default 0.62. */
  innerRadius?: number;
  /** Outer radius ratio, 0–1. 0 = auto. */
  outerRadius?: number;
  /** Gap between adjacent slices, pt. Default 2. */
  angularInset?: number;
  cornerRadius?: number;
  /** Center label rendered inside the donut hole. */
  centerLabel?: CenterLabel;
  legend?: LegendConfig;
  /**
   * Interactive tooltip + slice highlight.
   *
   * Tapping a slice ALWAYS (regardless of `tooltip.enabled`):
   *   - Bumps the selected slice (`sliceScale`, default 1.05), via
   *     a spring animation.
   *   - Dims unselected slices to `dimOpacity` (default 0.3).
   *   - Fires `onSelect` so callers can drive their own UI (center
   *     label, side panel, etc.).
   *   - Tapping the same slice again clears the selection.
   *   - Tapping empty area inside the chart frame (donut hole,
   *     corners, gaps) clears too.
   *
   * When `enabled: true` ADDITIONALLY:
   *   - Draws a short leader line from the slice's outer edge to a
   *     callout outside the chart, clamped to the chart's bounds.
   *
   * For tap-outside-the-chart dismiss, pass a `ref` and call
   * `ref.current?.clearSelection()` from a parent gesture handler.
   */
  tooltip?: TooltipConfig;
  /**
   * Fires when the user taps a slice. The payload `x` is the slice
   * label and `y` is its value. `null` when the selection clears
   * (tap same slice / tap miss / `clearSelection()` ref call).
   */
  onSelect?: (point: SelectedPoint) => void;
  animate?: boolean;
  animation?: AnimationConfig;
  annotations?: Annotation[];
  style?: ViewStyle;
};

// See LineChart.tsx for why we avoid `forwardRef<...>(...)` generics.
export const PieChart = forwardRef(
  function PieChart(
    {
      data,
      innerRadius = 0.62,
      outerRadius,
      angularInset = 2,
      cornerRadius = 2,
      centerLabel,
      legend,
      tooltip,
      onSelect,
      animate,
      animation,
      annotations,
      style,
    }: PieChartProps,
    ref: Ref<PieChartHandle>
  ) {
    const clearToken = useChartHandle(ref);

    const points: DataPoint[] = data.map((s) => ({
      x: s.label,
      y: s.value,
      color: s.color,
      category: s.label,
    }));
    return (
      <Chart
        style={style}
        animate={animate}
        animation={animation}
        legend={legend ?? { hidden: true }}
        centerLabel={centerLabel}
        tooltip={tooltip}
        onSelect={onSelect}
        annotations={annotations}
        clearSelectionToken={clearToken}
        marks={[
          {
            type: "sector",
            data: points,
            innerRadius,
            outerRadius,
            angularInset,
            cornerRadius,
          },
        ]}
      />
    );
  }
);
