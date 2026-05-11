import SwiftUI
import Charts
import ExpoModulesCore

internal final class ChartViewProps: ObservableObject {
  @Published var marks: [ChartMark] = []
  @Published var xAxis: ChartAxisConfig = ChartAxisConfig()
  @Published var yAxis: ChartAxisConfig = ChartAxisConfig()
  @Published var legend: ChartLegendConfig = ChartLegendConfig()
  @Published var centerLabel: ChartCenterLabel = ChartCenterLabel()
  @Published var tooltip: ChartTooltipConfig = ChartTooltipConfig()
  @Published var animate: Bool = true
  /// Enable native horizontal scrolling via SwiftUI's
  /// `chartScrollableAxes(.horizontal)`. Far better than wrapping the
  /// chart in a RN `<ScrollView horizontal>` — keeps tooltip touch
  /// coords correct and avoids gesture conflicts with the scrubber.
  @Published var scrollableX: Bool = false
  /// How many X categories are visible at once when scrolling. Only
  /// applies when `scrollableX` is true. 0 = let SwiftUI decide.
  @Published var visibleXCount: Int = 0
  /// Trading-chart mode for the X axis: removes SwiftUI Charts'
  /// default plot-dimension padding so the line / area reaches both
  /// edges of the plot. The first and last data points sit flush
  /// against the screen edges — like Robinhood, Apple Stocks, etc.
  @Published var tightX: Bool = false
  /// Maps a `point.category` string → fill color. Maps to SwiftUI's
  /// `chartForegroundStyleScale(_:)`. Lets callers define a palette
  /// once at the chart level instead of setting `color` on every
  /// datum. Empty dictionary = SwiftUI's automatic palette.
  @Published var categoryColors: [String: UIColor] = [:]

  /// Closure invoked when the user selects a point via the scrubber
  /// (or taps a pie sector). Wired to the Expo `onSelect` event.
  /// `nil` payload = selection cleared.
  var onSelect: (([String: Any]?) -> Void)?
}

/// One ExpoView that hosts a SwiftUI Chart, configurable to render
/// any combination of bar / line / area / point / rectangle / rule /
/// sector marks. Designed to be the single native primitive every
/// chart type ships through.
///
/// SwiftUI Charts' unified API (`Chart {}`, `SectorMark`,
/// `chartBackground`) is iOS 17+. The host view installs cleanly on
/// iOS 15.1+ so this pod can be added to any modern Expo project,
/// but on iOS 16 and earlier the chart renders nothing — matching
/// the JS-side no-op on non-iOS platforms.
internal final class ChartView: ExpoView {
  let props = ChartViewProps()
  /// JS `onSelect` event — fired when the user picks a point via
  /// the scrubber, taps a pie sector, or releases (clears selection).
  let onSelect = EventDispatcher()
  private let hostingController: UIViewController

  required init(appContext: AppContext? = nil) {
    if #available(iOS 17.0, *) {
      self.hostingController = UIHostingController(
        rootView: ChartHostView(props: props)
      )
    } else {
      // No-op host on iOS < 17. Keeps the view tree valid without
      // pulling in any iOS-17-only SwiftUI types.
      self.hostingController = UIHostingController(rootView: EmptyView())
    }
    super.init(appContext: appContext)

    // Bridge the props' Swift closure to the JS event dispatcher.
    // SwiftUI side calls `props.onSelect?(payload)`; we forward it.
    props.onSelect = { [weak self] payload in
      guard let self else { return }
      self.onSelect(payload ?? [:])
    }

    hostingController.view.backgroundColor = .clear
    addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }
}

// MARK: - SwiftUI implementation

@available(iOS 17.0, *)
private struct ChartHostView: View {
  @ObservedObject var props: ChartViewProps

  // Native selection bindings. SwiftUI Charts snaps to nearest datum
  // for both, so we don't have to do hit-testing ourselves.
  // - `selectedX` fires for cartesian marks (bar / line / area /
  //   point / rectangle).
  // - `selectedAngleY` fires for `sector` marks (pie / donut).
  @State private var selectedX: String?
  @State private var selectedAngleY: Double?

  var body: some View {
    Chart {
      ForEach(Array(props.marks.enumerated()), id: \.offset) { markIndex, mark in
        renderMark(mark, markIndex: markIndex)
      }
    }
    .chartLegend(legendVisibility)
    .customizedXAxis(config: props.xAxis)
    .customizedYAxis(config: props.yAxis)
    .conditionalChartXScale(domain: scaleDomain(props.xAxis))
    .conditionalChartYScale(domain: scaleDomain(props.yAxis))
    .conditionalTightX(enabled: props.tightX)
    .conditionalCategoryColors(props.categoryColors)
    .conditionalScrollable(
      enabled: props.scrollableX,
      visibleCount: props.visibleXCount
    )
    .chartBackground { proxy in
      centerLabelView(proxy: proxy)
    }
    .chartXSelection(value: $selectedX)
    .chartAngleSelection(value: $selectedAngleY)
    .chartOverlay { proxy in
      tooltipOverlay(proxy: proxy)
    }
    .onChange(of: selectedX) { _, _ in emitSelect() }
    .onChange(of: selectedAngleY) { _, _ in emitSelect() }
    .animation(
      props.animate ? .easeInOut(duration: 0.4) : nil,
      value: marksFingerprint
    )
  }

  // MARK: - Tooltip overlay

  @ViewBuilder
  private func tooltipOverlay(proxy: ChartProxy) -> some View {
    if props.tooltip.enabled, let x = selectedX, let active = findActivePoint(x: x) {
      GeometryReader { geo in
        if let plotFrame = proxy.plotFrame {
          let plot = geo[plotFrame]
          // Translate data → screen coords inside the plot frame.
          if let xRel = proxy.position(forX: x) {
            let xAbs = xRel + plot.minX
            // Y coordinate of the active datum. `position(forY:)` is
            // optional because numeric Y axes can be auto-scaled.
            let yAbs: CGFloat? = proxy.position(forY: active.point.y).map {
              $0 + plot.minY
            }

            ZStack(alignment: .topLeading) {
              if props.tooltip.showRule {
                Path { path in
                  path.move(to: CGPoint(x: xAbs, y: plot.minY))
                  path.addLine(to: CGPoint(x: xAbs, y: plot.maxY))
                }
                .stroke(
                  Color(props.tooltip.borderColor ?? UIColor.tertiaryLabel),
                  style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
              }
              if props.tooltip.showDot, let y = yAbs {
                Circle()
                  .fill(Color(activeColor(active.point) ?? UIColor.label))
                  .frame(width: 10, height: 10)
                  .overlay(
                    Circle()
                      .stroke(Color(props.tooltip.backgroundColor ?? UIColor.systemBackground), lineWidth: 2)
                  )
                  .position(x: xAbs, y: y)
              }
              calloutContent(activeX: x, fallback: active)
                .fixedSize()
                .modifier(CalloutPlacement(
                  xAbs: xAbs,
                  yAbs: yAbs ?? (plot.minY + 16),
                  plot: plot
                ))
            }
          }
        }
      }
    }
  }

  /// Picks single-row or multi-row callout based on `tooltip.multiSeries`.
  @ViewBuilder
  private func calloutContent(
    activeX x: String,
    fallback: ActiveHit
  ) -> some View {
    if props.tooltip.multiSeries {
      let hits = findAllActivePoints(x: x)
      if hits.count > 1 {
        multiSeriesCalloutView(activeX: x, hits: hits)
      } else {
        calloutView(point: fallback.point)
      }
    } else {
      calloutView(point: fallback.point)
    }
  }

  /// Multi-row tooltip — one row per cartesian mark at the selected X.
  /// Each row has a small color dot + the series name (or the mark's
  /// category if available) + the formatted value.
  @ViewBuilder
  private func multiSeriesCalloutView(
    activeX x: String,
    hits: [ActiveHit]
  ) -> some View {
    let bg = Color(props.tooltip.backgroundColor ?? UIColor.systemBackground)
    let fg = Color(props.tooltip.textColor ?? UIColor.label)
    let border = Color(props.tooltip.borderColor ?? UIColor.separator)

    VStack(alignment: .leading, spacing: 4) {
      if props.tooltip.showTitle {
        Text(x)
          .font(.system(size: 11))
          .foregroundColor(fg.opacity(0.6))
          .padding(.bottom, 2)
      }
      ForEach(Array(hits.enumerated()), id: \.offset) { _, hit in
        HStack(spacing: 6) {
          Circle()
            .fill(Color(activeColor(hit.point) ?? UIColor.label))
            .frame(width: 7, height: 7)
          Text(seriesLabel(for: hit))
            .font(.system(size: 11))
            .foregroundColor(fg.opacity(0.8))
          Spacer(minLength: 8)
          Text(formatValue(hit.point.y))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(fg)
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(bg)
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
    )
  }

  /// Per-row label in the multi-series callout. Prefers the point's
  /// `category`, falls back to `Series N` where N is the mark index.
  private func seriesLabel(for hit: ActiveHit) -> String {
    if let cat = hit.point.category, !cat.isEmpty {
      return cat
    }
    return "Series \(hit.markIndex + 1)"
  }

  @ViewBuilder
  private func calloutView(point: ChartDataPoint) -> some View {
    let bg = Color(props.tooltip.backgroundColor ?? UIColor.systemBackground)
    let fg = Color(props.tooltip.textColor ?? UIColor.label)
    let border = Color(props.tooltip.borderColor ?? UIColor.separator)

    VStack(alignment: .leading, spacing: 2) {
      if props.tooltip.showTitle {
        Text(point.x)
          .font(.system(size: 11))
          .foregroundColor(fg.opacity(0.6))
      }
      Text(formatValue(point.y))
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(fg)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(bg)
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
    )
  }

  /// Result of a single-series tooltip hit-test: the active datum
  /// plus where it lives in the marks tree.
  private struct ActiveHit {
    let point: ChartDataPoint
    let markIndex: Int
    let pointIndex: Int
  }

  private func findActivePoint(x: String) -> ActiveHit? {
    // Prefer non-rule, non-sector marks (those have meaningful Y at X).
    for (mi, mark) in props.marks.enumerated()
    where mark.type != "rule" && mark.type != "sector" {
      if let pi = mark.data.firstIndex(where: { $0.x == x }) {
        return ActiveHit(
          point: mark.data[pi], markIndex: mi, pointIndex: pi
        )
      }
    }
    // Fallback: scan everything.
    for (mi, mark) in props.marks.enumerated() {
      if let pi = mark.data.firstIndex(where: { $0.x == x }) {
        return ActiveHit(
          point: mark.data[pi], markIndex: mi, pointIndex: pi
        )
      }
    }
    return nil
  }

  /// All cartesian marks that have a datum at `x`. Used by the
  /// multi-series tooltip to render one row per series. Sector and
  /// rule marks are skipped (they don't have a meaningful Y at X).
  private func findAllActivePoints(x: String) -> [ActiveHit] {
    var hits: [ActiveHit] = []
    for (mi, mark) in props.marks.enumerated()
    where mark.type != "rule" && mark.type != "sector" {
      if let pi = mark.data.firstIndex(where: { $0.x == x }) {
        hits.append(
          ActiveHit(
            point: mark.data[pi], markIndex: mi, pointIndex: pi
          )
        )
      }
    }
    return hits
  }

  private func activeColor(_ point: ChartDataPoint) -> UIColor? {
    if let c = point.color { return c }
    for mark in props.marks {
      if mark.data.contains(where: { $0.x == point.x }), let mc = mark.color {
        return mc
      }
    }
    return nil
  }

  private func formatValue(_ y: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = props.tooltip.valueDecimals
    formatter.maximumFractionDigits = props.tooltip.valueDecimals
    let num = formatter.string(from: NSNumber(value: y)) ?? String(y)
    return "\(props.tooltip.valuePrefix)\(num)\(props.tooltip.valueSuffix)"
  }

  /// Dispatches the JS `onSelect` event with the currently-selected
  /// point (or `nil` if cleared). Payload includes `markIndex` and
  /// `pointIndex` so consumers can locate the datum deterministically
  /// — value-only matching is fragile when multiple slices/points
  /// share the same y value.
  private func emitSelect() {
    if let x = selectedX, let hit = findActivePoint(x: x) {
      props.onSelect?([
        "x": hit.point.x,
        "y": hit.point.y,
        "markIndex": hit.markIndex,
        "pointIndex": hit.pointIndex,
      ])
      return
    }
    if let ay = selectedAngleY {
      // Walk sector marks to find both the mark index and the slice
      // index — needed so consumers can map back to their data array
      // even when two slices have the same y value.
      for (mi, mark) in props.marks.enumerated() where mark.type == "sector" {
        if let pi = mark.data.firstIndex(where: {
          abs($0.y - ay) < 0.0001
        }) {
          let p = mark.data[pi]
          props.onSelect?([
            "x": p.x,
            "y": p.y,
            "markIndex": mi,
            "pointIndex": pi,
          ])
          return
        }
      }
    }
    props.onSelect?(nil)
  }

  // MARK: - Mark dispatch

  @ChartContentBuilder
  private func renderMark(_ mark: ChartMark, markIndex: Int) -> some ChartContent {
    ForEach(Array(mark.data.enumerated()), id: \.offset) { idx, point in
      buildMark(mark: mark, point: point, markIndex: markIndex, pointIndex: idx)
    }
  }

  @ChartContentBuilder
  private func buildMark(
    mark: ChartMark,
    point: ChartDataPoint,
    markIndex: Int,
    pointIndex: Int
  ) -> some ChartContent {
    switch mark.type {
    case "bar":
      barMark(mark: mark, point: point)
    case "line":
      lineMark(mark: mark, point: point)
      if mark.showPoints {
        pointMark(mark: mark, point: point)
      }
    case "area":
      areaMark(mark: mark, point: point)
    case "point":
      pointMark(mark: mark, point: point)
    case "rectangle":
      rectangleMark(mark: mark, point: point)
    case "rule":
      ruleMark(mark: mark, point: point)
    case "sector":
      sectorMark(mark: mark, point: point)
    default:
      lineMark(mark: mark, point: point)
    }
  }

  // MARK: - Individual marks

  @ChartContentBuilder
  private func barMark(mark: ChartMark, point: ChartDataPoint) -> some ChartContent {
    // Build the base mark first — horizontal bars swap X and Y so
    // long-tail labels read nicely on a vertical axis (Top-N pattern).
    if mark.horizontal {
      BarMark(
        x: .value("X", point.y),
        y: .value("Y", point.x),
        height: mark.barWidth > 0 ? .fixed(mark.barWidth) : .automatic
      )
      .cornerRadius(mark.cornerRadius)
      .foregroundStyle(resolveFill(mark: mark, point: point))
      .opacity(mark.opacity)
      .conditionalBarPosition(
        kind: mark.position,
        category: point.category
      )
    } else {
      BarMark(
        x: .value("X", point.x),
        y: .value("Y", point.y),
        width: mark.barWidth > 0 ? .fixed(mark.barWidth) : .automatic
      )
      .cornerRadius(mark.cornerRadius)
      .foregroundStyle(resolveFill(mark: mark, point: point))
      .opacity(mark.opacity)
      .conditionalBarPosition(
        kind: mark.position,
        category: point.category
      )
    }
  }

  @ChartContentBuilder
  private func lineMark(mark: ChartMark, point: ChartDataPoint) -> some ChartContent {
    LineMark(
      x: .value("X", point.x),
      y: .value("Y", point.y),
      series: .value("Series", point.category ?? "default")
    )
    .interpolationMethod(interpolationMethod(mark.interpolation))
    .lineStyle(StrokeStyle(
      lineWidth: mark.lineWidth,
      lineCap: lineCap(mark.lineCap),
      dash: mark.dashArray.map { CGFloat($0) }
    ))
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(mark.opacity)
  }

  @ChartContentBuilder
  private func areaMark(mark: ChartMark, point: ChartDataPoint) -> some ChartContent {
    AreaMark(
      x: .value("X", point.x),
      y: .value("Y", point.y),
      series: .value("Series", point.category ?? "default")
    )
    .interpolationMethod(interpolationMethod(mark.interpolation))
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(mark.opacity)
  }

  @ChartContentBuilder
  private func pointMark(mark: ChartMark, point: ChartDataPoint) -> some ChartContent {
    PointMark(
      x: .value("X", point.x),
      y: .value("Y", point.y)
    )
    .symbol(symbolShape(mark.symbol))
    .symbolSize(mark.symbolSize)
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(mark.opacity)
  }

  @ChartContentBuilder
  private func rectangleMark(mark: ChartMark, point: ChartDataPoint) -> some ChartContent {
    RectangleMark(
      x: .value("X", point.x),
      yStart: .value("Y", point.y),
      yEnd: .value("YEnd", point.yEnd ?? point.y)
    )
    .cornerRadius(mark.cornerRadius)
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(mark.opacity)
  }

  @ChartContentBuilder
  private func ruleMark(mark: ChartMark, point: ChartDataPoint) -> some ChartContent {
    if mark.orientation == "vertical" {
      RuleMark(x: .value("X", point.x))
        .lineStyle(StrokeStyle(
          lineWidth: mark.lineWidth,
          lineCap: lineCap(mark.lineCap),
          dash: mark.dashArray.map { CGFloat($0) }
        ))
        .foregroundStyle(resolveFill(mark: mark, point: point))
        .opacity(mark.opacity)
    } else {
      RuleMark(y: .value("Y", point.y))
        .lineStyle(StrokeStyle(
          lineWidth: mark.lineWidth,
          lineCap: lineCap(mark.lineCap),
          dash: mark.dashArray.map { CGFloat($0) }
        ))
        .foregroundStyle(resolveFill(mark: mark, point: point))
        .opacity(mark.opacity)
    }
  }

  @ChartContentBuilder
  private func sectorMark(mark: ChartMark, point: ChartDataPoint) -> some ChartContent {
    SectorMark(
      angle: .value("Value", point.y),
      innerRadius: .ratio(mark.innerRadius),
      outerRadius: mark.outerRadius > 0 ? .ratio(mark.outerRadius) : .inset(0),
      angularInset: mark.angularInset
    )
    .cornerRadius(mark.cornerRadius)
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(mark.opacity)
  }

  // MARK: - Fill resolution

  private func resolveFill(mark: ChartMark, point: ChartDataPoint) -> AnyShapeStyle {
    // Priority: per-point color > gradient > mark color > system default.
    if let pc = point.color {
      return AnyShapeStyle(Color(pc))
    }
    if let grad = mark.gradient {
      return AnyShapeStyle(buildGradient(grad, baseColor: mark.color))
    }
    if let mc = mark.color {
      return AnyShapeStyle(Color(mc))
    }
    return AnyShapeStyle(Color.accentColor)
  }

  private func buildGradient(
    _ grad: ChartGradient, baseColor: UIColor?
  ) -> LinearGradient {
    let base = baseColor.map { Color($0) } ?? Color.accentColor
    let stops: [Gradient.Stop]
    if !grad.stops.isEmpty {
      stops = grad.stops.map { s in
        Gradient.Stop(
          color: (s.color.map { Color($0) } ?? base).opacity(s.opacity),
          location: CGFloat(s.offset)
        )
      }
    } else {
      stops = [
        Gradient.Stop(
          color: base.opacity(grad.startOpacity), location: 0),
        Gradient.Stop(
          color: base.opacity(grad.endOpacity), location: 1),
      ]
    }
    return LinearGradient(
      gradient: Gradient(stops: stops),
      startPoint: UnitPoint(x: grad.startX, y: grad.startY),
      endPoint: UnitPoint(x: grad.endX, y: grad.endY)
    )
  }

  // MARK: - Center label overlay

  @ViewBuilder
  private func centerLabelView(proxy: ChartProxy) -> some View {
    if props.centerLabel.value != nil || props.centerLabel.label != nil {
      GeometryReader { geo in
        if let plotFrame = proxy.plotFrame {
          let f = geo[plotFrame]
          VStack(spacing: 2) {
            if let v = props.centerLabel.value {
              Text(v)
                .font(.system(
                  size: CGFloat(props.centerLabel.valueFontSize),
                  weight: .semibold
                ))
                .foregroundColor(
                  Color(props.centerLabel.valueColor ?? UIColor.label)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
            if let l = props.centerLabel.label {
              Text(l)
                .font(.system(size: CGFloat(props.centerLabel.labelFontSize)))
                .foregroundColor(
                  Color(props.centerLabel.labelColor ?? UIColor.secondaryLabel)
                )
                .lineLimit(1)
            }
          }
          .frame(width: f.width, height: f.height)
          .position(x: f.midX, y: f.midY)
        }
      }
    }
  }

  // MARK: - Helpers

  private var legendVisibility: Visibility {
    props.legend.hidden ? .hidden : .visible
  }

  private func scaleDomain(_ axis: ChartAxisConfig) -> ClosedRange<Double>? {
    guard let lo = axis.domainMin, let hi = axis.domainMax, hi > lo else {
      return nil
    }
    return lo...hi
  }

  // Used as the trigger for `animation(_, value:)`. Stable hash of
  // every y so SwiftUI knows when to re-animate the chart.
  private var marksFingerprint: [Double] {
    props.marks.flatMap { m in m.data.map(\.y) }
  }

  private func interpolationMethod(_ v: String) -> InterpolationMethod {
    switch v {
    case "catmullRom": return .catmullRom
    case "monotone": return .monotone
    case "stepStart": return .stepStart
    case "stepEnd": return .stepEnd
    case "stepCenter": return .stepCenter
    default: return .linear
    }
  }

  private func lineCap(_ v: String) -> CGLineCap {
    switch v {
    case "butt": return .butt
    case "square": return .square
    default: return .round
    }
  }

  private func symbolShape(_ v: String) -> some ChartSymbolShape {
    switch v {
    case "square": return AnyChartSymbolShape(BasicChartSymbolShape.square)
    case "triangle": return AnyChartSymbolShape(BasicChartSymbolShape.triangle)
    case "diamond": return AnyChartSymbolShape(BasicChartSymbolShape.diamond)
    case "pentagon": return AnyChartSymbolShape(BasicChartSymbolShape.pentagon)
    case "plus": return AnyChartSymbolShape(BasicChartSymbolShape.plus)
    case "cross": return AnyChartSymbolShape(BasicChartSymbolShape.cross)
    case "asterisk": return AnyChartSymbolShape(BasicChartSymbolShape.asterisk)
    default: return AnyChartSymbolShape(BasicChartSymbolShape.circle)
    }
  }
}

/// Per-axis customization. SwiftUI's `chartXAxis(.hidden)` /
/// `.automatic` only toggles visibility. To honor every field on
/// `ChartAxisConfig` (label color & font size, grid line color,
/// optional grid lines, optional tick labels, value formatters) we
/// have to build custom `AxisMarks` content.
@available(iOS 17.0, *)
private extension View {
  @ViewBuilder
  func customizedXAxis(config: ChartAxisConfig) -> some View {
    if config.hidden {
      self.chartXAxis(.hidden)
    } else {
      self.chartXAxis {
        AxisMarks(values: .automatic) { axisValue in
          if config.gridLines {
            AxisGridLine()
              .foregroundStyle(
                config.gridColor.map { Color($0) }
                  ?? Color(UIColor.separator)
              )
          }
          AxisTick()
            .foregroundStyle(
              config.gridColor.map { Color($0) }
                ?? Color(UIColor.separator)
            )
          if config.tickLabels {
            AxisValueLabel {
              axisLabelText(for: axisValue, config: config)
                .font(.system(size: CGFloat(config.labelFontSize)))
                .foregroundColor(
                  config.labelColor.map { Color($0) }
                    ?? Color(UIColor.secondaryLabel)
                )
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  func customizedYAxis(config: ChartAxisConfig) -> some View {
    if config.hidden {
      self.chartYAxis(.hidden)
    } else {
      self.chartYAxis {
        AxisMarks(values: .automatic) { axisValue in
          if config.gridLines {
            AxisGridLine()
              .foregroundStyle(
                config.gridColor.map { Color($0) }
                  ?? Color(UIColor.separator)
              )
          }
          AxisTick()
            .foregroundStyle(
              config.gridColor.map { Color($0) }
                ?? Color(UIColor.separator)
            )
          if config.tickLabels {
            AxisValueLabel {
              axisLabelText(for: axisValue, config: config)
                .font(.system(size: CGFloat(config.labelFontSize)))
                .foregroundColor(
                  config.labelColor.map { Color($0) }
                    ?? Color(UIColor.secondaryLabel)
                )
            }
          }
        }
      }
    }
  }
}

/// Builds the Text view shown for a single axis tick. Routes through
/// the active `valueFormat` and applies prefix/suffix. String values
/// pass through unchanged; Double values get a NumberFormatter or a
/// FormatStyle depending on the requested format.
@available(iOS 17.0, *)
@ViewBuilder
private func axisLabelText(
  for axisValue: AxisValue,
  config: ChartAxisConfig
) -> Text {
  if let v = axisValue.as(Double.self) {
    Text(formatAxisValue(v, config: config))
  } else if let v = axisValue.as(Int.self) {
    Text(formatAxisValue(Double(v), config: config))
  } else if let s = axisValue.as(String.self) {
    Text("\(config.valuePrefix)\(s)\(config.valueSuffix)")
  } else {
    Text("")
  }
}

@available(iOS 17.0, *)
private func formatAxisValue(
  _ v: Double,
  config: ChartAxisConfig
) -> String {
  let core: String
  switch config.valueFormat {
  case "currency":
    core = v.formatted(
      .currency(code: config.currencyCode)
        .precision(.fractionLength(config.valueDecimals))
    )
  case "percent":
    // SwiftUI's `.percent` multiplies by 100. Callers should pass
    // 0.5 to render as "50%". For caller-supplied percentages
    // (already 0-100), use raw + suffix "%".
    core = v.formatted(
      .percent.precision(.fractionLength(config.valueDecimals))
    )
  case "abbreviated":
    core = v.formatted(
      .number.notation(.compactName)
        .precision(.fractionLength(config.valueDecimals))
    )
  case "decimal":
    core = v.formatted(
      .number.precision(.fractionLength(config.valueDecimals))
    )
  default:
    // "" / "raw" / anything else: plain number with the configured
    // decimal places. Keeps the existing v0.1/0.2 behavior.
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = config.valueDecimals
    formatter.maximumFractionDigits = config.valueDecimals
    core = formatter.string(from: NSNumber(value: v)) ?? String(v)
  }
  return "\(config.valuePrefix)\(core)\(config.valueSuffix)"
}

/// Conditional axis-scale modifiers. SwiftUI's `chartXScale(domain:)`
/// and `chartYScale(domain:)` require a non-optional `ClosedRange`,
/// so we can't just pass the optional result of `scaleDomain` —
/// these helpers apply the modifier only when the domain is set,
/// otherwise return the view unmodified.
@available(iOS 17.0, *)
private extension View {
  @ViewBuilder
  func conditionalChartXScale(domain: ClosedRange<Double>?) -> some View {
    if let domain {
      self.chartXScale(domain: domain)
    } else {
      self
    }
  }

  @ViewBuilder
  func conditionalChartYScale(domain: ClosedRange<Double>?) -> some View {
    if let domain {
      self.chartYScale(domain: domain)
    } else {
      self
    }
  }

  /// Trading-chart X mode: 0pt plot-dimension padding so the first
  /// and last data points sit flush against the chart's edges. Use
  /// when the axis is hidden and you want the line to bleed.
  @ViewBuilder
  func conditionalTightX(enabled: Bool) -> some View {
    if enabled {
      self.chartXScale(range: .plotDimension(padding: 0))
    } else {
      self
    }
  }

  /// Native horizontal scrolling. When `visibleCount > 0`, also caps
  /// how many X categories are visible at once. Keeps tooltip coords
  /// and chart selection gestures working — unlike wrapping in a
  /// RN `<ScrollView horizontal>`.
  @ViewBuilder
  func conditionalScrollable(enabled: Bool, visibleCount: Int) -> some View {
    if enabled {
      if visibleCount > 0 {
        self
          .chartScrollableAxes(.horizontal)
          .chartXVisibleDomain(length: visibleCount)
      } else {
        self.chartScrollableAxes(.horizontal)
      }
    } else {
      self
    }
  }

  /// Custom category → color mapping. Translates `[String: UIColor]`
  /// into SwiftUI's `chartForegroundStyleScale` so consumers can
  /// define their palette once at the chart level instead of setting
  /// `color` on every datum.
  @ViewBuilder
  func conditionalCategoryColors(
    _ mapping: [String: UIColor]
  ) -> some View {
    if mapping.isEmpty {
      self
    } else {
      // Stable iteration order so SwiftUI's diffing doesn't churn.
      let keys = mapping.keys.sorted()
      self.chartForegroundStyleScale(
        domain: keys,
        range: keys.map { key in
          Color(mapping[key] ?? UIColor.label)
        }
      )
    }
  }
}

/// Positions a callout above the active datum and clamps it inside
/// the plot frame so it never overflows the chart's bounds. Uses
/// `alignmentGuide` so the callout is anchored bottom-center on
/// (xAbs, yAbs - 12) — i.e. 12pt above the dot.
@available(iOS 17.0, *)
private struct CalloutPlacement: ViewModifier {
  let xAbs: CGFloat
  let yAbs: CGFloat
  let plot: CGRect

  func body(content: Content) -> some View {
    content
      .background(
        // Invisible probe to read the callout's own size so we can
        // clamp it to the plot edges.
        GeometryReader { geo in
          Color.clear.preference(
            key: CalloutSizeKey.self,
            value: geo.size
          )
        }
      )
      .modifier(CalloutPositioner(xAbs: xAbs, yAbs: yAbs, plot: plot))
  }
}

@available(iOS 17.0, *)
private struct CalloutSizeKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

@available(iOS 17.0, *)
private struct CalloutPositioner: ViewModifier {
  let xAbs: CGFloat
  let yAbs: CGFloat
  let plot: CGRect

  @State private var size: CGSize = .zero

  func body(content: Content) -> some View {
    let half = size.width / 2
    let clampedX = min(max(xAbs, plot.minX + half + 4), plot.maxX - half - 4)
    // Prefer above the dot; if too close to the top, drop below.
    let aboveY = yAbs - size.height / 2 - 14
    let belowY = yAbs + size.height / 2 + 14
    let y = aboveY < plot.minY + size.height / 2
      ? belowY
      : aboveY

    return content
      .onPreferenceChange(CalloutSizeKey.self) { size = $0 }
      .position(x: clampedX, y: y)
  }
}

/// Per-bar position adjustment. SwiftUI's default behavior with
/// multiple BarMarks at the same X is implementation-defined; this
/// extension makes the intent explicit:
///   - "stacked" → `positionAdjustment(.stacking)`
///   - "grouped" → `position(by: .value("Series", category))` so
///     bars sit side-by-side, one column per series. Falls back to
///     "auto" when no category is set.
///   - anything else → leave the mark alone.
@available(iOS 17.0, *)
private extension ChartContent {
  @ChartContentBuilder
  func conditionalBarPosition(
    kind: String,
    category: String?
  ) -> some ChartContent {
    switch kind {
    case "stacked":
      self.positionAdjustment(.stacking)
    case "grouped":
      if let cat = category, !cat.isEmpty {
        self.position(by: .value("Series", cat))
      } else {
        self
      }
    default:
      self
    }
  }
}

/// Type-erased wrapper for the various BasicChartSymbolShape values
/// so a `switch` can return a single concrete type.
@available(iOS 17.0, *)
private struct AnyChartSymbolShape: ChartSymbolShape {
  private let _path: (CGRect) -> Path
  let perceptualUnitRect: CGRect

  init<S: ChartSymbolShape>(_ shape: S) {
    self._path = { rect in shape.path(in: rect) }
    self.perceptualUnitRect = shape.perceptualUnitRect
  }

  func path(in rect: CGRect) -> Path { _path(rect) }
}
