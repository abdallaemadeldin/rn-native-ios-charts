import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type {
  AxisConfig,
  DataPoint,
  LegendConfig,
  Symbol,
} from "./types";

export type ScatterDatum = {
  x: string;
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
  animate?: boolean;
  style?: ViewStyle;
};

export function ScatterChart({
  data,
  color,
  symbol = "circle",
  symbolSize = 36,
  xAxis,
  yAxis,
  legend,
  animate,
  style,
}: ScatterChartProps) {
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
      xAxis={xAxis}
      yAxis={yAxis}
      legend={legend}
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
