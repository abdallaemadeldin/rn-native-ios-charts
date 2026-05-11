import ExpoModulesCore

/// One mark on the chart. `type` discriminates between bar / line /
/// area / point / rectangle / rule / sector — Swift switches on it to
/// render the appropriate SwiftUI Mark.
///
/// All optional fields default to sensible no-ops so consumers only
/// pass what they care about.
internal struct ChartMark: Record {
  /// Discriminator. One of: "bar", "line", "area", "point",
  /// "rectangle", "rule", "sector".
  @Field var type: String = "line"
  @Field var data: [ChartDataPoint] = []

  // ─── Color / fill ───
  @Field var color: UIColor?
  @Field var opacity: Double = 1.0
  /// Optional gradient — wins over solid `color` when set. Most
  /// commonly used on AreaMark for the "fill under the curve" look.
  @Field var gradient: ChartGradient?

  // ─── Stroke (line, rule) ───
  @Field var lineWidth: Double = 2.0
  /// Dash pattern in points. Empty array = solid line.
  @Field var dashArray: [Double] = []
  /// "butt" | "round" | "square". Default "round".
  @Field var lineCap: String = "round"

  // ─── Line / area interpolation ───
  /// One of: "linear", "catmullRom", "monotone", "stepStart",
  /// "stepEnd", "stepCenter". Default "linear".
  @Field var interpolation: String = "linear"

  // ─── Symbols (point marks, line w/ points) ───
  /// One of: "circle", "square", "triangle", "diamond", "pentagon",
  /// "plus", "cross", "asterisk".
  @Field var symbol: String = "circle"
  @Field var symbolSize: Double = 36
  /// When true on a `line` mark, draw point symbols at each datum.
  @Field var showPoints: Bool = false

  // ─── Bar / rectangle ───
  @Field var cornerRadius: Double = 0
  /// Bar width (pt). 0 = auto.
  @Field var barWidth: Double = 0
  /// Bar positioning when multiple BarMarks share an X:
  ///   - "auto"    (default) — SwiftUI's default behavior
  ///   - "stacked" — explicit `.positionAdjustment(.stacking)`
  ///   - "grouped" — side-by-side via `.position(by: category)`
  @Field var position: String = "auto"
  /// Horizontal bars — swap the X and Y axes for `bar` marks. Use
  /// for Top-N lists, ranked leaderboards, etc.
  @Field var horizontal: Bool = false

  // ─── Sector (pie / donut) ───
  /// Inner radius as a ratio of outer, 0–1. 0 = full pie, 0.62 = thin donut.
  @Field var innerRadius: Double = 0
  /// Outer radius as a ratio of available space, 0–1. 0 = auto.
  @Field var outerRadius: Double = 0
  /// Gap between adjacent sectors, pt.
  @Field var angularInset: Double = 0

  // ─── Rule mark orientation ───
  /// "horizontal" | "vertical". A horizontal rule draws a constant-y
  /// reference line across the chart's x extent (and vice-versa).
  @Field var orientation: String = "horizontal"
  /// Constant value the rule is drawn at (interpretation depends on
  /// orientation). When set, `data` can be empty.
  @Field var ruleValue: Double?

  init() {}
}
