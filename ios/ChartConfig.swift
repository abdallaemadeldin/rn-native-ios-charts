import ExpoModulesCore

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
  @Field var backgroundColor: UIColor?
  @Field var textColor: UIColor?
  @Field var borderColor: UIColor?
  /// Decimal places for the y value when formatting. Default 0.
  @Field var valueDecimals: Int = 0
  /// Optional prefix (eg "$") prepended to the y value.
  @Field var valuePrefix: String = ""
  /// Optional suffix (eg "%") appended to the y value.
  @Field var valueSuffix: String = ""

  init() {}
}
