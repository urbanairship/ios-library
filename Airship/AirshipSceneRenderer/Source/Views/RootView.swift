/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

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

    /// The single focus authority for this layout's text inputs. Hoisting it here (rather
    /// than a per-input `@FocusState`) means a text input that gets recreated — e.g. when
    /// a branching pager re-evaluates its page list as form state changes — cannot bring
    /// its own focus back, and navigation can resign focus in one place by setting nil.
    @FocusState private var focusedInputID: String?

    @ObservedObject var thomasEnvironment: ThomasEnvironment
    @StateObject var thomasState: ThomasState
    @StateObject var validatableHelper: ValidatableHelper = ValidatableHelper()
    @StateObject private var formInputCollector: ThomasFormDataCollector = ThomasFormDataCollector()

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
            wrappedValue: ThomasState(
                sceneAIExecutor: thomasEnvironment.extensions.aiInferenceExecutor
            ) { [weak thomasEnvironment] state in
                thomasEnvironment?.onStateChange(state)
            }
        )
        self.associatedLabelResolver = ThomasAssociatedLabelResolver(
            layout: layout,
            localizer: thomasEnvironment.extensions.localizer
        )
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
            .environment(\.thomasFocusedInput, $focusedInputID)
            // Bridge the SwiftUI focus state (the owner of the keyboard) to the
            // environment object's `focusedID` (what callers read/write), both ways.
            // User-driven focus flows FocusState -> focusedID; programmatic focus and
            // dismissal (button tap / page change set focusedID = nil) flow focusedID ->
            // FocusState. The equality guards stop the mirror from looping.
            .airshipOnChangeOf(focusedInputID) { newValue in
                if thomasEnvironment.focusedID != newValue {
                    thomasEnvironment.focusedID = newValue
                }
            }
            .airshipOnChangeOf(thomasEnvironment.focusedID) { newValue in
                if focusedInputID != newValue {
                    focusedInputID = newValue
                }
            }
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
                    // `report()` calls this synchronously from the representable's own
                    // layout()/layoutSubviews(), which SwiftUI drives as part of resolving
                    // this very view's layout -- mutating `@Published` state inline here is
                    // "publishing changes from within view updates." Deferring to the next
                    // run loop turn moves the mutation outside that update.
                    Task { @MainActor in
                        orientationTracker.update(size)
                    }
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

        /// `deinit` runs nonisolated even for a MainActor class -- deallocation can happen from
        /// any thread -- so this can't be a normal (implicitly MainActor-isolated) stored
        /// property if `deinit` is going to read it. Only ever written on the main actor
        /// (`syncWindowObserver()`); `removeObserver` itself is documented safe from any thread.
        nonisolated(unsafe) private var resizeObserver: AnyObject?

        init(onChange: @escaping @MainActor (CGSize?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.syncWindowObserver()
            self.report()
        }

        override func layout() {
            super.layout()
            self.report()
        }

        /// Our own layout() only fires when the layout above us changes, and for an embedded
        /// placement nested several layers inside the host app's UI, AppKit may not re-layout
        /// this deeply-nested probe on every increment of a window resize -- only once it's
        /// large enough to actually propagate down. `NSWindow.didResizeNotification` fires on
        /// every increment of a live resize regardless of the view hierarchy's own layout
        /// timing, so listening for it directly -- rather than routing through a view pinned
        /// into that hierarchy -- keeps reporting independent of it without touching the
        /// hierarchy at all.
        private func syncWindowObserver() {
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
                self.resizeObserver = nil
            }

            guard let window = self.window else { return }

            self.resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                // `queue: .main` only guarantees this *runs* on the main thread -- the closure
                // type itself isn't proven MainActor-isolated at compile time, so `report()`
                // (MainActor-isolated, like the rest of this NSView) needs an explicit assertion.
                MainActor.assumeIsolated {
                    self?.report()
                }
            }
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
