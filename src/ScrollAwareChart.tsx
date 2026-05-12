import * as React from "react";
import type { ViewStyle } from "react-native";
import Animated from "react-native-reanimated";
import type { SharedValue } from "react-native-reanimated";
import {
  useChartScrollScale,
  type ChartScrollScaleOptions,
} from "./useChartScrollScale";

/**
 * Sugar wrapper that combines `useChartScrollScale` with an
 * `<Animated.View>` for the common "wrap one chart, scroll-scale
 * it" case. Equivalent to:
 *
 * ```tsx
 * const { onLayout, style } = useChartScrollScale(scrollY, opts);
 * <Animated.View onLayout={onLayout} style={[outerStyle, style]}>
 *   {children}
 * </Animated.View>
 * ```
 *
 * Reach for the hook directly when you need to compose the
 * scroll-scale style with your own animated styles (shadows,
 * tilts, parallax). Both paths run entirely on the UI thread —
 * `useAnimatedScrollHandler` + `useAnimatedStyle` keep frame
 * computation off the JS bridge.
 *
 * **120Hz on ProMotion** isn't automatic — add
 * `CADisableMinimumFrameDurationOnPhone = YES` to your app's
 * `Info.plist`. iOS caps third-party apps at 60Hz on ProMotion
 * displays without that flag, regardless of what Reanimated does.
 *
 * Usage:
 *
 * ```tsx
 * import Animated, {
 *   useAnimatedScrollHandler,
 *   useSharedValue,
 *   // …or use `useScrollOffset(scrollRef)` if you don't need
 *   // momentum/drag callbacks — it's the cleaner v4 API.
 * } from "react-native-reanimated";
 * import { ScrollAwareChart, LineChart } from "rn-native-ios-charts";
 *
 * const scrollY = useSharedValue(0);
 * const onScroll = useAnimatedScrollHandler({
 *   onScroll: (e) => { scrollY.value = e.contentOffset.y; },
 * });
 *
 * <Animated.ScrollView onScroll={onScroll} scrollEventThrottle={16}>
 *   <ScrollAwareChart scrollY={scrollY} fadeOut>
 *     <LineChart {...} />
 *   </ScrollAwareChart>
 * </Animated.ScrollView>
 * ```
 *
 * Caveats:
 *   - **Don't use inside a recycled list cell** (FlatList,
 *     FlashList). Cells reuse instances, so a sticky shared value
 *     can keep pointing at the wrong row's layout. Wrap each
 *     chart at the screen level instead, or key the row on item id.
 *   - The wrapper measures via `onLayout`. If only the parent
 *     reflows (siblings above grow/shrink) without changing the
 *     child's local frame, `onLayout` may not refire — the cached
 *     Y goes stale. For highly dynamic dashboards, prefer the
 *     hook + `measure()` worklet pattern from Reanimated.
 *
 * Requires `react-native-reanimated` as a peer dependency. If
 * you import this file without Reanimated installed, the module
 * load itself will throw — keep the import inside the conditional
 * branch of `isChartSupported()` if you need to support
 * non-iOS-17 targets gracefully.
 */
export type ScrollAwareChartProps = ChartScrollScaleOptions & {
  /**
   * Scroll position shared value. Drive from your parent
   * `Animated.ScrollView`'s `useAnimatedScrollHandler`, or from
   * `useScrollOffset(scrollRef)` (Reanimated 4+, drag-only
   * callbacks).
   */
  scrollY: SharedValue<number>;
  children: React.ReactNode;
  /** Outer view style — composes with the animated transform. */
  style?: ViewStyle;
};

export function ScrollAwareChart({
  scrollY,
  children,
  style,
  ...options
}: ScrollAwareChartProps) {
  const { onLayout, style: animatedStyle } = useChartScrollScale(
    scrollY,
    options
  );
  return (
    <Animated.View onLayout={onLayout} style={[style, animatedStyle]}>
      {children}
    </Animated.View>
  );
}
