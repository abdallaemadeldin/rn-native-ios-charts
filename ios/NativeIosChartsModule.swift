import ExpoModulesCore

/// Top-level Expo module registration. Exposes a single generic
/// `ChartView` that handles every SwiftUI Charts mark type — JS-side
/// convenience wrappers (`PieChart`, `LineChart`, `BarChart`, …) all
/// shape their props into the same `marks: [Mark]` config.
public class NativeIosChartsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("NativeIosCharts")

    View(ChartView.self) {
      Events("onSelect")

      Prop("marks") { (view: ChartView, marks: [ChartMark]) in
        view.props.marks = marks
      }
      Prop("xAxis") { (view: ChartView, axis: ChartAxisConfig) in
        view.props.xAxis = axis
      }
      Prop("yAxis") { (view: ChartView, axis: ChartAxisConfig) in
        view.props.yAxis = axis
      }
      Prop("legend") { (view: ChartView, legend: ChartLegendConfig) in
        view.props.legend = legend
      }
      Prop("centerLabel") { (view: ChartView, label: ChartCenterLabel) in
        view.props.centerLabel = label
      }
      Prop("tooltip") { (view: ChartView, config: ChartTooltipConfig) in
        view.props.tooltip = config
      }
      Prop("animate") { (view: ChartView, value: Bool) in
        view.props.animate = value
      }
    }
  }
}
