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

export type RangeDatum = {
  x: string | Date;
  yStart: number;
  yEnd: number;
  category?: string;
  color?: ColorValue;
};

export type RangeBarChartProps = {
  data: RangeDatum[];
  color?: ColorValue;
  cornerRadius?: number;
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

/**
 * Range bars — drawn as `RectangleMark` between `yStart` and `yEnd`.
 * Use for candlestick / OHLC visualisations, Gantt-style timelines,
 * or low/high bands.
 */
// See LineChart.tsx for why we avoid `forwardRef<...>(...)` generics.
export const RangeBarChart = forwardRef(
  function RangeBarChart(
    {
      data,
      color,
      cornerRadius = 2,
      xAxis,
      yAxis,
      legend,
      tooltip,
      onSelect,
      animate,
      animation,
      annotations,
      style,
    }: RangeBarChartProps,
    ref: Ref<ChartHandle>
  ) {
    const clearToken = useChartHandle(ref);
    const points: DataPoint[] = data.map((d) => ({
      x: d.x,
      y: d.yStart,
      yEnd: d.yEnd,
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
        annotations={annotations}
        clearSelectionToken={clearToken}
        marks={[
          {
            type: "rectangle",
            data: points,
            color,
            cornerRadius,
          },
        ]}
      />
    );
  }
);
