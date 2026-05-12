import * as React from "react";
import { useWindowDimensions } from "react-native";
import type { LayoutChangeEvent } from "react-native";
import {
  interpolate,
  useAnimatedStyle,
  useSharedValue,
} from "react-native-reanimated";
import type { SharedValue } from "react-native-reanimated";

/**
 * Options for `useChartScrollScale` / `<ScrollAwareChart>`. All
 * defaults assume a vertically scrolling parent and a "centered =
 * full size, edges = scaled down" feel.
 */
export type ChartScrollScaleOptions = {
  /**
   * Explicit viewport height in px. Defaults to the device's
   * window height — fine for most "the whole screen is one
   * ScrollView" dashboards. Override if your scrolling parent is
   * inset (e.g. inside a modal sheet, behind a tab bar that
   * shrinks the visible area).
   */
  viewportHeight?: number;
  /** Scale when the child is at the edges of `range`. Default 0.92. */
  minScale?: number;
  /** Scale when the child sits centered in the viewport. Default 1.0. */
  maxScale?: number;
  /**
   * Fade the child as well as scaling. Default false. Useful when
   * you want a deeper depth-of-field feel; turn off to keep
   * off-screen-bound text readable.
   */
  fadeOut?: boolean;
  /** Opacity at the edges of `range` when `fadeOut` is true. Default 0.5. */
  minOpacity?: number;
  /**
   * Distance from viewport center (in px) at which the scale
   * reaches `minScale`. Larger = gentler ramp. Default 320.
   */
  range?: number;
};

/**
 * Result of `useChartScrollScale`. Spread `onLayout` onto the
 * outer `<Animated.View>` (so the hook can measure the child's
 * position in the scroll content) and pass `style` to the same
 * view's `style` prop.
 */
export type ChartScrollScaleResult = {
  onLayout: (event: LayoutChangeEvent) => void;
  style: ReturnType<typeof useAnimatedStyle>;
};

/**
 * Worklet-driven scroll-position-aware scale + opacity for a
 * chart wrapped in an `<Animated.View>` inside an
 * `<Animated.ScrollView>`. Reads scroll position from a
 * `SharedValue` driven by the parent's `useAnimatedScrollHandler`
 * — every interpolation runs on the UI thread, so 60Hz (and 120Hz
 * on ProMotion devices) is comfortable.
 *
 * Why a hook + a wrapper component instead of a single component?
 * Some callers want to layer the animated transform with their
 * own (shadows, rotations, tilt) — the hook lets them compose
 * styles. The `<ScrollAwareChart>` component is just sugar over
 * this hook for the common case.
 *
 * Usage:
 *
 * ```tsx
 * import Animated, {
 *   useAnimatedScrollHandler,
 *   useSharedValue,
 * } from "react-native-reanimated";
 * import { useChartScrollScale, LineChart } from "rn-native-ios-charts";
 *
 * const scrollY = useSharedValue(0);
 * const onScroll = useAnimatedScrollHandler({
 *   onScroll: (e) => { scrollY.value = e.contentOffset.y; },
 * });
 * const { onLayout, style } = useChartScrollScale(scrollY);
 *
 * <Animated.ScrollView onScroll={onScroll} scrollEventThrottle={16}>
 *   <Animated.View onLayout={onLayout} style={style}>
 *     <LineChart {...} />
 *   </Animated.View>
 * </Animated.ScrollView>
 * ```
 *
 * Caveats:
 *   - The hook measures position via `onLayout`, which only fires
 *     on layout changes. If the parent re-flows but the child's
 *     local frame doesn't change, you might keep stale Y values
 *     until the next layout. For dashboards with stable structure
 *     this is fine; for highly dynamic UIs, consider keying the
 *     child to force remeasurement.
 *   - Don't use this inside a `FlatList`/`FlashList` row — those
 *     recycle cells, and the shared values get reused with stale
 *     positions. For lists with per-row scroll animation, prefer
 *     `react-native-reanimated`'s `useAnimatedRef` + `measure()`
 *     pattern with per-row sharedValues.
 */
export function useChartScrollScale(
  scrollY: SharedValue<number>,
  options?: ChartScrollScaleOptions
): ChartScrollScaleResult {
  const {
    viewportHeight,
    minScale = 0.92,
    maxScale = 1.0,
    fadeOut = false,
    minOpacity = 0.5,
    range = 320,
  } = options ?? {};

  const { height: windowHeight } = useWindowDimensions();
  const viewport = viewportHeight ?? windowHeight;

  // Layout values live in shared values so the worklet can read
  // them without crossing the JS bridge. Updated synchronously
  // inside `onLayout` (which runs on the JS thread, but the
  // assignment to a shared value is bridge-free).
  const layoutY = useSharedValue(0);
  const layoutHeight = useSharedValue(0);

  const onLayout = React.useCallback(
    (event: LayoutChangeEvent) => {
      layoutY.value = event.nativeEvent.layout.y;
      layoutHeight.value = event.nativeEvent.layout.height;
    },
    [layoutY, layoutHeight]
  );

  const style = useAnimatedStyle(() => {
    "worklet";
    const childCenter = layoutY.value + layoutHeight.value / 2;
    const viewportCenter = scrollY.value + viewport / 2;
    const distance = Math.abs(childCenter - viewportCenter);
    const scale = interpolate(
      distance,
      [0, range],
      [maxScale, minScale],
      "clamp"
    );
    const opacity = fadeOut
      ? interpolate(distance, [0, range], [1, minOpacity], "clamp")
      : 1;
    return {
      opacity,
      transform: [{ scale }],
    };
  });

  return { onLayout, style };
}
