import { useImperativeHandle, useState } from "react";
import type { Ref } from "react";

/**
 * Imperative handle shared by every chart wrapper. The only method
 * is `clearSelection()`, which dismisses any active tooltip /
 * highlight by bumping a token prop that the SwiftUI side observes.
 *
 * Pies use this to drop a sticky slice highlight; cartesian
 * scrubber selections normally auto-clear on gesture release, but
 * the same API works there too for state-consistency callers (e.g.
 * a screen-level "Clear" button).
 */
export type ChartHandle = {
  clearSelection: () => void;
};

/**
 * Hook that wires a chart wrapper's `forwardRef` to a token-bump
 * counter. The returned `token` is the prop you pass into
 * `<Chart clearSelectionToken={...}>`; every `ref.current.clearSelection()`
 * call increments it, which Swift's `.onChange(of: clearSelectionToken)`
 * picks up and uses to wipe `selectedX` / `selectedAngleY` /
 * `selectedSlice` state.
 *
 * The bare token value is meaningless — only the change matters.
 */
export function useChartHandle(ref: Ref<ChartHandle>): number {
  const [token, setToken] = useState(0);
  useImperativeHandle(
    ref,
    () => ({
      clearSelection: () => setToken((t) => t + 1),
    }),
    []
  );
  return token;
}
