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
