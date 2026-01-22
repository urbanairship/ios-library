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
    
    @ObservedObject
    private var viewModel: ViewModel
    
    var backButtonDelegate: any MessageViewBackButtonCallback {
        return viewModel
    }
    
    init(
        phase: Binding<MessageCenterMessageView.DisplayPhase>,
        layout: LoadableLayout,
        analytics: ThomasDisplayListener,
        timer: any AirshipTimerProtocol
    ) {
        self._phase = phase
        self.viewModel = ViewModel(
            layout: layout,
            analytics: analytics,
            timer: timer
        )
    }
    
    var body: some View {
        if let layout = viewModel.layout {
            AirshipSimpleLayoutView(
                layout: layout,
                delegate: viewModel.analyticsRecorder,
                timer: viewModel.timer
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
    
    init (
        layout: LoadableLayout,
        analytics: ThomasDisplayListener,
        timer: any AirshipTimerProtocol
    ) {
        self.timer = timer
        self.loadableLayout = layout
        self.layout = loadableLayout.layout
        self.analyticsRecorder = analytics
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
    
    func reportDismissed() {
        analyticsRecorder.onReportingEvent(.dismiss(.userDismissed, timer.time, ThomasLayoutContext()))
    }
}

extension ViewModel: MessageViewBackButtonCallback {
    func onBackButtonTapped() {
        reportDismissed()
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
