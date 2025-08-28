/* Copyright Airship and Contributors */


public import SwiftUI
public import Combine

/// NOTE: For internal use only. :nodoc:
public extension Color {
    static var airshipTappableClear: Color { Color.white.opacity(0.001) }
    static var airshipShadowColor: Color { Color.black.opacity(0.33) }
}

/// NOTE: For internal use only. :nodoc:
public extension View {
    /// Wrapper to prevent linter warnings for deprecated onChange method
    /// - Parameters:
    ///   - value: The value to observe for changes.
    ///   - initial: A Boolean value that determines whether the action should be fired initially.
    ///   - action: The action to perform when the value changes.
    /// NOTE: For internal use only. :nodoc:
    @ViewBuilder
    func airshipOnChangeOf<Value: Equatable>(_ value: Value, initial: Bool = false, _ action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
            self.onChange(of: value, initial: initial, {
                action(value)
            })
        } else {
            self.onChange(of: value, perform: action)
        }
    }

    @ViewBuilder
    func showing(isShowing: Bool) -> some View {
        if isShowing {
            self.opacity(1)
        } else {
            self.hidden().opacity(0)
        }
    }

    @ViewBuilder
    func airshipAddNub(
        isTopPlacement: Bool,
        nub: AnyView,
        itemSpacing: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            if isTopPlacement {
                self
                nub.padding(.vertical, itemSpacing / 2)
            } else {
                nub.padding(.vertical, itemSpacing / 2)
                self
            }
        }
    }

    @ViewBuilder
    private func airshipApplyTransition(
        isTopPlacement: Bool
    ) -> some View {
        if isTopPlacement {
            self.transition(
                .asymmetric(
                    insertion: .move(edge: .top),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
        } else {
            self.transition(
                .asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                )
            )
        }
    }

    @ViewBuilder
    func airshipApplyTransitioningPlacement(
        isTopPlacement: Bool
    ) -> some View {
        if isTopPlacement {
            VStack {
                self.airshipApplyTransition(isTopPlacement:isTopPlacement)
                Spacer()
            }
        } else {
            VStack {
                Spacer()
                self.airshipApplyTransition(isTopPlacement:isTopPlacement)
            }
        }
    }
}


#if !os(watchOS)
/// NOTE: For internal use only. :nodoc:
public extension UIWindow {
    func airshipAddRootController<T: UIViewController>(
        _ viewController: T?
    ) {
        viewController?.modalPresentationStyle = UIModalPresentationStyle.automatic
        viewController?.view.isUserInteractionEnabled = true

        if let viewController = viewController,
           let rootController = self.rootViewController
        {
            rootController.addChild(viewController)
            viewController.didMove(toParent: rootController)
            rootController.view.addSubview(viewController.view)
        }

        self.isUserInteractionEnabled = true
    }

    static func airshipMakeModalReadyWindow(
        scene: UIWindowScene
    ) -> UIWindow {
        let window: UIWindow = AirshipWindowFactory.shared.makeWindow(windowScene: scene)
        window.accessibilityViewIsModal = true
        window.alpha = 0
        window.makeKeyAndVisible()
        window.isUserInteractionEnabled = false

        return window
    }

    func airshipAnimateIn() {
        self.makeKeyAndVisible()
        self.isUserInteractionEnabled = true

        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 1
            },
            completion: { _ in
            }
        )
    }

    func airshipAnimateOut() {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 0
            },
            completion: { _ in
                self.isHidden = true
                self.isUserInteractionEnabled = false
                self.removeFromSuperview()
            }
        )
    }
}
#endif


/// NOTE: For internal use only. :nodoc:
@MainActor
public final class AirshipObservableTimer: ObservableObject {
    private static let tick: TimeInterval = 0.1
    private var elapsedTime: TimeInterval = 0
    private let duration: TimeInterval?

    private var isStarted: Bool = false
    private var task: Task<Void, any Error>?
    public var isPaused: Bool = false

    @Published
    public private(set) var isExpired: Bool = false

    public init(duration: TimeInterval?) {
        self.duration = duration
    }

    public func onAppear() {
        guard !isStarted, !isExpired, let duration else {
            return
        }

        self.isStarted = true

        self.task = Task { @MainActor [weak self] in
            while self?.isExpired == false, self?.isStarted == true {
                try await Task.sleep(nanoseconds: UInt64(Self.tick * 1_000_000_000))
                guard let self, self.isStarted, !Task.isCancelled else { return }

                if !self.isPaused {
                    self.elapsedTime += Self.tick
                    if self.elapsedTime >= duration {
                        self.isExpired = true
                        self.task?.cancel()
                    }
                }
            }
        }
    }

    public func onDisappear() {
        isStarted = false
        task?.cancel()
    }
}
