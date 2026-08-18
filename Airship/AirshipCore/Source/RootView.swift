/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

struct RootView<Content: View>: View {

#if !os(tvOS) && !os(watchOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    /// Orientation to resolve placement selectors against. Self-contained: we find the window we
    /// were put in and track its shape, so no presentation has to plumb this in.
    @StateObject private var orientationTracker: ThomasOrientationTracker

    @State private var isForeground: Bool = true
    @State private var isVisible: Bool = false
    @State private var isVoiceOverRunning: Bool = RootViewResolver.resolveIsVoiceOverRunning()

    @ObservedObject var thomasEnvironment: ThomasEnvironment
    @StateObject var thomasState: ThomasState
    @StateObject var validatableHelper: ValidatableHelper = ValidatableHelper()
    @StateObject var formInputCollector: ThomasFormDataCollector = ThomasFormDataCollector()

    // Default form state so @EnvironmentObject does not crash
    @StateObject
    private var defaultFormState: ThomasFormState = ThomasFormState(
        identifier: "",
        formType: .form,
        formResponseType: nil,
        validationMode: .onDemand
    )

    // Default pager state so @EnvironmentObject does not crash
    @StateObject
    private var defaultPagerState: PagerState = PagerState(
        identifier: "",
        branching: nil
    )

    // Default video state so @EnvironmentObject does not crash
    @StateObject
    private var defaultVideoState: VideoState = VideoState(
        identifier: ""
    )

    // Default async view state so @EnvironmentObject does not crash
    @StateObject
    private var defaultAsyncViewState: ThomasAsyncViewState = ThomasAsyncViewState()
    
    let layout: AirshipLayout
    let content: (ThomasOrientation, ThomasWindowSize) -> Content

    let associatedLabelResolver: ThomasAssociatedLabelResolver

    /// - Parameter initialWindowSize: Window size snapshot from display time, where the caller has
    /// one. Only seeds the first frame -- the window is tracked from there regardless.
    init(
        thomasEnvironment: ThomasEnvironment,
        layout: AirshipLayout,
        initialWindowSize: CGSize = .zero,
        @ViewBuilder content: @escaping (ThomasOrientation, ThomasWindowSize) -> Content
    ) {
        self.thomasEnvironment = thomasEnvironment
        self.layout = layout
        self._orientationTracker = StateObject(
            wrappedValue: ThomasOrientationTracker(initialSize: initialWindowSize)
        )
        self.content = content
        self._isForeground = State(initialValue: AppStateTracker.shared.isForegrounded)
        self._thomasState = StateObject(
            wrappedValue: ThomasState() { [weak thomasEnvironment] state in
                thomasEnvironment?.onStateChange(state)
            }
        )
        self.associatedLabelResolver = ThomasAssociatedLabelResolver(layout: layout)
    }

    @ViewBuilder
    var body: some View {
        // Orientation is read straight off the tracker, so a resize re-renders through the usual
        // observation path -- no notification to subscribe to and no state to keep in sync.
        content(orientationTracker.orientation, resolveWindowSize())
            .environmentObject(self.thomasEnvironment)
            .environmentObject(self.thomasState)
            .environmentObject(self.formInputCollector)
            .environmentObject(self.validatableHelper)
            .environmentObject(self.defaultPagerState)
            .environmentObject(self.defaultFormState)
            .environmentObject(self.defaultVideoState)
            .environmentObject(self.defaultAsyncViewState)
            .environment(\.windowSize, resolveWindowSize())
            .environment(\.isVisible, isVisible)
            .environment(\.isVoiceOverRunning, isVoiceOverRunning)
            .environment(\.thomasAssociatedLabelResolver, associatedLabelResolver)
            .onReceive(NotificationCenter.default.publisher(for: AppStateTracker.didTransitionToForeground)) { (_) in
                self.isForeground = true
                self.thomasEnvironment.onVisibilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
            }
            .onReceive(NotificationCenter.default.publisher(for: AppStateTracker.didTransitionToBackground)) { (_) in
                self.isForeground = false
                self.thomasEnvironment.onVisibilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
            }
#if os(macOS)
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
                updateVoiceoverRunningState()
            }
#elseif !os(watchOS)
        // iOS, tvOS, visionOS
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
                updateVoiceoverRunningState()
            }
#endif
            .onAppear {
                updateVoiceoverRunningState()
                self.isVisible = true
                self.thomasEnvironment.onVisibilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
            }
            .onDisappear {
                self.isVisible = false
                self.thomasEnvironment.onVisibilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
            }
#if !os(watchOS)
            .background(
                ThomasSceneSizeReader { size in
                    orientationTracker.update(size)
                }
            )
#endif
    }

    /// Uses the vertical and horizontal class size to determine small, medium, large window size:
    /// - large: regular x regular = large
    /// - medium: regular x compact or compact x regular
    /// - small: compact x compact
    func resolveWindowSize() -> ThomasWindowSize {
#if os(watchOS)
        return .small
#elseif os(tvOS)
        return .large
#else
        switch (verticalSizeClass, horizontalSizeClass) {
        case (.regular, .regular):
            return .large
        case (.compact, .compact):
            return .small
        default:
            return .medium
        }
#endif
    }

    private func updateVoiceoverRunningState() {
        isVoiceOverRunning = RootViewResolver.resolveIsVoiceOverRunning()
    }
}

/// Non-generic helpers so referencing them does not form a `RootView<Content>`
/// metatype, which would surface `Content`'s isolated `View` conformance.
@MainActor
private enum RootViewResolver {
    static func resolveIsVoiceOverRunning() -> Bool {
#if os(watchOS)
        // watchOS does not expose a public property to check VoiceOver status
        return false
#elseif os(macOS)
        // macOS equivalent
        return NSWorkspace.shared.isVoiceOverEnabled
#else
        // iOS, tvOS, visionOS
        return UIAccessibility.isVoiceOverRunning
#endif
    }
}

/// Orientation a layout should resolve its placement selectors against.
///
/// This is a property of the scene, not of the device. In resizable environments the two disagree:
/// a window is free to take a shape that has nothing to do with the device's interface orientation,
/// the system treats `supportedInterfaceOrientations` as no more than a preference, and iPhone
/// Mirroring reports portrait no matter how the user has sized the window. So we infer it from the
/// shape of the space instead.
///
/// Every presentation reports through ``ThomasSceneSizeReader``, which finds the scene the layout
/// was actually placed in. Note the banner path measures the window a second time, independently,
/// into `ThomasBannerConstraints` -- that one sizes the banner itself and is not wired to this.
///
/// - Note: For internal use only. :nodoc:
@MainActor
final class ThomasOrientationTracker: ObservableObject {

    @Published
    private(set) var orientation: ThomasOrientation = .landscape

    /// - Parameter initialSize: Size of the window at display time, so the first frame resolves
    /// against the real window rather than the default above. Empty sizes leave the default.
    init(initialSize: CGSize = .zero) {
        self.update(initialSize)
    }

    /// Reports the size of the scene the layout is being presented in.
    ///
    /// Empty sizes are ignored so a scene that has not been laid out yet cannot knock orientation
    /// back to the default. No platform special-casing is needed: a TV reports a landscape scene, a
    /// Mac window reports whatever the user dragged it to, and watchOS never reports at all.
    func update(_ size: CGSize?) {
        guard let size, size.width > 0, size.height > 0 else { return }

        let resolved: ThomasOrientation = size.width > size.height ? .landscape : .portrait
        guard self.orientation != resolved else { return }

        self.orientation = resolved
    }
}

#if !os(watchOS)

/// Reports the size of the scene -- or on macOS, the window -- a layout has been placed into.
///
/// The view finds the scene it was actually put in, which a `GeometryReader` cannot tell us since
/// that only ever describes the container. It also beats asking `AirshipSceneManager` for the last
/// active scene, which is only a guess once more than one exists. Works for every presentation:
/// banner and modal overlay windows are created with `UIWindow(windowScene:)`, so they resolve to
/// the same scene as the host app.
///
/// - Note: For internal use only. :nodoc:
struct ThomasSceneSizeReader: AirshipNativeViewRepresentable {

    let onChange: @MainActor (CGSize?) -> Void

#if os(macOS)
    typealias NSViewType = NSView

    func makeNSView(context: Context) -> NSView {
        ProbeView(onChange: self.onChange)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ProbeView: NSView {
        private let onChange: @MainActor (CGSize?) -> Void

        init(onChange: @escaping @MainActor (CGSize?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.report()
        }

        override func layout() {
            super.layout()
            self.report()
        }

        /// The window's own content area, not the screen's -- a Mac window is rarely the size of the
        /// display it happens to be on, and `frame` would fold in the title bar and chrome.
        private func report() {
            guard let window = self.window else { return }
            self.onChange(window.contentLayoutRect.size)
        }
    }
#else
    typealias UIViewType = UIView

    func makeUIView(context: Context) -> UIView {
        ProbeView(onChange: self.onChange)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class ProbeView: UIView {
        private let onChange: @MainActor (CGSize?) -> Void

        /// Owned by the window, so held weakly.
        private weak var resizeObserver: WindowResizeObserverView?

        init(onChange: @escaping @MainActor (CGSize?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            self.isUserInteractionEnabled = false
            self.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            self.syncResizeObserver()
            self.report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            self.report()
        }

        /// Our own bounds only change when the layout above us changes, and for a fixed-size layout
        /// that never happens -- so we would read the scene once and never look again. A view pinned
        /// to the window does the watching instead, which makes reporting independent of every
        /// layout decision between us and the window, including the host app's.
        private func syncResizeObserver() {
            guard let window = self.window else {
                self.resizeObserver?.removeFromSuperview()
                self.resizeObserver = nil
                return
            }

            guard self.resizeObserver?.superview !== window else { return }

            self.resizeObserver?.removeFromSuperview()

            let observer = WindowResizeObserverView { [weak self] in
                self?.report()
            }
            observer.translatesAutoresizingMaskIntoConstraints = false
            window.insertSubview(observer, at: 0)
            NSLayoutConstraint.activate([
                observer.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                observer.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                observer.topAnchor.constraint(equalTo: window.topAnchor),
                observer.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            ])
            self.resizeObserver = observer
        }

        private func report() {
            guard let window = self.window else { return }
            self.onChange(window.windowScene?.airshipAvailableSpace ?? window.bounds.size)
        }
    }

    /// Pinned to the window's edges, so its bounds -- and therefore its layout pass -- track the
    /// window regardless of what the layout above the probe is doing. Non-interactive and clear, and
    /// inserted at the back of the window so it cannot affect anything the host app draws.
    private final class WindowResizeObserverView: UIView {
        private let onLayout: @MainActor () -> Void

        init(onLayout: @escaping @MainActor () -> Void) {
            self.onLayout = onLayout
            super.init(frame: .zero)
            self.isUserInteractionEnabled = false
            self.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            self.onLayout()
        }
    }
#endif
}

#endif
