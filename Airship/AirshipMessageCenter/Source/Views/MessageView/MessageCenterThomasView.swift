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
    
    init(
        phase: Binding<MessageCenterMessageView.DisplayPhase>,
        layout: LoadableLayout,
        dismiss: @escaping () async -> Void
    ) {
        self._phase = phase
        self.viewModel = ViewModel(layout: layout, onDismiss: dismiss)
    }
    
    var body: some View {
        if let layout = viewModel.layout {
            AirshipSimpleLayoutView(layout: layout, delegate: viewModel)
                .onAppear { viewModel.onDisplayed() }
        } else {
            Color.clear.task {
                //TODO: fix reload button
                if case .loading = phase {
                    self.phase = await viewModel.loadLayout()
                }
            }
        }
    }
}

@MainActor
private final class ViewModel: ObservableObject, ThomasDelegate {
    private let onDismiss: () async -> Void
    private let loadableLayout: LoadableLayout
    
    @Published
    private(set) var layout: AirshipLayout? = nil
    
    
    init (
        layout: LoadableLayout,
        onDismiss: @escaping () async -> Void
    ) {
        self.loadableLayout = layout
        self.layout = loadableLayout.layout
        self.onDismiss = onDismiss
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
    
    func onDisplayed() {
        //TODO: report metered usage
    }
    
    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
    
    func onReportingEvent(_ event: ThomasReportingEvent) {
        //TODO: track analytics events
    }
    
    func onDismissed(cancel: Bool) {
        Task { @MainActor [weak self] in
            await self?.onDismiss()
        }
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
