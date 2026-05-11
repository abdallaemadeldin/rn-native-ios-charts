import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type {
  AxisConfig,
  DataPoint,
  LegendConfig,
  SelectedPoint,
  Symbol,
  TooltipConfig,
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
  tooltip?: TooltipConfig;
  onSelect?: (point: SelectedPoint) => void;
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
  tooltip,
  onSelect,
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
      tooltip={tooltip}
      onSelect={onSelect}
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
