#if os(macOS)
import AppKit
import Combine
import SwiftUI

/// Reports the exact AppKit window hosting a SwiftUI hierarchy.
/// This avoids racing `NSApplication.shared.windows` during app launch.
struct HostingWindowReader: NSViewRepresentable {
    let onWindowChange: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> HostingWindowProbe {
        HostingWindowProbe(onWindowChange: onWindowChange)
    }

    func updateNSView(_ nsView: HostingWindowProbe, context: Context) {
        nsView.onWindowChange = onWindowChange
        nsView.reportWindowIfNeeded()
    }
}

final class HostingWindowProbe: NSView {
    var onWindowChange: @MainActor (NSWindow?) -> Void
    private weak var reportedWindow: NSWindow?

    init(onWindowChange: @escaping @MainActor (NSWindow?) -> Void) {
        self.onWindowChange = onWindowChange
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportWindowIfNeeded()
    }

    func reportWindowIfNeeded() {
        guard reportedWindow !== window else { return }
        reportedWindow = window
        // `updateNSView` can run while SwiftUI is evaluating `body`. Defer
        // the AppKit binding so `attach` may publish state outside that pass.
        let callback = onWindowChange
        let currentWindow = window
        DispatchQueue.main.async {
            callback(currentWindow)
        }
    }
}

/// Owns the desktop pet panel while the app's main window is miniaturized.
@MainActor
final class FloatingDeskPetWindow: NSObject {
    static let shared = FloatingDeskPetWindow()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private weak var mainWindow: NSWindow?
    private weak var controller: DeskPetController?
    private var onDoubleTap: (() -> Void)?
    private var profileObservation: AnyCancellable?
    private var animationID = UUID()

    // 桌宠自主行为（静止/跳一跳）
    private var behaviorTimer: DispatchWorkItem?
    private var behaviorsActive = false
    private var rngState: UInt64 = 0

    override init() {
        super.init()
    }

    // MARK: - Window lifecycle

    func attach(
        to window: NSWindow?,
        controller: DeskPetController,
        onDoubleTap: @escaping () -> Void
    ) {
        self.onDoubleTap = onDoubleTap
        observeProfileChanges(on: controller)

        guard mainWindow !== window else {
            reconcilePanelVisibility()
            return
        }

        stopObservingWindow()
        mainWindow = window

        guard let window else {
            dismissPanel()
            return
        }

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(windowWillMiniaturize(_:)),
            name: NSWindow.willMiniaturizeNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(windowDidDeminiaturize(_:)),
            name: NSWindow.didDeminiaturizeNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        reconcilePanelVisibility()
    }

    private func observeProfileChanges(on controller: DeskPetController) {
        guard self.controller !== controller else { return }

        profileObservation?.cancel()
        self.controller?.isFloating = false
        self.controller = controller
        profileObservation = controller.$partnerProfile
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reconcilePanelVisibility()
                }
            }
    }

    private func stopObservingWindow() {
        if let mainWindow {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.willMiniaturizeNotification,
                object: mainWindow
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didDeminiaturizeNotification,
                object: mainWindow
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.willCloseNotification,
                object: mainWindow
            )
        }
    }

    @objc private func windowWillMiniaturize(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        showFloatingPet()
    }

    @objc private func windowDidDeminiaturize(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        hideFloatingPet(animated: true)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        stopObservingWindow()
        mainWindow = nil
        dismissPanel()
    }

    private func reconcilePanelVisibility() {
        guard let controller else {
            dismissPanel()
            return
        }

        guard controller.activePartnerProfile != nil else {
            dismissPanel()
            return
        }

        if mainWindow?.isMiniaturized == true {
            showFloatingPet()
        } else if panel != nil {
            hideFloatingPet(animated: false)
        } else {
            controller.isFloating = false
        }
    }

    // MARK: - Floating panel

    private func showFloatingPet() {
        guard
            let controller,
            let profile = controller.activePartnerProfile,
            let screen = mainWindow?.screen ?? NSScreen.main
        else { return }

        controller.isFloating = true

        let petSize = petSizeFromMainWindow()
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 20
        let destination = NSRect(
            x: screenFrame.maxX - petSize - margin,
            y: screenFrame.minY + margin,
            width: petSize,
            height: petSize
        )

        let panel = panel ?? makePanel(
            controller: controller,
            profile: profile,
            size: petSize,
            origin: petScreenPosition(petSize: petSize)
        )
        let currentAnimationID = UUID()
        animationID = currentAnimationID

        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.7
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(destination, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.animationID == currentAnimationID else { return }
                self?.bouncePanel(at: destination, animationID: currentAnimationID)
            }
        }
    }

    private func makePanel(
        controller: DeskPetController,
        profile: DeskPetProfile,
        size: CGFloat,
        origin: NSPoint
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: origin.x, y: origin.y, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        let hostingView = NSHostingView(
            rootView: AnyView(
                FloatingDeskPetView(
                    controller: controller,
                    profile: profile,
                    size: size,
                    onDoubleTap: onDoubleTap ?? {}
                )
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
        return panel
    }

    private func hideFloatingPet(animated: Bool) {
        stopBehaviorLoop()
        guard let panel else {
            controller?.isFloating = false
            return
        }

        guard animated, mainWindow != nil else {
            dismissPanel()
            return
        }

        let petSize = panel.frame.width
        let target = NSRect(
            origin: petScreenPosition(petSize: petSize),
            size: panel.frame.size
        )
        let currentAnimationID = UUID()
        animationID = currentAnimationID

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.animationID == currentAnimationID else { return }
                self?.dismissPanel()
            }
        }
    }

    private func bouncePanel(at destination: NSRect, animationID: UUID) {
        guard let panel, self.animationID == animationID else { return }

        var raisedFrame = destination
        raisedFrame.origin.y += 12
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(raisedFrame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard
                    let self,
                    self.animationID == animationID,
                    let panel = self.panel
                else { return }

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.12
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    panel.animator().setFrame(destination, display: true)
                } completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self, self.animationID == animationID else { return }
                        self.startBehaviorLoop(baseY: destination.origin.y)
                    }
                }
            }
        }
    }

    private func dismissPanel() {
        stopBehaviorLoop()
        animationID = UUID()
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        controller?.isFloating = false
    }

    // MARK: - Autonomous behavior (idle / move / jump)

    private func startBehaviorLoop(baseY: CGFloat) {
        guard panel != nil else { return }
        behaviorsActive = true
        scheduleNextAction()
    }

    private func stopBehaviorLoop() {
        behaviorsActive = false
        behaviorTimer?.cancel()
        behaviorTimer = nil
    }

    private func scheduleNextAction() {
        guard behaviorsActive else { return }
        behaviorTimer?.cancel()

        // 每个动作之间停顿 4 ~ 10 秒
        let delay = 4.0 + nextUnit() * 6.0
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in self?.performRandomAction() }
        }
        behaviorTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performRandomAction() {
        guard behaviorsActive, panel != nil, mainWindow?.isMiniaturized == true else {
            stopBehaviorLoop()
            return
        }

        // 静止 60% / 跳一跳 40%
        if nextUnit() < 0.6 {
            scheduleNextAction()
        } else {
            performJump()
        }
    }

    private func performJump() {
        guard let panel else { scheduleNextAction(); return }

        let petSize = panel.frame.width
        let landingFrame = panel.frame
        var raisedFrame = landingFrame
        raisedFrame.origin.y += petSize * 0.5

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(raisedFrame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let panel = self.panel, self.behaviorsActive else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.20
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    panel.animator().setFrame(landingFrame, display: true)
                } completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in self?.scheduleNextAction() }
                }
            }
        }
    }

    /// 以当前时间为种子的伪随机数，返回 [0, 1)
    private func nextUnit() -> Double {
        var x = rngState ^ UInt64(bitPattern: Int64(Date().timeIntervalSince1970 * 1000))
        x = x == 0 ? 0x9E3779B97F4A7C15 : x
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        rngState = x
        return Double(x >> 11) / Double(1 << 53)
    }

    // MARK: - Geometry

    private func petSizeFromMainWindow() -> CGFloat {
        // 优先沿用场景内桌宠的实际尺寸，保证最小化前后大小一致
        if let size = controller?.partnerPetSize { return size }

        guard let window = mainWindow else { return 136 }
        let sceneWidth = window.frame.width
            - LayoutMetrics.sidebarWidth
            - LayoutMetrics.contextPanelWidth
        let size = min(sceneWidth, window.frame.height) * 0.20
        return min(max(size, 76), 176)
    }

    private func petScreenPosition(petSize: CGFloat) -> NSPoint {
        guard let window = mainWindow else {
            let screen = NSScreen.main?.visibleFrame ?? .zero
            return NSPoint(x: screen.maxX - petSize - 22, y: screen.minY + 84)
        }

        let half = petSize / 2

        // 如果用户在场景内拖拽过桌宠，用拖拽后的位置映射到屏幕坐标
        if let pos = controller?.partnerScenePosition {
            // pos 为场景本地坐标（左上角原点，y 向下）下的桌宠中心
            let sceneLeft = window.frame.minX + LayoutMetrics.sidebarWidth
            let centerX = sceneLeft + pos.x
            let centerY = window.frame.maxY - pos.y  // 转换为屏幕坐标（左下角原点，y 向上）
            return NSPoint(x: centerX - half, y: centerY - half)
        }

        return NSPoint(
            x: window.frame.maxX - LayoutMetrics.contextPanelWidth - 22 - petSize,
            y: window.frame.minY + 84
        )
    }

}

private struct FloatingDeskPetView: View {
    @ObservedObject var controller: DeskPetController
    let profile: DeskPetProfile
    let size: CGFloat
    let onDoubleTap: () -> Void

    var body: some View {
        InteractiveDeskPetView(
            controller: controller,
            profile: profile,
            size: size,
            onDoubleTap: onDoubleTap
        )
    }
}
#endif
