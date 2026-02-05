/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

struct MessageCenterThomasView: View {
    
    @Binding
    var phase: MessageCenterMessageView.DisplayPhase
    
    @StateObject
    private var viewModel: ViewModel
    
    init(
        phase: Binding<MessageCenterMessageView.DisplayPhase>,
        layout: LoadableLayout,
        analytics: ThomasDisplayListener,
        timer: any AirshipTimerProtocol,
        dismissHandle: ThomasDismissHandle
    ) {
        self._phase = phase
        self._viewModel = StateObject(
            wrappedValue: ViewModel(
                layout: layout,
                analytics: analytics,
                timer: timer,
                dismissHandle: dismissHandle
            )
        )
    }
    
    var body: some View {
        if let layout = viewModel.layout {
            AirshipSimpleLayoutView(
                layout: layout,
                viewModel: viewModel.layoutViewModel
            ).onAppear {
                viewModel.timer.start()
            }
        } else {
            Color.clear.task {
                switch phase {
                case .loaded: return
                default: self.phase = await viewModel.loadLayout()
                }
            }
        }
    }
    
    
}

@MainActor
private final class ViewModel: ObservableObject {
    private let loadableLayout: LoadableLayout

    @Published
    private(set) var layout: AirshipLayout? = nil

    let analyticsRecorder: any ThomasDelegate
    let timer: any AirshipTimerProtocol
    let dismissHandle: ThomasDismissHandle
    let layoutViewModel: AirshipSimpleLayoutViewModel

    init(
        layout: LoadableLayout,
        analytics: ThomasDisplayListener,
        timer: any AirshipTimerProtocol,
        dismissHandle: ThomasDismissHandle
    ) {
        self.timer = timer
        self.loadableLayout = layout
        self.layout = loadableLayout.layout
        self.analyticsRecorder = analytics
        self.dismissHandle = dismissHandle
        self.layoutViewModel = AirshipSimpleLayoutViewModel(
            delegate: analytics,
            timer: timer,
            dismissHandle: dismissHandle
        )
    }
    
    func loadLayout() async -> MessageCenterMessageView.DisplayPhase {
        guard self.layout == nil else {
            return .loaded
        }
        
        do {
            self.layout = try await self.loadableLayout.load()
        } catch {
            return .error(error)
        }
        
        return .loaded
    }

    func dismiss() {
        self.dismissHandle.dismiss()
    }
}


@MainActor
class LoadableLayout {
    private let request: () async throws -> URLRequest
    private(set) var layout: AirshipLayout? = nil
    
    init(request: @escaping () async throws -> URLRequest) {
        self.request = request
    }
    
    func load() async throws -> AirshipLayout? {
        if let layout = self.layout {
            return layout
        }
        
        let request = try await self.request()
        let (data, _) = try await URLSession.airshipSecureSession.data(for: request)
        self.layout = try JSONDecoder().decode(AirshipLayout.self, from: data)
        
        return self.layout
    }
}

extension View {
    func also(_ action: (Self) -> ()) -> some View {
        action(self)
        return self
    }
}
