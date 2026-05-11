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
    .chartXAxis(props.xAxis.hidden ? .hidden : .automatic)
    .chartYAxis(props.yAxis.hidden ? .hidden : .automatic)
    .conditionalChartXScale(domain: scaleDomain(props.xAxis))
    .conditionalChartYScale(domain: scaleDomain(props.yAxis))
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
            let yAbs: CGFloat? = proxy.position(forY: active.y).map {
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
                  .fill(Color(activeColor(active) ?? UIColor.label))
                  .frame(width: 10, height: 10)
                  .overlay(
                    Circle()
                      .stroke(Color(props.tooltip.backgroundColor ?? UIColor.systemBackground), lineWidth: 2)
                  )
                  .position(x: xAbs, y: y)
              }
              calloutView(point: active)
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

  private func findActivePoint(x: String) -> ChartDataPoint? {
    // Prefer non-rule, non-sector marks (those have meaningful Y at X).
    for mark in props.marks where mark.type != "rule" && mark.type != "sector" {
      if let hit = mark.data.first(where: { $0.x == x }) {
        return hit
      }
    }
    // Fallback: scan everything.
    for mark in props.marks {
      if let hit = mark.data.first(where: { $0.x == x }) {
        return hit
      }
    }
    return nil
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
  /// point (or `nil` if cleared).
  private func emitSelect() {
    if let x = selectedX, let p = findActivePoint(x: x) {
      props.onSelect?([
        "x": p.x,
        "y": p.y,
      ])
      return
    }
    if let ay = selectedAngleY,
       let p = props.marks.first(where: { $0.type == "sector" })?
         .data.first(where: { abs($0.y - ay) < 0.0001 }) {
      props.onSelect?([
        "x": p.x,
        "y": p.y,
      ])
      return
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
    BarMark(
      x: .value("X", point.x),
      y: .value("Y", point.y),
      width: mark.barWidth > 0 ? .fixed(mark.barWidth) : .automatic
    )
    .cornerRadius(mark.cornerRadius)
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(mark.opacity)
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
