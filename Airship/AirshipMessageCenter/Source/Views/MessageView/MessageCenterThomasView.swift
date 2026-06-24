/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipScenes

struct MessageCenterThomasView: View {

    @Binding
    var phase: MessageCenterMessageView.DisplayPhase

    @StateObject
    private var viewModel: ViewModel

    init(
        phase: Binding<MessageCenterMessageView.DisplayPhase>,
        layoutRequest: @escaping () async throws -> URLRequest,
        displayListener: ThomasDisplayListener,
        dismissHandle: ThomasDismissHandle,
        stateStorage: @escaping () -> any LayoutDataStorage
    ) {
        self._phase = phase
        self._viewModel = StateObject(
            wrappedValue: ViewModel(
                request: layoutRequest,
                displayListener: displayListener,
                dismissHandle: dismissHandle,
                stateStorage: stateStorage
            )
        )
    }

    var body: some View {
        if let (layout, model) = viewModel.layout {
            AirshipSimpleLayoutView(
                layout: layout,
                viewModel: model
            )
        } else {
            Color.clear.task {
                self.phase = await viewModel.loadLayout()
            }
        }
    }
}

@MainActor
private final class ViewModel: ObservableObject {
    private let layoutRequest: () async throws -> URLRequest
    private let stateStorageBuilder: () -> any LayoutDataStorage

    @Published
    private(set) var layout: (AirshipLayout, AirshipSimpleLayoutViewModel)? = nil

    let displayListener: any ThomasDelegate
    let dismissHandle: ThomasDismissHandle

    private var loadTask: Task<MessageCenterMessageView.DisplayPhase, Never>?

    init(
        request: @escaping () async throws -> URLRequest,
        displayListener: ThomasDisplayListener,
        dismissHandle: ThomasDismissHandle,
        stateStorage: @escaping () -> any LayoutDataStorage
    ) {
        self.layoutRequest = request
        self.displayListener = displayListener
        self.dismissHandle = dismissHandle
        self.stateStorageBuilder = stateStorage
    }

    func loadLayout() async -> MessageCenterMessageView.DisplayPhase {
        guard self.layout == nil else {
            return .loaded
        }

        if let loadTask {
            return await loadTask.value
        }

        let task = Task { await self.performLoadLayout() }
        self.loadTask = task
        let result = await task.value
        self.loadTask = nil
        return result
    }

    private func performLoadLayout() async -> MessageCenterMessageView.DisplayPhase {
        guard self.layout == nil else {
            return .loaded
        }

        do {
            let request = try await self.layoutRequest()
            let (data, _) = try await URLSession.airshipSecureSession.data(for: request)
            let downloaded = try JSONDecoder().decode(AirshipLayout.self, from: data)
            let storage = await preloadData(for: downloaded)
            self.layout = (downloaded, makeSimpleLayoutViewModel(with: storage))
        } catch {
            return .error(error)
        }

        return .loaded
    }

    private func preloadData(for layout: AirshipLayout) async -> (any LayoutDataStorage)? {
        let storage = self.stateStorageBuilder()

        guard let options = layout.options?.stateRestoration else {
            storage.clear()
            return nil
        }

        await storage.prepare(restoreID: options.restoreID)
        return storage
    }

    private func makeSimpleLayoutViewModel(with storage: (any LayoutDataStorage)?) -> AirshipSimpleLayoutViewModel {
        AirshipSimpleLayoutViewModel(
            delegate: displayListener,
            dismissHandle: dismissHandle,
            stateStorage: storage
        )
    }
}
