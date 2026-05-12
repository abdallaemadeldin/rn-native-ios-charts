import { requireNativeView } from "expo";
import * as React from "react";
import { Platform, View } from "react-native";
import type {
  Annotation,
  ChartProps,
  DataPoint,
  Mark,
  SelectedPoint,
} from "./types";

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

/**
 * Normalizes a single datum's x value for transport over the
 * Expo bridge. `Date` instances become their ISO-8601 string so
 * the Swift side can parse them deterministically when the axis is
 * configured with `valueFormat: "date"`. Everything else
 * (numbers-as-strings, categorical strings) passes through.
 */
function normalizeX(x: string | Date): string {
  if (x instanceof Date) {
    return x.toISOString();
  }
  return x;
}

/**
 * Walks `marks` and normalizes every datum's `x`. Returns a fresh
 * array only when any conversion was needed — otherwise the input
 * is passed through so React doesn't see a new reference and
 * re-render needlessly.
 */
function normalizeMarks(marks: Mark[]): Mark[] {
  let mutated = false;
  const out = marks.map((mark) => {
    const newData = mark.data.map((p) => {
      if (p.x instanceof Date) {
        mutated = true;
        const next: DataPoint = { ...p, x: normalizeX(p.x) };
        return next;
      }
      return p;
    });
    if (newData === mark.data) return mark;
    return { ...mark, data: newData };
  });
  return mutated ? out : marks;
}

/**
 * Normalize Date values inside an `Annotation` array, mirroring
 * the data-point handling. Returns the input unchanged when no
 * conversion is needed.
 */
function normalizeAnnotations(
  annotations: Annotation[] | undefined
): Annotation[] | undefined {
  if (!annotations || annotations.length === 0) return annotations;
  let mutated = false;
  const out = annotations.map((ann) => {
    let next: Annotation = ann;
    if (next.x instanceof Date) {
      next = { ...next, x: normalizeX(next.x) };
      mutated = true;
    }
    if (
      next.xRange &&
      (next.xRange[0] instanceof Date || next.xRange[1] instanceof Date)
    ) {
      next = {
        ...next,
        xRange: [normalizeX(next.xRange[0]), normalizeX(next.xRange[1])],
      };
      mutated = true;
    }
    return next;
  });
  return mutated ? out : annotations;
}

export function Chart(props: ChartProps) {
  if (!NativeChart) {
    return <View style={props.style} />;
  }

  const { onSelect, marks, annotations, ...rest } = props;
  const normalizedMarks = React.useMemo(() => normalizeMarks(marks), [marks]);
  const normalizedAnnotations = React.useMemo(
    () => normalizeAnnotations(annotations),
    [annotations]
  );

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

  return (
    <NativeChart
      {...rest}
      marks={normalizedMarks}
      annotations={normalizedAnnotations}
      onSelect={handleSelect}
    />
  );
}
