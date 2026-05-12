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
  Symbol,
  TooltipConfig,
} from "./types";

export type ScatterDatum = {
  x: string | Date;
  y: number;
  category?: string;
  color?: ColorValue;
};

export type ScatterChartProps = {
  data: ScatterDatum[];
  color?: ColorValue;
  symbol?: Symbol;
  symbolSize?: number;
  xAxis?: AxisConfig;
  yAxis?: AxisConfig;
  legend?: LegendConfig;
  tooltip?: TooltipConfig;
  onSelect?: (point: SelectedPoint) => void;
  animate?: boolean;
  animation?: AnimationConfig;
  /** Category → color palette. See `categoryColors` on `<Chart>`. */
  categoryColors?: Record<string, ColorValue>;
  annotations?: Annotation[];
  style?: ViewStyle;
};

// See LineChart.tsx for why we avoid `forwardRef<...>(...)` generics.
export const ScatterChart = forwardRef(
  function ScatterChart(
    {
      data,
      color,
      symbol = "circle",
      symbolSize = 36,
      xAxis,
      yAxis,
      legend,
      tooltip,
      onSelect,
      animate,
      animation,
      categoryColors,
      annotations,
      style,
    }: ScatterChartProps,
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
            type: "point",
            data: points,
            color,
            symbol,
            symbolSize,
          },
        ]}
      />
    );
  }
);
