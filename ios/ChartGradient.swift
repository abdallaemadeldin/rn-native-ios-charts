import ExpoModulesCore

/// One stop in a multi-stop gradient.
internal struct ChartGradientStop: Record {
  /// Position along the gradient axis, 0–1.
  @Field var offset: Double = 0
  @Field var color: UIColor?
  /// 0 = transparent, 1 = opaque. Multiplied with the stop's color alpha.
  @Field var opacity: Double = 1.0

  init() {}
}

/// Gradient fill applied to a mark's `foregroundStyle`. Two-stop
/// shorthand (`startOpacity` + `endOpacity`) is the common case; for
/// fancier multi-stop gradients use `stops`.
internal struct ChartGradient: Record {
  /// "linear" | "radial". Default linear.
  @Field var kind: String = "linear"
  /// Linear gradient start point in unit coords. Defaults to .top.
  @Field var startX: Double = 0.5
  @Field var startY: Double = 0
  /// Linear gradient end point in unit coords. Defaults to .bottom.
  @Field var endX: Double = 0.5
  @Field var endY: Double = 1
  /// Two-stop shorthand — used when `stops` is empty.
  @Field var startOpacity: Double = 0.35
  @Field var endOpacity: Double = 0.02
  /// Explicit stops. Overrides `startOpacity` / `endOpacity` when set.
  @Field var stops: [ChartGradientStop] = []

  init() {}
}
