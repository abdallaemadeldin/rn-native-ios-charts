import * as React from "react";
import { forwardRef, type Ref } from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type { ChartHandle } from "./useChartHandle";
import { useChartHandle } from "./useChartHandle";
import type {
  AnimationConfig,
  Annotation,
  AxisConfig,
  DataPoint,
  LegendConfig,
  SelectedPoint,
  TooltipConfig,
} from "./types";

export type BarDatum = {
  /** Categorical string or a `Date` for time-binned bars. */
  x: string | Date;
  y: number;
  /** Optional series key for grouped / colored bars. */
  category?: string;
  color?: ColorValue;
};

export type BarChartProps = {
  data: BarDatum[];
  color?: ColorValue;
  cornerRadius?: number;
  /** Fixed width per bar in pt. 0 = auto. */
  barWidth?: number;
  /**
   * Multi-series positioning. "stacked" stacks bars at the same X;
   * "grouped" places them side-by-side via the per-point `category`
   * field. Default "auto".
   */
  position?: "auto" | "stacked" | "grouped";
  /** Render bars horizontally (swap X/Y). Default false. */
  horizontal?: boolean;
  /**
   * Maps `category` → color, shorthand for `chartForegroundStyleScale`.
   * When set, per-point `color` is unnecessary.
   */
  categoryColors?: Record<string, ColorValue>;
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  tooltip?: TooltipConfig;
  onSelect?: (point: SelectedPoint) => void;
  /** Legacy boolean shorthand for `animation: { enabled: true }`. */
  animate?: boolean;
  /** Full animation config — curve, duration, entrance, dim-on-select. */
  animation?: AnimationConfig;
  /** Datum-anchored labels + range bands. See `Annotation`. */
  annotations?: Annotation[];
  style?: ViewStyle;
};

// NOTE: don't put generics on the `forwardRef<…, …>(…)` call here.
// Babel's TSX parser conflates the leading `<` with a JSX tag and
// bails before reaching the body. Typing the inner function's
// parameters explicitly gives TypeScript the same inference
// without the parse hazard.
export const BarChart = forwardRef(
  function BarChart(
    {
      data,
      color,
      cornerRadius = 4,
      barWidth,
      position,
      horizontal,
      categoryColors,
      xAxis,
      yAxis,
      legend,
      tooltip,
      onSelect,
      animate,
      animation,
      annotations,
      style,
    }: BarChartProps,
    ref: Ref<ChartHandle>
  ) {
    const clearToken = useChartHandle(ref);
    const points: DataPoint[] = data.map((d) => ({
      x: d.x,
      y: d.y,
      category: d.category,
      color: d.color,
    }));
    return (
      <Chart
        style={style}
        animate={animate}
        animation={animation}
        xAxis={xAxis}
        yAxis={yAxis}
        legend={legend}
        tooltip={tooltip}
        onSelect={onSelect}
        categoryColors={categoryColors}
        annotations={annotations}
        clearSelectionToken={clearToken}
        marks={[
          {
            type: "bar",
            data: points,
            color,
            cornerRadius,
            barWidth,
            position,
            horizontal,
          },
        ]}
      />
    );
  }
);
