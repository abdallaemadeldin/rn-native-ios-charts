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
  /// Stable identity for `ForEach` diffing across data swaps. Index-
  /// only identity caused stale layouts when the data prop was
  /// replaced with a different set of x labels (e.g., a pie tab
  /// switch) — SwiftUI re-used the old slice positions instead of
  /// rebuilding them. Combining `x` + `category` is unique within
  /// any single mark; appending the array index keeps it unique
  /// even in the pathological case of duplicate (x, category)
  /// pairs.
  var identityKey: String {
    "\(x)|\(category ?? "")"
  }
}
