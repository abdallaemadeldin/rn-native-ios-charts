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
  /// Legacy boolean toggle. When `animation` is also set, `animation`
  /// wins; this stays for backwards compatibility with v0.x callers
  /// that passed `animate={false}` to skip animations.
  @Published var animate: Bool = true
  /// Full animation config. When `nil`, falls back to `animate` and
  /// the framework defaults (400ms easeInOut, no entrance).
  @Published var animation: ChartAnimationConfig = ChartAnimationConfig()
  /// Datum-anchored labels + shaded range bands overlayed on top of
  /// the marks. Renders in `chartOverlay`, beneath the tooltip.
  @Published var annotations: [ChartAnnotation] = []
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

  /// Increment from JS to imperatively clear any active selection
  /// (the cartesian scrubber's selectedX and/or the pie's
  /// selectedAngleY). Used by `chartRef.clearSelection()` so the
  /// parent screen can dismiss a sticky pie-slice selection on a
  /// tap outside the chart's host view. Default 0; the SwiftUI side
  /// only reacts to `.onChange`, not the initial value.
  @Published var clearSelectionToken: Int = 0

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
  /// Composite index of the currently-selected sector slice, derived
  /// from `selectedAngleY`. Held separately so the dim/scale
  /// modifiers can react synchronously and so the tap-same-slice
  /// toggle has a stable "previous" value to compare against.
  @State private var selectedSlice: SliceID?
  /// Entrance animation latch. Starts false on mount; flipped to
  /// true inside the first `onAppear` callback so SwiftUI animates
  /// the scaleEffect+opacity from initial to final values. Reused
  /// across re-renders — only the initial transition is animated.
  @State private var hasAppeared: Bool = false
  /// Local mirror of `props.marks`, driven explicitly via
  /// `withAnimation { renderedMarks = props.marks }` whenever the
  /// fingerprint changes. SwiftUI Charts doesn't reliably animate
  /// `SectorMark` angle/value changes when the data binding lives on
  /// an `@ObservedObject` — the framework keys its diff on the
  /// observation source, and `@Published`-driven updates skip the
  /// interpolator. Mirroring through `@State` + `withAnimation` is
  /// the canonical fix: it makes data changes a SwiftUI transaction
  /// the framework respects, which animates angles, colors and the
  /// fill style consistently regardless of how large the value
  /// delta is.
  @State private var renderedMarks: [ChartMark] = []

  /// Identifies a pie slice by its (markIndex, pointIndex) pair.
  /// Equatable so SwiftUI's implicit animations can interpolate on
  /// changes to `selectedSlice`.
  private struct SliceID: Equatable {
    let mark: Int
    let point: Int
  }

  var body: some View {
    // NOTE: previously this body wrapped the chart in a `ZStack`
    // with a `Color.clear.onTapGesture` backdrop to clear the
    // selection on "miss" taps (donut hole, chart corners).
    // Removed — that gesture competed with `chartAngleSelection`'s
    // slice-tap on pies: either it consumed the tap before the
    // chart saw it (no selection), or it fired right after the
    // chart set state (tooltip flashed and vanished). Cartesian
    // charts use long-press-drag so they were unaffected, but pies
    // were unusable. Dismiss paths still available:
    //   1. Tap the same slice (toggle, handled in `onChange`).
    //   2. Tap a different slice (selection switches).
    //   3. `chartRef.current?.clearSelection()` from JS.
    // A smarter geometry-aware backdrop is a future improvement.
    Group {
      Chart {
        // Iterates the @State mirror, not props.marks directly —
        // see `renderedMarks` for the why. State-lookup helpers
        // (`findActivePoint`, `selectedSliceData`, `emitSelect`)
        // still read `props.marks` so taps and tooltip resolution
        // always reflect the latest data, even mid-animation.
        ForEach(Array(renderedMarks.enumerated()), id: \.offset) { markIndex, mark in
          renderMark(mark, markIndex: markIndex)
        }
      }
      .chartLegend(legendVisibility)
      .customizedXAxis(config: props.xAxis)
      .customizedYAxis(config: props.yAxis)
      .conditionalChartXScale(domain: scaleDomain(props.xAxis))
      .conditionalChartYScale(
        domain: scaleDomain(props.yAxis),
        logarithmic: props.yAxis.scaleType == "log"
      )
      .conditionalTightX(enabled: props.tightX, xDomain: tightXDomain)
      .conditionalCategoryColors(props.categoryColors)
      .conditionalScrollable(
        enabled: props.scrollableX,
        visibleCount: props.visibleXCount
      )
      .chartBackground { proxy in
        centerLabelView(proxy: proxy)
      }
      // Selection modifiers are scoped to the mark types actually
      // present. Otherwise `chartXSelection` keeps firing during
      // long-press on a pie-only chart (because the long-press
      // recognizer is still tracking even though there's nothing
      // to resolve), flooding `onSelect` with `null`s. The
      // symmetric case — `chartAngleSelection` firing on cartesian
      // taps — is unlikely but cheap to guard against.
      .conditionalChartXSelection(
        value: $selectedX,
        enabled: hasCartesianMarks
      )
      .conditionalChartAngleSelection(
        value: $selectedAngleY,
        enabled: hasSectorMarks
      )
      .chartOverlay { proxy in
        // Annotations draw under the tooltip so the active callout
        // and dim never get obscured by commentary on the plot.
        ZStack {
          annotationsOverlay(proxy: proxy)
          tooltipOverlay(proxy: proxy)
        }
      }
      .onChange(of: selectedX) { _, _ in emitSelect() }
      .onChange(of: selectedAngleY) { _, newValue in
        // SwiftUI Charts' `chartAngleSelection` doesn't keep the
        // binding set after the user lifts off — it auto-resets to
        // nil when the tap ends. If we treated that nil-reset as a
        // real selection change we'd immediately clear
        // `selectedSlice` and the tooltip would flash on tap-down
        // and disappear on tap-up. Ignore nil resets here;
        // intentional clears (toggle re-tap, `clearSelectionState`,
        // the `clearSelectionToken` prop) write `selectedSlice = nil`
        // directly.
        guard let cum = newValue else { return }
        let next = resolveSlice(forAngleValue: cum)
        if let nextSlice = next, nextSlice == selectedSlice {
          // Tap-same-slice toggle — clear the visible highlight.
          // We don't touch `selectedAngleY` because the framework
          // will reset it on tap-up anyway, and writing it
          // ourselves would fire `onChange` again (caught and
          // ignored by the guard above, but still pointless).
          selectedSlice = nil
        } else {
          selectedSlice = next
        }
        emitSelect()
      }
      .onChange(of: props.clearSelectionToken) { _, _ in
        clearSelectionState()
      }
      // Drive the data-change animation explicitly through a
      // SwiftUI transaction. The `.onChange` fires whenever the
      // fingerprint differs from the previous render's; inside
      // `withAnimation`, every state read by the body that depends
      // on `renderedMarks` (sector angles, mark fills, scale) is
      // interpolated between old and new. This is more reliable
      // than `.animation(_, value:)` on an `@ObservedObject`-fed
      // chart, which sometimes no-ops on small value deltas or on
      // foreground-style changes wrapped in `AnyShapeStyle`.
      .onChange(of: marksFingerprint) { _, _ in
        if animationEnabled, let anim = dataChangeAnimation {
          withAnimation(anim) {
            renderedMarks = props.marks
          }
        } else {
          renderedMarks = props.marks
        }
      }
      // Animate the slice scale + dim independently of data-change
      // animation so taps feel snappier than the slower data ease.
      // The spring is hard-coded for selection feel; the data-
      // change animation runs through `withAnimation` above.
      .animation(
        .spring(response: 0.32, dampingFraction: 0.72),
        value: selectedSlice
      )
    }
    // Entrance animation. Starts collapsed (scale 0.96, fully
    // transparent) and animates to identity inside `onAppear`.
    // SwiftUI's implicit-animation system handles the transition —
    // we just flip the latch state inside `withAnimation`.
    .scaleEffect(entranceScale)
    .opacity(entranceOpacity)
    .onAppear {
      // Seed the local mirror before the first paint so the chart
      // doesn't flash empty during entrance. Subsequent updates
      // flow through the `onChange` above.
      if renderedMarks.isEmpty {
        renderedMarks = props.marks
      }
      guard !hasAppeared else { return }
      if props.animation.entrance && animationEnabled {
        withAnimation(entranceAnimation) {
          hasAppeared = true
        }
      } else {
        hasAppeared = true
      }
    }
  }

  // MARK: - Animation resolution

  /// True when any animation should run. `animation.enabled == false`
  /// or `animate == false` both kill everything.
  private var animationEnabled: Bool {
    props.animate && props.animation.enabled
  }

  /// SwiftUI `Animation` for data-change transitions (mark layout
  /// changes, new/removed data points). Returns nil when animations
  /// are globally disabled — `.animation(nil, value:)` is a no-op.
  private var dataChangeAnimation: Animation? {
    guard animationEnabled else { return nil }
    let secs = max(props.animation.duration / 1000.0, 0.05)
    switch props.animation.curve {
    case "easeIn": return .easeIn(duration: secs)
    case "easeOut": return .easeOut(duration: secs)
    case "linear": return .linear(duration: secs)
    case "spring":
      // Springs ignore duration. The defaults give a snappy-but-soft
      // feel that fits both pie data swaps and line refits.
      return .spring(response: 0.35, dampingFraction: 0.7)
    default:
      return .easeInOut(duration: secs)
    }
  }

  /// Animation used during the entrance transition. Always uses the
  /// configured curve, but caps the duration at 600ms so a slow
  /// data-change duration doesn't drag out the first paint.
  private var entranceAnimation: Animation {
    let secs = min(max(props.animation.duration / 1000.0, 0.15), 0.6)
    switch props.animation.curve {
    case "easeIn": return .easeIn(duration: secs)
    case "easeOut": return .easeOut(duration: secs)
    case "linear": return .linear(duration: secs)
    case "spring": return .spring(response: 0.42, dampingFraction: 0.78)
    default: return .easeOut(duration: secs)
    }
  }

  private var entranceScale: CGFloat {
    guard props.animation.entrance && animationEnabled else { return 1.0 }
    return hasAppeared ? 1.0 : 0.96
  }

  private var entranceOpacity: Double {
    guard props.animation.entrance && animationEnabled else { return 1.0 }
    return hasAppeared ? 1.0 : 0.0
  }

  /// Wipes both cartesian and pie selection state. Called from the
  /// in-chart miss backdrop tap, the `clearSelectionToken` prop
  /// observer (the JS-side `clearSelection()` ref), and the
  /// tap-same-slice toggle.
  private func clearSelectionState() {
    if selectedX != nil { selectedX = nil }
    if selectedAngleY != nil { selectedAngleY = nil }
    if selectedSlice != nil { selectedSlice = nil }
    emitSelect()
  }

  /// Maps the raw `selectedAngleY` binding value back to a
  /// `(markIndex, pointIndex)` pair. SwiftUI Charts'
  /// `chartAngleSelection` returns the **cumulative angle position**
  /// along the circumference — not the slice's literal `y` value —
  /// so we walk each sector mark's data, accumulate `y` values, and
  /// find the slice whose cumulative range contains the tap's
  /// position. The earlier `abs($0.y - ay) < 0.0001` exact-match
  /// approach only succeeded by coincidence (when the tap happened
  /// to land exactly at a slice's y-equivalent angle), which is why
  /// `onSelect` was emitting `null` for almost every real tap.
  private func resolveSlice(forAngleValue angle: Double?) -> SliceID? {
    guard let cum = angle else { return nil }
    for (mi, mark) in props.marks.enumerated() where mark.type == "sector" {
      var accumulator: Double = 0
      for (pi, point) in mark.data.enumerated() {
        let upper = accumulator + point.y
        // Use a closed range so cum == 0 maps to the first slice
        // and cum == total maps to the last. Successive boundaries
        // can technically match both adjacent slices; insertion
        // order resolves ties — the earlier slice wins, which is
        // fine because tapping exactly on a slice boundary is
        // essentially zero-probability.
        if cum >= accumulator && cum <= upper {
          return SliceID(mark: mi, point: pi)
        }
        accumulator = upper
      }
    }
    return nil
  }

  // MARK: - Annotations overlay

  /// Walks the `annotations` array and draws either a range band or
  /// a datum-anchored label per entry. Anchored via `ChartProxy` so
  /// the labels track the chart's plot frame even when the chart
  /// resizes. Drawn under the tooltip in the overlay ZStack.
  @ViewBuilder
  private func annotationsOverlay(proxy: ChartProxy) -> some View {
    if !props.annotations.isEmpty {
      GeometryReader { geo in
        if let plotFrame = proxy.plotFrame {
          let plot = geo[plotFrame]
          ForEach(Array(props.annotations.enumerated()), id: \.offset) { _, ann in
            annotationView(ann, proxy: proxy, plot: plot)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func annotationView(
    _ ann: ChartAnnotation,
    proxy: ChartProxy,
    plot: CGRect
  ) -> some View {
    if ann.xRange.count == 2 {
      rangeBandView(ann, proxy: proxy, plot: plot)
    } else if !ann.x.isEmpty {
      datumLabelView(ann, proxy: proxy, plot: plot)
    }
  }

  /// Shaded vertical band between `xRange[0]` and `xRange[1]`,
  /// optionally constrained to a Y range. Default fill is
  /// `Color(systemBlue).opacity(0.15)` — light enough not to swamp
  /// the marks but visible against most chart backgrounds. Optional
  /// `text` is placed at the `position` (top / bottom / inside).
  @ViewBuilder
  private func rangeBandView(
    _ ann: ChartAnnotation,
    proxy: ChartProxy,
    plot: CGRect
  ) -> some View {
    if let s = proxy.position(forX: ann.xRange[0]),
       let e = proxy.position(forX: ann.xRange[1]) {
      let bandStartX = min(s, e) + plot.minX
      let bandWidth = abs(e - s)
      // Compute the vertical extent in a pure helper so the
      // `@ViewBuilder` body stays expression-only — `var bandY = ...;
      // bandY = ...` inside the builder errors with "Type '()' cannot
      // conform to 'View'" because the assignment produces no view.
      let (bandY, bandHeight) = rangeBandVerticalExtent(ann, proxy: proxy, plot: plot)

      let fill = Color(ann.color ?? UIColor.systemBlue).opacity(0.15)
      let textColor = Color(ann.color ?? UIColor.label)

      ZStack {
        Rectangle()
          .fill(fill)
          .frame(width: bandWidth, height: bandHeight)
          .position(
            x: bandStartX + bandWidth / 2,
            y: bandY + bandHeight / 2
          )

        if !ann.text.isEmpty {
          // Same story for textY — pick the y-offset in a helper so
          // the conditional doesn't leak into the builder.
          let textY = rangeBandTextY(
            position: ann.position,
            bandY: bandY,
            bandHeight: bandHeight
          )
          Text(ann.text)
            .font(.system(
              size: CGFloat(ann.fontSize > 0 ? ann.fontSize : 11),
              weight: .medium
            ))
            .foregroundColor(textColor)
            .position(
              x: bandStartX + bandWidth / 2,
              y: textY
            )
        }
      }
    }
  }

  /// Pure helper: returns the (y, height) the band should occupy.
  /// Defaults to the full plot height; clamps to the data range
  /// when `yRange` is set and both endpoints fall inside the
  /// visible scale.
  private func rangeBandVerticalExtent(
    _ ann: ChartAnnotation,
    proxy: ChartProxy,
    plot: CGRect
  ) -> (y: CGFloat, height: CGFloat) {
    if ann.yRange.count == 2,
       let yLoPos = proxy.position(forY: ann.yRange[0]),
       let yHiPos = proxy.position(forY: ann.yRange[1]) {
      return (
        y: min(yLoPos, yHiPos) + plot.minY,
        height: max(abs(yHiPos - yLoPos), 1)
      )
    }
    return (y: plot.minY, height: plot.height)
  }

  /// Pure helper: y-offset for the band's text label.
  private func rangeBandTextY(
    position: String,
    bandY: CGFloat,
    bandHeight: CGFloat
  ) -> CGFloat {
    switch position {
    case "bottom":
      return bandY + bandHeight - 12
    case "inside":
      return bandY + bandHeight / 2
    default:
      return bandY + 12
    }
  }

  /// Floating text label anchored to a single x value. When
  /// `yRange[0]` is set, sits at that data y; otherwise floats near
  /// the top/bottom/middle of the plot per `position`.
  @ViewBuilder
  private func datumLabelView(
    _ ann: ChartAnnotation,
    proxy: ChartProxy,
    plot: CGRect
  ) -> some View {
    if !ann.text.isEmpty,
       let xRel = proxy.position(forX: ann.x) {
      let xAbs = xRel + plot.minX
      let yAbs: CGFloat = {
        if let first = ann.yRange.first,
           let yPos = proxy.position(forY: first) {
          return yPos + plot.minY
        }
        switch ann.position {
        case "bottom": return plot.maxY - 14
        case "inside": return plot.midY
        default: return plot.minY + 14
        }
      }()
      Text(ann.text)
        .font(.system(
          size: CGFloat(ann.fontSize > 0 ? ann.fontSize : 11),
          weight: .medium
        ))
        .foregroundColor(Color(ann.color ?? UIColor.label))
        .position(x: xAbs, y: yAbs)
    }
  }

  // MARK: - Tooltip overlay

  @ViewBuilder
  private func tooltipOverlay(proxy: ChartProxy) -> some View {
    if props.tooltip.enabled, let x = selectedX, let active = findActivePoint(x: x) {
      cartesianTooltipView(proxy: proxy, activeX: x, active: active)
    } else if props.tooltip.enabled, let slice = selectedSlice,
              let resolved = selectedSliceData(slice) {
      pieTooltipView(
        proxy: proxy,
        slice: slice,
        mark: resolved.mark,
        point: resolved.point
      )
    }
  }

  @ViewBuilder
  private func cartesianTooltipView(
    proxy: ChartProxy,
    activeX x: String,
    active: ActiveHit
  ) -> some View {
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

  /// Pie/donut tooltip: a short leader line from the selected
  /// slice's outer edge to a callout anchored just outside the
  /// chart's outer radius, at the slice's midpoint angle. The
  /// callout itself is clamped to the plot frame so it never spills
  /// past the host view.
  @ViewBuilder
  private func pieTooltipView(
    proxy: ChartProxy,
    slice: SliceID,
    mark: ChartMark,
    point: ChartDataPoint
  ) -> some View {
    GeometryReader { geo in
      if let plotFrame = proxy.plotFrame {
        let plot = geo[plotFrame]
        let total = mark.data.reduce(0.0) { $0 + $1.y }
        if total > 0 {
          // Cumulative angle up to the slice's midpoint. SwiftUI
          // Charts starts pies at 12 o'clock and sweeps clockwise,
          // so 0° is north and we subtract 90° before converting to
          // standard math radians. Sum lives in a pure helper so
          // the `for` loop stays out of the `@ViewBuilder` body —
          // result builders don't accept control-flow statements
          // whose bodies don't yield views.
          let before = cumulativeYBefore(slice: slice, in: mark)
          let midpointFraction = (before + point.y / 2.0) / total
          let angleRad = (midpointFraction * 360.0 - 90.0) * .pi / 180.0
          let center = CGPoint(x: plot.midX, y: plot.midY)
          let baseRatio = mark.outerRadius > 0 ? mark.outerRadius : 1.0
          // Outer edge of the slice. Match the same min-dim/2
          // approximation SwiftUI uses internally so the leader line
          // touches the painted slice edge.
          let radius = min(plot.width, plot.height) / 2.0 * baseRatio
          let leaderStart = CGPoint(
            x: center.x + cos(angleRad) * radius,
            y: center.y + sin(angleRad) * radius
          )
          let leaderEnd = CGPoint(
            x: center.x + cos(angleRad) * (radius + 14),
            y: center.y + sin(angleRad) * (radius + 14)
          )
          let calloutAnchor = CGPoint(
            x: center.x + cos(angleRad) * (radius + 28),
            y: center.y + sin(angleRad) * (radius + 28)
          )

          ZStack(alignment: .topLeading) {
            if props.tooltip.showRule {
              Path { path in
                path.move(to: leaderStart)
                path.addLine(to: leaderEnd)
              }
              .stroke(
                Color(activeColor(point) ?? UIColor.tertiaryLabel),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
              )
            }
            calloutView(point: point)
              .fixedSize()
              .modifier(PieCalloutPlacement(
                anchor: calloutAnchor,
                plot: plot
              ))
          }
        }
      }
    }
  }

  /// True when at least one mark in `props.marks` is a cartesian
  /// type (bar / line / area / point / rectangle). Used to gate
  /// `chartXSelection` — without this gate, long-pressing on a
  /// pie-only chart triggers the cartesian scrubber and floods
  /// `onSelect` with `null` callbacks.
  private var hasCartesianMarks: Bool {
    props.marks.contains { mark in
      switch mark.type {
      case "bar", "line", "area", "point", "rectangle":
        return true
      default:
        return false
      }
    }
  }

  /// True when at least one mark is a sector (pie / donut). Symmetric
  /// gate for `chartAngleSelection`.
  private var hasSectorMarks: Bool {
    props.marks.contains { $0.type == "sector" }
  }

  /// Sum of `y` values for slices BEFORE the selected one, used to
  /// compute the cumulative-fraction angle that locates the slice's
  /// midpoint. Pure helper extracted from `pieTooltipView` so the
  /// `for` loop stays out of the `@ViewBuilder` body.
  private func cumulativeYBefore(
    slice: SliceID,
    in mark: ChartMark
  ) -> Double {
    var total = 0.0
    let upper = min(slice.point, mark.data.count)
    for i in 0..<upper {
      total += mark.data[i].y
    }
    return total
  }

  /// Looks up the (mark, point) referenced by a `SliceID`, returning
  /// nil if the indices have drifted out of range (e.g. after a
  /// data swap raced ahead of the selection state). Mirrors the
  /// bounds checks scattered through `emitSelect` and the overlay.
  private func selectedSliceData(
    _ slice: SliceID
  ) -> (mark: ChartMark, point: ChartDataPoint)? {
    guard slice.mark >= 0, slice.mark < props.marks.count else { return nil }
    let mark = props.marks[slice.mark]
    guard mark.type == "sector" else { return nil }
    guard slice.point >= 0, slice.point < mark.data.count else { return nil }
    return (mark, mark.data[slice.point])
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
        Text(formatTooltipX(x))
          .font(.system(size: 11))
          .foregroundColor(fg.opacity(0.6))
          .padding(.bottom, 2)
      }
      ForEach(Array(hits.enumerated()), id: \.offset) { _, hit in
        HStack(spacing: 6) {
          Circle()
            .fill(Color(activeMarkColor(hit) ?? UIColor.label))
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
        Text(formatTooltipX(point.x))
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

  /// All cartesian datums at `x`, one per series. Walks **every**
  /// matching point in each mark (not just the first), then
  /// dedupes by category. This covers two layouts that look
  /// different at the JS level but should produce the same
  /// tooltip:
  ///   - `<LineChart series>` → one mark per series, each with its
  ///     own category and one matching point per x.
  ///   - `<BarChart data={[{x, category}, ...]} position="stacked|grouped">`
  ///     → one mark with multiple matching points per x, each
  ///     carrying a different category.
  ///
  /// Two passes (non-area marks first, then area) so when a series
  /// is rendered as a paired area+line, the line wins for color
  /// resolution. Sector and rule marks are skipped — neither has a
  /// meaningful y at x.
  private func findAllActivePoints(x: String) -> [ActiveHit] {
    var hits: [ActiveHit] = []
    var seenCategories = Set<String>()

    func key(forPoint p: ChartDataPoint, markIndex: Int, pointIndex: Int) -> String {
      // Prefer category; if absent fall back to (markIndex,
      // pointIndex) so two categoryless points at the same x in
      // the same mark each get a row.
      if let cat = p.category, !cat.isEmpty { return cat }
      return "__mark_\(markIndex)_\(pointIndex)"
    }

    for (mi, mark) in props.marks.enumerated()
    where mark.type != "rule"
      && mark.type != "sector"
      && mark.type != "area" {
      for (pi, point) in mark.data.enumerated() where point.x == x {
        let k = key(forPoint: point, markIndex: mi, pointIndex: pi)
        if seenCategories.insert(k).inserted {
          hits.append(
            ActiveHit(point: point, markIndex: mi, pointIndex: pi)
          )
        }
      }
    }
    for (mi, mark) in props.marks.enumerated() where mark.type == "area" {
      for (pi, point) in mark.data.enumerated() where point.x == x {
        let k = key(forPoint: point, markIndex: mi, pointIndex: pi)
        if seenCategories.insert(k).inserted {
          hits.append(
            ActiveHit(point: point, markIndex: mi, pointIndex: pi)
          )
        }
      }
    }
    return hits
  }

  /// Color for a tooltip dot in the single-point/pie path. Walks
  /// every mark that contains the same `x` and returns the first
  /// matching mark's color — wrong for the multi-series tooltip
  /// where every mark has a datum at the active x, so use
  /// `activeMarkColor(_:)` instead in that path.
  private func activeColor(_ point: ChartDataPoint) -> UIColor? {
    if let c = point.color { return c }
    for mark in props.marks {
      if mark.data.contains(where: { $0.x == point.x }), let mc = mark.color {
        return mc
      }
    }
    return nil
  }

  /// Color for a tooltip dot in the multi-series row path. Uses the
  /// `markIndex` of the active hit so each series shows its own
  /// stroke color, instead of the first-match-wins behavior of
  /// `activeColor(_:)` (which collapsed every row to the first
  /// mark's color when every mark had data at the active x).
  /// Falls back through: per-point color → mark color →
  /// `categoryColors[category]` → nil.
  private func activeMarkColor(_ hit: ActiveHit) -> UIColor? {
    if let c = hit.point.color { return c }
    guard hit.markIndex >= 0, hit.markIndex < props.marks.count else {
      return nil
    }
    let mark = props.marks[hit.markIndex]
    if let mc = mark.color { return mc }
    if let cat = hit.point.category, let cc = props.categoryColors[cat] {
      return cc
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

  /// Formats the tooltip's X label. When the X axis is configured
  /// as a date axis (`xAxis.valueFormat == "date"`), parses the
  /// stored ISO string and renders it with `xAxis.dateFormat`. Falls
  /// back to the raw string for categorical / non-date axes.
  private func formatTooltipX(_ raw: String) -> String {
    if props.xAxis.valueFormat == "date",
       let date = parseISODateString(raw) {
      let df = DateFormatter()
      df.dateFormat = props.xAxis.dateFormat
      return df.string(from: date)
    }
    return raw
  }

  /// Dispatches the JS `onSelect` event with the currently-selected
  /// point (or `nil` if cleared). For pie marks, reads
  /// `selectedSlice` (our persistent mirror) rather than
  /// `selectedAngleY` (the framework's transient binding that
  /// resets on tap-up). Using the binding directly would cause the
  /// toggle-off emit to read a still-active angle value mid-gesture
  /// and emit the previously-selected slice instead of `null`.
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
    if let slice = selectedSlice,
       slice.mark < props.marks.count,
       slice.point < props.marks[slice.mark].data.count {
      let p = props.marks[slice.mark].data[slice.point]
      props.onSelect?([
        "x": p.x,
        "y": p.y,
        "markIndex": slice.mark,
        "pointIndex": slice.point,
      ])
      return
    }
    props.onSelect?(nil)
  }

  // MARK: - Mark dispatch

  @ChartContentBuilder
  private func renderMark(_ mark: ChartMark, markIndex: Int) -> some ChartContent {
    // Identity is x + category (stable across data updates that
    // change y values), falling back to the index when the x is
    // empty. Index-only identity caused stale slice positions when
    // tabs swapped the data prop with different x labels — SwiftUI
    // diffed positions, not slices, and missed the redraw.
    ForEach(Array(mark.data.enumerated()), id: \.element.identityKey) { idx, point in
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
      barMark(mark: mark, point: point, markIndex: markIndex)
    case "line":
      lineMark(mark: mark, point: point, markIndex: markIndex)
      if mark.showPoints {
        pointMark(mark: mark, point: point, markIndex: markIndex)
      }
    case "area":
      areaMark(mark: mark, point: point, markIndex: markIndex)
    case "point":
      pointMark(mark: mark, point: point, markIndex: markIndex)
    case "rectangle":
      rectangleMark(mark: mark, point: point, markIndex: markIndex)
    case "rule":
      ruleMark(mark: mark, point: point)
    case "sector":
      sectorMark(
        mark: mark, point: point,
        markIndex: markIndex, pointIndex: pointIndex
      )
    default:
      lineMark(mark: mark, point: point, markIndex: markIndex)
    }
  }

  // MARK: - Cartesian dim-on-select

  /// Effective opacity for a cartesian mark, factoring in
  /// `animation.cartesianDimOnSelect`. When the tooltip scrubber is
  /// active and the feature is enabled, marks that don't own the
  /// active datum are reduced to `tooltip.dimOpacity`. Rule marks
  /// stay full-strength — they're reference lines, not series.
  /// Returns `mark.opacity` unchanged when the feature is off or
  /// there's no active selection.
  private func cartesianEffectiveOpacity(
    mark: ChartMark,
    markIndex: Int
  ) -> Double {
    guard props.tooltip.enabled,
          props.animation.cartesianDimOnSelect,
          let x = selectedX,
          let activeHit = findActivePoint(x: x) else {
      return mark.opacity
    }
    if markIndex == activeHit.markIndex || mark.type == "rule" {
      return mark.opacity
    }
    return mark.opacity * props.tooltip.dimOpacity
  }

  // MARK: - Individual marks

  @ChartContentBuilder
  private func barMark(
    mark: ChartMark,
    point: ChartDataPoint,
    markIndex: Int
  ) -> some ChartContent {
    let opacity = cartesianEffectiveOpacity(mark: mark, markIndex: markIndex)
    // When a point has a category AND no explicit color override is
    // set, we let `chartForegroundStyleScale` (driven by the
    // `categoryColors` prop) resolve the fill via
    // `.foregroundStyle(by: .value("Series", category))`. Otherwise
    // we apply the static `resolveFill` style. The two paths are
    // mutually exclusive — applying both on the same `BarMark`
    // makes SwiftUI Charts ignore the by-value form and keep the
    // static color, which is why stacked bars rendered as the
    // accent color even after the earlier "add series style on
    // top" attempt.
    let useSeriesStyle = point.color == nil
      && mark.color == nil
      && mark.gradient == nil
      && (point.category?.isEmpty == false)
    // Horizontal bars swap X/Y so long-tail labels read nicely on
    // a vertical axis (Top-N pattern). Inside each orientation we
    // branch on `useSeriesStyle` to apply exactly one of the two
    // mutually exclusive foreground-style paths.
    if mark.horizontal {
      if useSeriesStyle, let cat = point.category {
        BarMark(
          x: .value("X", point.y),
          y: .value("Y", point.x),
          height: mark.barWidth > 0 ? .fixed(mark.barWidth) : .automatic
        )
        .cornerRadius(mark.cornerRadius)
        .foregroundStyle(by: .value("Series", cat))
        .opacity(opacity)
        .conditionalBarPosition(kind: mark.position, category: cat)
      } else {
        BarMark(
          x: .value("X", point.y),
          y: .value("Y", point.x),
          height: mark.barWidth > 0 ? .fixed(mark.barWidth) : .automatic
        )
        .cornerRadius(mark.cornerRadius)
        .foregroundStyle(resolveFill(mark: mark, point: point))
        .opacity(opacity)
        .conditionalBarPosition(
          kind: mark.position,
          category: point.category
        )
      }
    } else {
      if useSeriesStyle, let cat = point.category {
        BarMark(
          x: .value("X", point.x),
          y: .value("Y", point.y),
          width: mark.barWidth > 0 ? .fixed(mark.barWidth) : .automatic
        )
        .cornerRadius(mark.cornerRadius)
        .foregroundStyle(by: .value("Series", cat))
        .opacity(opacity)
        .conditionalBarPosition(kind: mark.position, category: cat)
      } else {
        BarMark(
          x: .value("X", point.x),
          y: .value("Y", point.y),
          width: mark.barWidth > 0 ? .fixed(mark.barWidth) : .automatic
        )
        .cornerRadius(mark.cornerRadius)
        .foregroundStyle(resolveFill(mark: mark, point: point))
        .opacity(opacity)
        .conditionalBarPosition(
          kind: mark.position,
          category: point.category
        )
      }
    }
  }

  @ChartContentBuilder
  private func lineMark(
    mark: ChartMark,
    point: ChartDataPoint,
    markIndex: Int
  ) -> some ChartContent {
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
    .opacity(cartesianEffectiveOpacity(mark: mark, markIndex: markIndex))
  }

  @ChartContentBuilder
  private func areaMark(
    mark: ChartMark,
    point: ChartDataPoint,
    markIndex: Int
  ) -> some ChartContent {
    AreaMark(
      x: .value("X", point.x),
      y: .value("Y", point.y),
      series: .value("Series", point.category ?? "default")
    )
    .interpolationMethod(interpolationMethod(mark.interpolation))
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(cartesianEffectiveOpacity(mark: mark, markIndex: markIndex))
  }

  @ChartContentBuilder
  private func pointMark(
    mark: ChartMark,
    point: ChartDataPoint,
    markIndex: Int
  ) -> some ChartContent {
    PointMark(
      x: .value("X", point.x),
      y: .value("Y", point.y)
    )
    .symbol(symbolShape(mark.symbol))
    .symbolSize(mark.symbolSize)
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(cartesianEffectiveOpacity(mark: mark, markIndex: markIndex))
  }

  @ChartContentBuilder
  private func rectangleMark(
    mark: ChartMark,
    point: ChartDataPoint,
    markIndex: Int
  ) -> some ChartContent {
    RectangleMark(
      x: .value("X", point.x),
      yStart: .value("Y", point.y),
      yEnd: .value("YEnd", point.yEnd ?? point.y)
    )
    .cornerRadius(mark.cornerRadius)
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(cartesianEffectiveOpacity(mark: mark, markIndex: markIndex))
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
  private func sectorMark(
    mark: ChartMark,
    point: ChartDataPoint,
    markIndex: Int,
    pointIndex: Int
  ) -> some ChartContent {
    let isSelected = selectedSlice == SliceID(mark: markIndex, point: pointIndex)
    // Dim + slice-scale engage whenever there's a selected slice,
    // regardless of `tooltip.enabled`. The latter only controls the
    // leader-line + callout overlay (see `tooltipOverlay`). This lets
    // callers that drive their own selection UI via `onSelect` (e.g.
    // a center-label that updates on tap) still get the standard
    // "selected slice pops, others fade" visual feedback without
    // having to opt into the built-in callout. Matches the docs on
    // `TooltipConfig.dimOpacity` which never mentioned a gate.
    let highlightActive = selectedSlice != nil
    // Base radius the caller asked for. `.inset(0)` and `.ratio(1.0)`
    // resolve to the same geometry when the plot's frame is square,
    // so normalising to a ratio here lets us interpolate cleanly
    // between selected (full) and unselected (scaled down) values.
    let baseOuter = mark.outerRadius > 0 ? mark.outerRadius : 1.0
    // When the highlight is active, shrink unselected slices by the
    // configured scale factor so the selected one appears to bump
    // outward. The selected slice keeps its full base radius —
    // shrinking the others is visually identical to scaling up the
    // selected one but doesn't require headroom past ratio 1.0.
    let effectiveOuter: Double = {
      guard highlightActive else { return baseOuter }
      if isSelected { return baseOuter }
      let inverseScale = 1.0 / max(props.tooltip.sliceScale, 1.0001)
      return baseOuter * inverseScale
    }()
    let effectiveOpacity: Double = {
      guard highlightActive else { return mark.opacity }
      return mark.opacity * (isSelected ? 1.0 : props.tooltip.dimOpacity)
    }()
    SectorMark(
      angle: .value("Value", point.y),
      innerRadius: .ratio(mark.innerRadius),
      outerRadius: .ratio(effectiveOuter),
      angularInset: mark.angularInset
    )
    .cornerRadius(mark.cornerRadius)
    .foregroundStyle(resolveFill(mark: mark, point: point))
    .opacity(effectiveOpacity)
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

  // Trigger for the `withAnimation { renderedMarks = props.marks }`
  // `onChange` reaction. Includes x + category + y + color so the
  // animation fires on every meaningful data change — label swaps
  // (pie tab switch), value updates, AND palette changes. The
  // `description` of UIColor is stable enough to detect re-themes
  // without parsing RGBA.
  private var marksFingerprint: [String] {
    props.marks.flatMap { m in
      m.data.map { p in
        let colorTag = p.color.map { String(describing: $0) } ?? ""
        let markColorTag = m.color.map { String(describing: $0) } ?? ""
        return "\(p.x)|\(p.category ?? "")|\(p.y)|\(colorTag)|\(markColorTag)"
      }
    }
  }

  /// Ordered, unique X values across every cartesian mark. Used to
  /// pin the X scale's domain when `tightX` is enabled so the first
  /// and last categorical values map to the literal left and right
  /// edges of the plot (no half-cell insets).
  ///
  /// We walk marks in insertion order and skip duplicates with a
  /// Set, so the resulting array preserves the data's natural left-
  /// to-right ordering even when multiple series share X values.
  private var tightXDomain: [String] {
    var seen = Set<String>()
    var out: [String] = []
    for mark in props.marks
      where mark.type != "sector" && mark.type != "rule" {
      for point in mark.data {
        if seen.insert(point.x).inserted {
          out.append(point.x)
        }
      }
    }
    return out
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
/// FormatStyle depending on the requested format. Returns a single
/// `Text` (not `@ViewBuilder` content) so the caller can apply
/// `.font` and `.foregroundColor` directly to it.
@available(iOS 17.0, *)
private func axisLabelText(
  for axisValue: AxisValue,
  config: ChartAxisConfig
) -> Text {
  return Text(axisLabelString(for: axisValue, config: config))
}

@available(iOS 17.0, *)
private func axisLabelString(
  for axisValue: AxisValue,
  config: ChartAxisConfig
) -> String {
  if let v = axisValue.as(Double.self) {
    return formatAxisValue(v, config: config)
  }
  if let v = axisValue.as(Int.self) {
    return formatAxisValue(Double(v), config: config)
  }
  if let s = axisValue.as(String.self) {
    // Date format support — parse the ISO-8601 string the JS side
    // wrote into `x` and reformat it per the axis config. Lets
    // callers pass `Date` objects with a clean `xAxis: { valueFormat:
    // "date", dateFormat: "MMM yy" }` config and get nicely formatted
    // ticks without exposing date semantics through every layer.
    if config.valueFormat == "date" {
      if let date = parseISODateString(s) {
        let df = DateFormatter()
        df.dateFormat = config.dateFormat
        return "\(config.valuePrefix)\(df.string(from: date))\(config.valueSuffix)"
      }
    }
    return "\(config.valuePrefix)\(s)\(config.valueSuffix)"
  }
  return ""
}

/// Parses the ISO-8601 strings that `Chart.tsx` writes for `Date`
/// inputs. Tries the most common variant first (with fractional
/// seconds, since `Date.toISOString()` emits those) and falls back
/// to no-fraction ISO for inputs that came from other producers.
@available(iOS 17.0, *)
private func parseISODateString(_ s: String) -> Date? {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let d = f.date(from: s) { return d }
  let basic = ISO8601DateFormatter()
  basic.formatOptions = [.withInternetDateTime]
  return basic.date(from: s)
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

/// Conditional selection modifiers. `chartXSelection` and
/// `chartAngleSelection` are always-on when applied — they install
/// gesture recognizers that fire even when the bound state never
/// resolves to anything useful (e.g., long-pressing a pie-only
/// chart triggers `chartXSelection`'s drag tracking continuously,
/// because the recognizer doesn't know the chart has no cartesian
/// marks). Gating them on the mark types that need them keeps
/// `onSelect` quiet for irrelevant gestures.
@available(iOS 17.0, *)
private extension View {
  @ViewBuilder
  func conditionalChartXSelection(
    value: Binding<String?>,
    enabled: Bool
  ) -> some View {
    if enabled {
      self.chartXSelection(value: value)
    } else {
      self
    }
  }

  @ViewBuilder
  func conditionalChartAngleSelection(
    value: Binding<Double?>,
    enabled: Bool
  ) -> some View {
    if enabled {
      self.chartAngleSelection(value: value)
    } else {
      self
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
  func conditionalChartYScale(
    domain: ClosedRange<Double>?,
    logarithmic: Bool = false
  ) -> some View {
    switch (domain, logarithmic) {
    case (let d?, true):
      // Log + explicit domain. SwiftUI requires the domain to be
      // strictly positive when type is `.log` — caller is
      // responsible for clamping; we just forward the values.
      self.chartYScale(domain: d, type: .log)
    case (let d?, false):
      self.chartYScale(domain: d)
    case (nil, true):
      self.chartYScale(type: .log)
    case (nil, false):
      self
    }
  }

  /// Trading-chart X mode. Three coordinated tricks make the line /
  /// area / bars reach both edges of the chart frame regardless of
  /// data density:
  ///
  /// 1. **Explicit categorical domain** — SwiftUI positions
  ///    categorical values at the CENTER of evenly-sized cells by
  ///    default (leaves a half-cell gap on each end, brutal with
  ///    few points). Passing the X strings as `domain:` pins the
  ///    first value to pixel 0 and the last to pixel-max.
  ///
  /// 2. **`.plotDimension(startPadding: 0, endPadding: 0)`** —
  ///    zeros out the scale's outer padding within the plot area.
  ///
  /// 3. **`chartPlotStyle { $0.frame(maxWidth: .infinity,
  ///    maxHeight: .infinity) }`** — forces the plot area itself to
  ///    fill the chart's full frame, in case SwiftUI's hidden axes
  ///    still reserve any space.
  ///
  /// All three together give the Robinhood / Apple Stocks look
  /// where the chart's content truly spans edge-to-edge.
  @ViewBuilder
  func conditionalTightX(
    enabled: Bool,
    xDomain: [String]
  ) -> some View {
    if enabled && !xDomain.isEmpty {
      self
        .chartXScale(
          domain: xDomain,
          range: .plotDimension(startPadding: 0, endPadding: 0)
        )
        .chartPlotStyle { plot in
          plot.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    } else if enabled {
      // No data yet — apply just the range + plot expansion so the
      // chart doesn't crash; once data arrives a re-render will set
      // the categorical domain.
      self
        .chartXScale(
          range: .plotDimension(startPadding: 0, endPadding: 0)
        )
        .chartPlotStyle { plot in
          plot.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

/// Pie/donut callout placement. Anchors the callout at the slice's
/// midpoint-projected screen position and clamps both X and Y so
/// the bubble never spills past the plot frame. Unlike the
/// cartesian `CalloutPlacement`, there's no "prefer above" bias —
/// the callout sits exactly where the slice points, which is the
/// most natural read for a pie.
@available(iOS 17.0, *)
private struct PieCalloutPlacement: ViewModifier {
  let anchor: CGPoint
  let plot: CGRect

  @State private var size: CGSize = .zero

  func body(content: Content) -> some View {
    let halfW = size.width / 2
    let halfH = size.height / 2
    let clampedX = min(
      max(anchor.x, plot.minX + halfW + 4),
      plot.maxX - halfW - 4
    )
    let clampedY = min(
      max(anchor.y, plot.minY + halfH + 4),
      plot.maxY - halfH - 4
    )
    return content
      .background(
        GeometryReader { geo in
          Color.clear.preference(
            key: CalloutSizeKey.self,
            value: geo.size
          )
        }
      )
      .onPreferenceChange(CalloutSizeKey.self) { size = $0 }
      .position(x: clampedX, y: clampedY)
  }
}

/// Per-bar position adjustment. SwiftUI Charts already stacks
/// multiple `BarMark`s that share an X value by default — that's
/// the framework's built-in behavior, no modifier needed. To opt
/// OUT of stacking and lay bars side-by-side, we add
/// `.position(by: .value("Series", category))`.
///
/// So this helper:
///   - "stacked" / "auto" / anything else → leave the mark alone
///     (stacking is the default)
///   - "grouped" → apply `position(by:)` using the point's
///     `category`. Falls back to no-op if `category` is missing.
@available(iOS 17.0, *)
private extension ChartContent {
  @ChartContentBuilder
  func conditionalBarPosition(
    kind: String,
    category: String?
  ) -> some ChartContent {
    if kind == "grouped", let cat = category, !cat.isEmpty {
      self.position(by: .value("Series", cat))
    } else {
      self
    }
  }

  /// Attaches `.foregroundStyle(by: .value("Series", category))`
  /// so the chart's `chartForegroundStyleScale` (driven by the
  /// `categoryColors` prop) resolves the bar's fill. Without this
  /// modifier, stacked bars don't declare a series identity and
  /// the scale silently doesn't apply, leaving every bar at the
  /// accent color. Grouped bars get this implicitly through
  /// `.position(by:)` so it's redundant there, but harmless.
  /// Skipped entirely when a static `color` is set on the mark or
  /// point, so single-series bars (e.g., a horizontal Top-N with
  /// `color={blue}`) keep their explicit color.
  @ChartContentBuilder
  func conditionalBarSeriesStyle(
    category: String?,
    enabled: Bool
  ) -> some ChartContent {
    if enabled, let cat = category, !cat.isEmpty {
      self.foregroundStyle(by: .value("Series", cat))
    } else {
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
