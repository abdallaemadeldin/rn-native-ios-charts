import SwiftUI
import Charts
import ExpoModulesCore

internal final class ChartViewProps: ObservableObject {
  @Published var marks: [ChartMark] = []
  @Published var xAxis: ChartAxisConfig = ChartAxisConfig()
  @Published var yAxis: ChartAxisConfig = ChartAxisConfig()
  @Published var legend: ChartLegendConfig = ChartLegendConfig()
  @Published var centerLabel: ChartCenterLabel = ChartCenterLabel()
  @Published var animate: Bool = true
}

/// One ExpoView that hosts a SwiftUI Chart, configurable to render
/// any combination of bar / line / area / point / rectangle / rule /
/// sector marks. Designed to be the single native primitive every
/// chart type ships through.
internal final class ChartView: ExpoView {
  let props = ChartViewProps()
  private let hostingController: UIHostingController<ChartContent>

  required init(appContext: AppContext? = nil) {
    let view = ChartContent(props: props)
    self.hostingController = UIHostingController(rootView: view)
    super.init(appContext: appContext)
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

private struct ChartContent: View {
  @ObservedObject var props: ChartViewProps

  var body: some View {
    Chart {
      ForEach(Array(props.marks.enumerated()), id: \.offset) { markIndex, mark in
        renderMark(mark, markIndex: markIndex)
      }
    }
    .chartLegend(legendVisibility)
    .chartXAxis(props.xAxis.hidden ? .hidden : .automatic)
    .chartYAxis(props.yAxis.hidden ? .hidden : .automatic)
    .chartXScale(domain: scaleDomain(props.xAxis))
    .chartYScale(domain: scaleDomain(props.yAxis))
    .chartBackground { proxy in
      centerLabelView(proxy: proxy)
    }
    .animation(
      props.animate ? .easeInOut(duration: 0.4) : nil,
      value: marksFingerprint
    )
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

/// Type-erased wrapper for the various BasicChartSymbolShape values
/// so a `switch` can return a single concrete type.
private struct AnyChartSymbolShape: ChartSymbolShape {
  private let _path: (CGRect) -> Path
  let perceptualUnitRect: CGRect

  init<S: ChartSymbolShape>(_ shape: S) {
    self._path = { rect in shape.path(in: rect) }
    self.perceptualUnitRect = shape.perceptualUnitRect
  }

  func path(in rect: CGRect) -> Path { _path(rect) }
}
