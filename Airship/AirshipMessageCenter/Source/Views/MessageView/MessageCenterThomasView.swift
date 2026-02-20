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
        layoutRequest: @escaping () async throws -> URLRequest,
        analytics: ThomasDisplayListener,
        dismissHandle: ThomasDismissHandle,
        stateStorage: (any LayoutDataStorage)? = nil
    ) {
        self._phase = phase
        self._viewModel = StateObject(
            wrappedValue: ViewModel(
                request: layoutRequest,
                analytics: analytics,
                dismissHandle: dismissHandle,
                stateStorage: stateStorage
            )
        )
    }
    
    var body: some View {
        if let layout = viewModel.layout {
            AirshipSimpleLayoutView(
                layout: layout,
                viewModel: viewModel.layoutViewModel
            )
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
    private let layoutRequest: () async throws -> URLRequest
    private let stateStorage: (any LayoutDataStorage)?

    @Published
    private(set) var layout: AirshipLayout? = nil

    let analyticsRecorder: any ThomasDelegate
    let dismissHandle: ThomasDismissHandle
    let layoutViewModel: AirshipSimpleLayoutViewModel

    init(
        request: @escaping () async throws -> URLRequest,
        analytics: ThomasDisplayListener,
        dismissHandle: ThomasDismissHandle,
        stateStorage: (any LayoutDataStorage)? = nil
    ) {
        self.layoutRequest = request
        self.analyticsRecorder = analytics
        self.dismissHandle = dismissHandle
        self.stateStorage = stateStorage
        self.layoutViewModel = AirshipSimpleLayoutViewModel(
            delegate: analytics,
            dismissHandle: dismissHandle,
            stateStorage: stateStorage
        )
    }
    
    func loadLayout() async -> MessageCenterMessageView.DisplayPhase {
        if let layout {
            await preloadData(for: layout)
            return .loaded
        }
        
        do {
            let request = try await self.layoutRequest()
            let (data, _) = try await URLSession.airshipSecureSession.data(for: request)
            let downloaded = try JSONDecoder().decode(AirshipLayout.self, from: data)
            await preloadData(for: downloaded)
            self.layout = downloaded
        } catch {
            return .error(error)
        }
        
        return .loaded
    }

    func dismiss() {
        self.dismissHandle.dismiss()
    }
    
    private func preloadData(for layout: AirshipLayout) async {
        await self.stateStorage?.prepare(restoreID: "static") //TODO: replace with the actual
    }
}

extension View {
    func also(_ action: (Self) -> ()) -> some View {
        action(self)
        return self
    }
}
