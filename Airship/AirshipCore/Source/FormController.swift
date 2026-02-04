/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

@MainActor
struct FormController: View {

    enum FormInfo {
        case nps(ThomasViewInfo.NPSController)
        case form(ThomasViewInfo.FormController)
    }

    private let info: FormInfo
    private let constraints: ViewConstraints

    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject private var environment: ThomasEnvironment
    @EnvironmentObject private var state: ThomasState

    init(info: FormInfo, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        Content(
            info: self.info,
            constraints: constraints,
            environment: environment,
            parentFormState: formState,
            parentFormDataCollector: formDataCollector,
            parentState: state
        )
        .id(info.identifier)
    }

    private struct Content: View {

        private let info: FormController.FormInfo
        private let constraints: ViewConstraints

        @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
        @Environment(\.layoutState) private var layoutState

        @ObservedObject private var formState: ThomasFormState
        @StateObject private var formDataCollector: ThomasFormDataCollector
        @StateObject private var state: ThomasState

        init(
            info: FormController.FormInfo,
            constraints: ViewConstraints,
            environment: ThomasEnvironment,
            parentFormState: ThomasFormState,
            parentFormDataCollector: ThomasFormDataCollector,
            parentState: ThomasState
        ) {
            self.info = info
            self.constraints = constraints

            // Use the environment to create or retrieve the state in case the view
            // stack changes and we lose our state.
            let formState = environment.retrieveState(identifier: info.identifier) {
                ThomasFormState(
                    identifier: info.identifier,
                    formType: info.formType,
                    formResponseType: info.responseType,
                    validationMode: info.validationMode ?? .immediate,
                    parentFormState: info.isParent ? nil : parentFormState
                )
            }

            if info.isParent {
                formState.onSubmit = { [weak environment] identifier, result, layoutState in
                    guard let environment else { throw AirshipErrors.error("Missing environment") }
                    environment.submitForm(
                        result: ThomasFormResult(
                            identifier: identifier,
                            formData: try ThomasFormPayloadGenerator.makeFormEventPayload(
                                identifier: identifier,
                                formValue: result.value
                            )
                        ),
                        channels: result.channels ?? [],
                        attributes: result.attributes ?? [],
                        layoutState: layoutState
                    )
                }
            } else {
                formState.onSubmit = { [weak parentFormDataCollector] identifier, result, layoutState in
                    guard let parentFormDataCollector else { throw AirshipErrors.error("Missing form collector") }
                    let field = ThomasFormField.validField(identifier: identifier, input: result.value, result: result)
                    parentFormDataCollector.updateField(field, pageID: layoutState.pagerState?.currentPageId)
                }
            }

            self._formState = ObservedObject(wrappedValue: formState)
            self._formDataCollector = StateObject(
                wrappedValue: parentFormDataCollector.with(formState: formState)
            )
            self._state = StateObject(
                wrappedValue: parentState.with(formState: formState)
            )
        }

        var body: some View {
            ViewFactory.createView(self.info.view, constraints: constraints)
                .thomasCommon(self.info.thomasInfo, formInputID: self.info.identifier)
                .thomasEnableBehaviors(self.info.formEnableBehaviors) { enabled in
                    self.formState.isEnabled = enabled
                }
                .environmentObject(formState)
                .environmentObject(formDataCollector)
                .environmentObject(state)
                .airshipOnChangeOf(formState.isVisible) { [weak formState, weak thomasEnvironment] incoming in
                    guard info.isParent, incoming, let formState, let thomasEnvironment else {
                        return
                    }
                    thomasEnvironment.formDisplayed(
                        formState,
                        layoutState: layoutState.override(
                            formState: formState
                        )
                    )
                }
        }
    }
}

struct FormControllerDebug: View {
    @EnvironmentObject var state: ThomasFormState

    var body: some View {
        Text(String(describing: state))
    }
}

fileprivate extension FormController.FormInfo {
    var responseType: String? {
        switch(self) {
        case .nps(let info): info.properties.responseType
        case .form(let info): info.properties.responseType
        }
    }

    var formType: ThomasFormState.FormType {
        switch(self) {
        case .nps(let info): .nps(info.properties.npsIdentifier)
        case .form: .form
        }
    }

    var formEnableBehaviors: [ThomasEnableBehavior]? {
        switch(self) {
        case .nps(let info): info.properties.formEnableBehaviors
        case .form(let info): info.properties.formEnableBehaviors
        }
    }

    var identifier: String {
        switch(self) {
        case .nps(let info): info.properties.identifier
        case .form(let info): info.properties.identifier
        }
    }

    var isParent: Bool {
        switch(self) {
        case .nps(let info): info.properties.submit != nil
        case .form(let info): info.properties.submit != nil
        }
    }

    var validationMode: ThomasFormValidationMode? {
        switch(self) {
        case .nps(let info): info.properties.validationMode
        case .form(let info): info.properties.validationMode
        }
    }

    var view: ThomasViewInfo {
        switch(self) {
        case .nps(let info): info.properties.view
        case .form(let info): info.properties.view
        }
    }

    var thomasInfo: any ThomasViewInfo.BaseInfo {
        switch(self) {
        case .nps(let info): info
        case .form(let info): info
        }
    }
}
