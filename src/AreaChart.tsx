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
  Gradient,
  Interpolation,
  LegendConfig,
  SelectedPoint,
  TooltipConfig,
} from "./types";

export type AreaDatum = {
  /** Categorical string or a `Date` for time-series. */
  x: string | Date;
  y: number;
  category?: string;
};

export type AreaChartProps = {
  data: AreaDatum[];
  color?: ColorValue;
  gradient?: Gradient;
  interpolation?: Interpolation;
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  tooltip?: TooltipConfig;
  onSelect?: (point: SelectedPoint) => void;
  animate?: boolean;
  animation?: AnimationConfig;
  annotations?: Annotation[];
  style?: ViewStyle;
};

// See LineChart.tsx for why we avoid `forwardRef<...>(...)` generics
// — Babel's TSX parser treats the `<` as a JSX tag.
export const AreaChart = forwardRef(
  function AreaChart(
    {
      data,
      color,
      gradient = { startOpacity: 0.35, endOpacity: 0.02 },
      interpolation = "catmullRom",
      xAxis,
      yAxis,
      legend,
      tooltip,
      onSelect,
      animate,
      animation,
      annotations,
      style,
    }: AreaChartProps,
    ref: Ref<ChartHandle>
  ) {
    const clearToken = useChartHandle(ref);
    const points: DataPoint[] = data.map((p) => ({
      x: p.x,
      y: p.y,
      category: p.category,
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
        annotations={annotations}
        clearSelectionToken={clearToken}
        marks={[
          {
            type: "area",
            data: points,
            color,
            gradient,
            interpolation,
          },
        ]}
      />
    );
  }
);
