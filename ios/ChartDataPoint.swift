import ExpoModulesCore

/// One datum on any chart. The shape is intentionally permissive so a
/// single struct serves bar, line, area, point, rectangle, rule and
/// sector marks.
///
/// - `x` / `y`: primary coordinate. `x` is stringly-typed because
///   SwiftUI Charts categorical axes want strings; if your data is
///   numeric, stringify it on the JS side (`String(year)`).
/// - `yEnd`: optional second value — used by range bar / rectangle
///   marks (a stacked low/high pair).
/// - `category`: optional grouping key. When present, the chart
///   colors by `.value("Category", category)` so SwiftUI assigns a
///   consistent color per series across the legend.
/// - `color`: per-point override. Wins over the mark-level color
///   when both are set.
internal struct ChartDataPoint: Record {
  @Field var x: String = ""
  @Field var y: Double = 0
  @Field var yEnd: Double?
  @Field var category: String?
  @Field var color: UIColor?

  init() {}
}

extension ChartDataPoint {
  /// Stable identity for `ForEach` diffing across data swaps, and
  /// for `SliceID`-based selection state in `ChartHostView`. Index-
  /// only identity caused stale layouts when the data prop was
  /// replaced with a different set of x labels (e.g., a pie tab
  /// switch) — SwiftUI re-used the old slice positions instead of
  /// rebuilding them.
  ///
  /// `(x, category)` is unique within a single mark for every
  /// real-world chart shape we support (one entry per category per
  /// x for stacked/grouped bars, unique slice labels for pies, etc).
  /// Two points sharing both fields within the same mark would
  /// collide and confuse SwiftUI's diff — that case is genuinely
  /// pathological and we don't try to handle it. Pass distinct
  /// `category` values to disambiguate if you ever hit it.
  var identityKey: String {
    "\(x)|\(category ?? "")"
  }
}
