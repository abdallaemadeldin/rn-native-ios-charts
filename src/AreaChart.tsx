import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type {
  AxisConfig,
  DataPoint,
  Gradient,
  Interpolation,
  LegendConfig,
  SelectedPoint,
  TooltipConfig,
} from "./types";

export type AreaDatum = { x: string; y: number; category?: string };

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
  style?: ViewStyle;
};

export function AreaChart({
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
  style,
}: AreaChartProps) {
  const points: DataPoint[] = data.map((p) => ({
    x: p.x,
    y: p.y,
    category: p.category,
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
