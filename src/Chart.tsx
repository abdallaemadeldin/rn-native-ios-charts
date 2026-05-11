import { requireNativeView } from "expo";
import * as React from "react";
import { Platform, View } from "react-native";
import type { ChartProps, SelectedPoint } from "./types";

/**
 * Generic SwiftUI Charts view. Render any combination of bar / line /
 * area / point / rectangle / rule / sector marks by passing them in
 * the `marks` array. iOS-only — on other platforms this is a no-op
 * placeholder `View`, so consuming code can mount it unconditionally
 * and feature-detect via `Platform.OS`.
 *
 * Use the convenience wrappers (`PieChart`, `LineChart`, `BarChart`,
 * etc.) for common single-mark cases — they all delegate here.
 */

// Expo Modules events deliver the payload wrapped in `nativeEvent`.
// We re-shape it into the public `SelectedPoint` type at the boundary
// so consumers don't have to deal with the bridge layout.
type NativeSelectPayload = {
  x?: string;
  y?: number;
  markIndex?: number;
  pointIndex?: number;
};

type NativeChartProps = Omit<ChartProps, "onSelect"> & {
  onSelect?: (event: { nativeEvent: NativeSelectPayload }) => void;
};

const NativeChart =
  Platform.OS === "ios"
    ? requireNativeView<NativeChartProps>("NativeIosCharts", "ChartView")
    : null;

export function Chart(props: ChartProps) {
  if (!NativeChart) {
    return <View style={props.style} />;
  }

  const { onSelect, ...rest } = props;

  // Wrap the user's callback to unwrap the native event shape. Empty
  // payloads (`{}`) signal a cleared selection — emit `null` for them.
  const handleSelect = onSelect
    ? (event: { nativeEvent: NativeSelectPayload }) => {
        const { x, y, markIndex, pointIndex } = event.nativeEvent ?? {};
        const point: SelectedPoint =
          typeof x === "string" && typeof y === "number"
            ? {
                x,
                y,
                markIndex: typeof markIndex === "number" ? markIndex : 0,
                pointIndex: typeof pointIndex === "number" ? pointIndex : 0,
              }
            : null;
        onSelect(point);
      }
    : undefined;

  return <NativeChart {...rest} onSelect={handleSelect} />;
}
