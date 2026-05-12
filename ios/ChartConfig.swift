import ExpoModulesCore

/// Chart annotation. Either datum-anchored (set `x`) or range-band
/// (set `xRange`). Date inputs from JS arrive as ISO-8601 strings
/// thanks to `Chart.tsx`'s pre-bridge normalization.
internal struct ChartAnnotation: Record {
  /// Datum-anchored x. Empty when this is a range band.
  @Field var x: String = ""
  /// Range-band start/end. 2 elements when set; empty otherwise.
  @Field var xRange: [String] = []
  /// Optional Y bounds in data coordinates. 2 elements when set.
  @Field var yRange: [Double] = []
  /// Label text. Empty = no label, band/marker only.
  @Field var text: String = ""
  /// Band fill / label foreground color. nil → system blue / label.
  @Field var color: UIColor?
  /// "top" | "bottom" | "inside". Default "top".
  @Field var position: String = "top"
  /// Label font size in pt. Default 11.
  @Field var fontSize: Double = 11

  init() {}
}

/// Per-axis config. Each field is optional; omit to use SwiftUI's
/// automatic behavior.
internal struct ChartAxisConfig: Record {
  @Field var hidden: Bool = false
  @Field var gridLines: Bool = true
  @Field var tickLabels: Bool = true
  /// Hex color string parsed by Expo's UIColor converter. `nil` =
  /// system default.
  @Field var labelColor: UIColor?
  @Field var gridColor: UIColor?
  @Field var labelFontSize: Double = 11
  /// Explicit numeric domain. Both must be set to take effect.
  @Field var domainMin: Double?
  @Field var domainMax: Double?
  /// Scale type for numeric axes. "linear" (default) or "log".
  /// Y-only — `chartXScale` always stays categorical/date in this
  /// release. Log scales require all values > 0.
  @Field var scaleType: String = "linear"
  /// Value-label format. Only meaningful for axes whose values are
  /// Double (in practice: the Y axis — our X axis is `String`):
  ///   - "" / "raw"      — no formatting, pass through
  ///   - "currency"      — locale-aware currency (`currencyCode`)
  ///   - "percent"       — multiplied by 100 with "%"
  ///   - "abbreviated"   — compact "1K", "1.2M", "3.4B"
  ///   - "decimal"       — plain number with `decimals` fraction digits
  @Field var valueFormat: String = ""
  /// Used when `valueFormat == "currency"`. Default "USD".
  @Field var currencyCode: String = "USD"
  /// Fraction digits for numeric formatters that respect it. Default 0.
  @Field var valueDecimals: Int = 0
  /// Prepended to the formatted value, e.g. "$" when not using the
  /// currency format. Useful for custom prefixes/suffixes.
  @Field var valuePrefix: String = ""
  /// Appended to the formatted value, e.g. "%" or " years".
  @Field var valueSuffix: String = ""
  /// Date format string for `valueFormat == "date"`. Uses Apple's
  /// `DateFormatter.dateFormat` syntax (UTS #35). Default "MMM yy"
  /// renders ISO inputs like "2026-01-15T..." as "Jan 26". Common
  /// options: "MMM d", "yyyy", "MMM d, yyyy", "HH:mm".
  @Field var dateFormat: String = "MMM yy"

  init() {}
}

/// Legend placement + visibility. SwiftUI handles auto-coloring when
/// `category` is set on data points.
internal struct ChartLegendConfig: Record {
  @Field var hidden: Bool = false
  /// "automatic" | "top" | "bottom" | "leading" | "trailing" | "overlay".
  @Field var placement: String = "automatic"

  init() {}
}

/// Chart-level animation config. Drives both the data-change
/// animation (when marks update) and the optional entrance
/// animation (when the chart first mounts). Replaces the boolean
/// `animate` flag from v0.x; `animate: true` is still honored as a
/// shorthand for `enabled: true`.
internal struct ChartAnimationConfig: Record {
  /// Master toggle. Default true — charts animate unless explicitly
  /// disabled (matches the v0.x default for `animate`).
  @Field var enabled: Bool = true
  /// Duration of data-change animations in milliseconds.
  /// Default 400ms. Ignored when `curve == "spring"` (springs are
  /// timing-free).
  @Field var duration: Double = 400
  /// Easing curve: "easeInOut" (default), "easeIn", "easeOut",
  /// "linear", or "spring".
  @Field var curve: String = "easeInOut"
  /// Entrance animation on first mount — fades in + scales from
  /// 0.96 to 1.0 over `duration`. Default false (opt-in).
  @Field var entrance: Bool = false
  /// For multi-series cartesian charts: when the tooltip scrubber is
  /// active, dim non-selected marks to `tooltip.dimOpacity`. Mirrors
  /// the pie's slice-dim behavior for line / bar / area / point
  /// charts. Default false. Pie ignores this — pies always dim
  /// unselected slices when `tooltip.enabled` is true.
  @Field var cartesianDimOnSelect: Bool = false

  init() {}
}

/// Center label drawn inside the chart's plot frame via
/// `chartBackground`. Most useful with `sector` marks (the donut hole)
/// but works on any chart.
internal struct ChartCenterLabel: Record {
  @Field var value: String?
  @Field var label: String?
  @Field var valueColor: UIColor?
  @Field var labelColor: UIColor?
  @Field var valueFontSize: Double = 18
  @Field var labelFontSize: Double = 11

  init() {}
}

/// Tooltip overlay shown when the user touches/drags on a cartesian
/// chart. Uses SwiftUI Charts' native `chartXSelection`, so the
/// scrubber snaps to data points automatically. For `sector` marks
/// (pie / donut), `chartAngleSelection` fires the `onSelect` event
/// but no visual callout is drawn — use the event to update a
/// `centerLabel` or your own JS overlay.
internal struct ChartTooltipConfig: Record {
  @Field var enabled: Bool = false
  /// Draw a vertical rule at the selected X.
  @Field var showRule: Bool = true
  /// Highlight the active point with a filled dot.
  @Field var showDot: Bool = true
  /// Show the x label above the y value in the callout.
  @Field var showTitle: Bool = true
  /// Render one row per mark at the selected X (color dot + series
  /// name + value). Falls back to single-row mode when the chart has
  /// only one cartesian mark anyway. Useful for OHLC stock charts
  /// and side-by-side series comparisons.
  @Field var multiSeries: Bool = false
  @Field var backgroundColor: UIColor?
  @Field var textColor: UIColor?
  @Field var borderColor: UIColor?
  /// Decimal places for the y value when formatting. Default 0.
  @Field var valueDecimals: Int = 0
  /// Optional prefix (eg "$") prepended to the y value.
  @Field var valuePrefix: String = ""
  /// Optional suffix (eg "%") appended to the y value.
  @Field var valueSuffix: String = ""
  /// Opacity applied to non-selected slices (or non-selected cartesian
  /// marks when `cartesianDimOnSelect` is enabled at the chart level)
  /// while another point is selected. Default 0.3.
  @Field var dimOpacity: Double = 0.3
  /// For pie / donut: when a slice is selected, scale it up by this
  /// multiplier (achieved by shrinking unselected slices in tandem so
  /// the selected one appears to grow). Default 1.05.
  @Field var sliceScale: Double = 1.05

  init() {}
}
