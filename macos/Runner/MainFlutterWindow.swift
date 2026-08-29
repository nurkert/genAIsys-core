import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  private let toolbarTopInset: CGFloat = 10
  private let toolbarHeight: CGFloat = 32
  private let trafficLightLeadingInset: CGFloat = 20
  private let trafficLightSpacing: CGFloat = 8
  private static let closeLeadingConstraintId =
    "genaisys.window.close.leading"
  private static let closeCenterYConstraintId =
    "genaisys.window.close.centerY"
  private static let miniLeadingConstraintId =
    "genaisys.window.mini.leading"
  private static let miniCenterYConstraintId =
    "genaisys.window.mini.centerY"
  private static let zoomLeadingConstraintId =
    "genaisys.window.zoom.leading"
  private static let zoomCenterYConstraintId =
    "genaisys.window.zoom.centerY"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.isRestorable = false

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      self.alignTrafficLightsWhenWindowReady(controller: controller, attempt: 0)
    }

    super.awakeFromNib()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(repositionTrafficLights),
      name: NSWindow.didResizeNotification,
      object: self
    )

    DispatchQueue.main.async { [weak self] in
      self?.repositionTrafficLights()
    }
  }

  private func alignTrafficLightsWhenWindowReady(
    controller: FlutterViewController,
    attempt: Int
  ) {
    let maxAttempts = 24
    if let window = controller.view.window {
      Self.applyOpaqueStartupBackground(for: window)
      window.isRestorable = false
      Self.alignTrafficLights(
        for: window,
        toolbarTopInset: toolbarTopInset,
        toolbarHeight: toolbarHeight,
        leadingInset: trafficLightLeadingInset,
        spacing: trafficLightSpacing
      )
      return
    }

    guard attempt < maxAttempts else {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
      guard let self else {
        return
      }
      self.alignTrafficLightsWhenWindowReady(controller: controller, attempt: attempt + 1)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func repositionTrafficLights() {
    Self.alignTrafficLights(
      for: self,
      toolbarTopInset: toolbarTopInset,
      toolbarHeight: toolbarHeight,
      leadingInset: trafficLightLeadingInset,
      spacing: trafficLightSpacing
    )
  }

  private static func alignTrafficLights(
    for window: NSWindow,
    toolbarTopInset: CGFloat,
    toolbarHeight: CGFloat,
    leadingInset: CGFloat,
    spacing: CGFloat
  ) {
    guard
      let close = window.standardWindowButton(.closeButton),
      let mini = window.standardWindowButton(.miniaturizeButton),
      let zoom = window.standardWindowButton(.zoomButton),
      let buttonContainer = close.superview
    else {
      return
    }

    let existingConstraintIds = Set(
      buttonContainer.constraints.compactMap { $0.identifier }
    )
    if existingConstraintIds.contains(closeLeadingConstraintId) {
      return
    }

    close.translatesAutoresizingMaskIntoConstraints = false
    mini.translatesAutoresizingMaskIntoConstraints = false
    zoom.translatesAutoresizingMaskIntoConstraints = false

    let targetCenterYFromTop = toolbarTopInset + (toolbarHeight / 2)

    let closeLeading = close.leadingAnchor.constraint(
      equalTo: buttonContainer.leadingAnchor,
      constant: leadingInset
    )
    closeLeading.identifier = .init(closeLeadingConstraintId)

    let closeCenterY = close.centerYAnchor.constraint(
      equalTo: buttonContainer.topAnchor,
      constant: targetCenterYFromTop
    )
    closeCenterY.identifier = .init(closeCenterYConstraintId)

    let miniLeading = mini.leadingAnchor.constraint(
      equalTo: close.trailingAnchor,
      constant: spacing
    )
    miniLeading.identifier = .init(miniLeadingConstraintId)

    let miniCenterY = mini.centerYAnchor.constraint(equalTo: close.centerYAnchor)
    miniCenterY.identifier = .init(miniCenterYConstraintId)

    let zoomLeading = zoom.leadingAnchor.constraint(
      equalTo: mini.trailingAnchor,
      constant: spacing
    )
    zoomLeading.identifier = .init(zoomLeadingConstraintId)

    let zoomCenterY = zoom.centerYAnchor.constraint(equalTo: close.centerYAnchor)
    zoomCenterY.identifier = .init(zoomCenterYConstraintId)

    NSLayoutConstraint.activate([
      closeLeading,
      closeCenterY,
      miniLeading,
      miniCenterY,
      zoomLeading,
      zoomCenterY,
    ])
  }

  private static func applyOpaqueStartupBackground(for window: NSWindow) {
    // Prevents black flash on newly created subwindows before the first
    // Flutter frame is rendered.
    window.isOpaque = true
    window.backgroundColor = NSColor(
      red: 0.95,
      green: 0.97,
      blue: 0.99,
      alpha: 1.0
    )
    window.contentView?.wantsLayer = true
    window.contentView?.layer?.backgroundColor = NSColor(
      red: 0.95,
      green: 0.97,
      blue: 0.99,
      alpha: 1.0
    ).cgColor
  }
}
