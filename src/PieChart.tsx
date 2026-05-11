import * as React from "react";
import type { ColorValue, ViewStyle } from "react-native";
import { Chart } from "./Chart";
import type {
  CenterLabel,
  DataPoint,
  LegendConfig,
  SelectedPoint,
} from "./types";

export type PieSlice = {
  label: string;
  value: number;
  color?: ColorValue;
};

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
   * Fires when the user taps a slice. The payload `x` is the slice
   * label and `y` is its value. `null` when the selection clears.
   * No visual callout is drawn — wire `centerLabel` from this event
   * to update the donut hole copy.
   */
  onSelect?: (point: SelectedPoint) => void;
  animate?: boolean;
  style?: ViewStyle;
};

export function PieChart({
  data,
  innerRadius = 0.62,
  outerRadius,
  angularInset = 2,
  cornerRadius = 2,
  centerLabel,
  legend,
  onSelect,
  animate,
  style,
}: PieChartProps) {
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
      legend={legend ?? { hidden: true }}
      centerLabel={centerLabel}
      onSelect={onSelect}
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
