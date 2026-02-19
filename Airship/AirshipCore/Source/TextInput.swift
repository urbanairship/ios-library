/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

struct TextInput: View {


    private let info: ThomasViewInfo.TextInput
    private let constraints: ViewConstraints

    @Environment(\.pageIdentifier) private var pageID
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.colorScheme) private var colorScheme

    @EnvironmentObject private var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var thomasState: ThomasState
    @EnvironmentObject private var validatableHelper: ValidatableHelper
    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    @State private var isEditing: Bool = false
    @StateObject private var viewModel: ViewModel

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .textInput,
            thomasState: thomasState
        )
    }


    private var scaledFontSize: Double {
        UIFontMetrics.default.scaledValue(
            for: self.info.properties.textAppearance.fontSize
        )
    }

    init(
        info: ThomasViewInfo.TextInput,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints

        self._viewModel = StateObject(
            wrappedValue: ViewModel(
                inputProperties: info.properties,
                isRequired: info.validation.isRequired ?? false
            )
        )
    }

#if !os(watchOS)
    private var keyboardType: UIKeyboardType {
        switch self.info.properties.inputType {
        case .email:
            return .emailAddress
        case .number:
            return .decimalPad
        case .text:
            return .default
        case .textMultiline:
            return .default
        case .sms:
            return .phonePad
        }
    }
#endif

    @ViewBuilder
    private func makeTextEditor() -> some View {
        AirshipTextField(
            info: self.info,
            constraints: constraints,
            alignment: self.textFieldAlignment,
            binding: self.$viewModel.input,
            isEditing: $isEditing
        )
    }

    var showSMSPicker: Bool {
        guard
            self.info.properties.inputType == .sms,
            self.viewModel.availableLocales != nil
        else {
            return false
        }
        return true
    }

    @ViewBuilder
    private func smsPicker() -> some View {
#if !os(watchOS)
        SmsLocalePicker(
            selectedLocale: $viewModel.selectedSMSLocale,
            availableLocales: self.viewModel.availableLocales ?? [],
            fontSize: scaledFontSize
        )
#else
        EmptyView()
#endif
    }

    var textFieldAlignment: Alignment {
        return switch(self.info.properties.inputType) {
        case .email, .text, .number, .sms: .center
        case .textMultiline: .top
        }
    }

    var placeHolderAlignment: Alignment {
        let textAlignment = self.info.properties.textAppearance.alignment ?? .start

        let horizontalAlignment: HorizontalAlignment = switch(textAlignment) {
        case .start: .leading
        case .end: .trailing
        case .center: .center
        }

        return Alignment(
            horizontal: horizontalAlignment,
            vertical: self.textFieldAlignment.vertical
        )
    }

    @ViewBuilder
    private func textInputContent() -> some View {
        ZStack {
            if let hint = self.info.properties.placeholder ?? self.viewModel.selectedSMSLocale?.prefix {
                Text(hint)
                    .textAppearance(placeHolderTextAppearance(), colorScheme: colorScheme)
                    .padding(5)
                    .constraints(constraints, alignment: self.placeHolderAlignment)
                    .opacity(self.viewModel.input.isEmpty && !isEditing ? 1 : 0)
                    .animation(.linear(duration: 0.1), value: self.info.properties.placeholder)
                    .accessibilityHidden(true)
            }
            HStack {
                makeTextEditor()
#if !os(watchOS)
                    .airshipApplyIf(self.info.properties.inputType == .email) { view in
                        view.textInputAutocapitalization(.never)
                    }
#endif
                    .id(self.info.properties.identifier)

                if let resolvedIconEndInfo = resolvedIconEndInfo?.icon {
                    let size = scaledFontSize
                    Icons.icon(info: resolvedIconEndInfo, colorScheme: colorScheme, resizable: false)
                        .frame(maxWidth: size, maxHeight: size)
                        .padding(5)
                }
            }
        }
    }

    @ViewBuilder
    var body: some View {
        HStack {
            if showSMSPicker {
                smsPicker()
                    .padding(.vertical, 5)
                    .padding(.leading, 5)
            }
            
            textInputContent()
        }
#if !os(watchOS)
        .keyboardType(keyboardType)
        .airshipApplyIf(self.info.properties.inputType == .email) { view in
            view.textContentType(.emailAddress)
        }
        .airshipApplyIf(self.info.properties.inputType == .sms) { view in
            view.textContentType(.telephoneNumber)
        }
#endif
        .thomasCommon(self.info)
        .accessible(
            self.info.accessible,
            associatedLabel: associatedLabel,
            hideIfDescriptionIsMissing: false
        )
        .formElement()
        .onAppear {
            let (value, locale) = restoredValue()
            viewModel.setInitialValue(value, locale: locale)
            validatableHelper.subscribe(
                forIdentifier: info.properties.identifier,
                formState: formState,
                initialValue: self.viewModel.input,
                valueUpdates: self.viewModel.$input,
                validatables: info.validation
            ) { [weak thomasState, weak viewModel] actions in
                guard let thomasState, let viewModel else { return }
                thomasState.processStateActions(
                    actions,
                    formFieldValue: viewModel.formField?.input
                )
            }
        }
        .onReceive(self.viewModel.$formField) { field in
            guard let field else { return }
            self.formDataCollector.updateField(field, pageID: pageID)
        }
    }

    private var resolvedIconEndInfo: ThomasViewInfo.TextInput.IconEndInfo? {
        return ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: self.info.overrides?.iconEnd,
            defaultValue: self.info.properties.iconEnd ?? nil
        )
    }

    private func handleStateActions(_ stateActions: [ThomasStateAction]) {
        thomasState.processStateActions(
            stateActions,
            formFieldValue: self.viewModel.formField?.input
        )
    }
    
    private func restoredValue() -> (String?, ThomasSMSLocale?) {
        let identifier = self.info.properties.identifier
        switch(self.info.properties.inputType, formState.fieldValue(identifier: identifier)) {
        case(.email, .email(let value)),
            (.number, .text(let value)),
            (.text, .text(let value)),
            (.textMultiline, .text(let value)):
            return (value, nil)
        case (.sms, .sms(let value, let locale)):
            return (value, locale)
        default:
            return (nil, nil)
        }
    }

    private func placeHolderTextAppearance() -> ThomasTextAppearance {
        guard let color = self.info.properties.textAppearance.placeHolderColor else {
            return self.info.properties.textAppearance
        }

        var appearance = self.info.properties.textAppearance
        appearance.color = color
        return appearance
    }

    @MainActor
    fileprivate final class ViewModel: ObservableObject {
        private let inputProperties: ThomasViewInfo.TextInput.Properties
        private let isRequired: Bool

        private var inputValidator: (any AirshipInputValidation.Validator)? {
            guard Airship.isFlying else { return nil }
            return Airship.inputValidator
        }

        @Published
        var formField: ThomasFormField?
        private var lastInput: String?
        
        @Published
        var selectedSMSLocale: ThomasSMSLocale?
        let availableLocales: [ThomasSMSLocale]?

        @Published
        var input: String = "" {
            didSet {
                if !self.input.isEmpty, !didEdit {
                    didEdit = true
                }
                self.updateFormData()
            }
        }

        @Published
        var didEdit: Bool = false

        init(
            inputProperties: ThomasViewInfo.TextInput.Properties,
            isRequired: Bool,
        ) {
            self.inputProperties = inputProperties
            self.isRequired = isRequired
            self.availableLocales = inputProperties.smsLocales
            self.selectedSMSLocale = inputProperties.smsLocales?.first
        }
        
        func setInitialValue(_ value: String?, locale: ThomasSMSLocale?) {
            guard self.formField == nil else { return }
            
            if
                let locale,
                inputProperties.smsLocales?.contains(where: { $0 == locale }) == true {
                self.selectedSMSLocale = locale
            }
            
            self.formField = self.makeFormField(input: value ?? "")
            self.input = value ?? ""
        }

        private func updateFormData() {
            guard lastInput != self.input else {
                return
            }
            self.lastInput = self.input
            self.formField = self.makeFormField(input: input)
        }

        private func makeAttributes(value: String) -> [ThomasFormField.Attribute]? {
            guard
                !value.isEmpty,
                let name = inputProperties.attributeName
            else {
                return nil
            }

            return [
                ThomasFormField.Attribute(
                    attributeName: name,
                    attributeValue: .string(value)
                )
            ]
        }

        private func makeChannels(
            value: String,
            selectedSMSLocale: ThomasSMSLocale? = nil
        ) -> [ThomasFormField.Channel]? {
            guard !value.isEmpty else { return nil }

            switch(self.inputProperties.inputType) {
            case .email:
                return if let options = self.inputProperties.emailRegistration {
                    [.email(value, options)]
                } else {
                    nil
                }
            case .sms:
                return if let options = selectedSMSLocale?.registration {
                    [.sms(value, options)]
                } else {
                    nil
                }
            case .number, .text, .textMultiline: return nil
            }
        }

        private func makeFormField(input: String) -> ThomasFormField {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            switch(self.inputProperties.inputType) {

            case .email:
                guard !trimmed.isEmpty else {
                    return if isRequired {
                        ThomasFormField.invalidField(
                            identifier: inputProperties.identifier,
                            input: .email(input)
                        )
                    } else {
                        ThomasFormField.validField(
                            identifier: inputProperties.identifier,
                            input: .email(input),
                            result: .init(value: .email(nil))
                        )
                    }
                }

                let request: AirshipInputValidation.Request = .email(
                    AirshipInputValidation.Request.Email(
                        rawInput: input
                    )
                )

                return ThomasFormField.asyncField(
                    identifier: inputProperties.identifier,
                    input: .email(input),
                    processDelay: 1.5
                ) { [inputValidator, weak self] in

                    guard let inputValidator else { return .invalid }

                    let result = try await inputValidator.validateRequest(
                        request
                    )

                    guard let self else { return .invalid }

                    switch (result) {
                    case .invalid:
                        return .invalid
                    case .valid(let address):
                        return .valid(
                            .init(
                                value: .email(address),
                                channels: self.makeChannels(value: address),
                                attributes: self.makeAttributes(value: address)
                            )
                        )
                    }
                }
            case .sms:

                guard !trimmed.isEmpty, let selectedSMSLocale else {
                    return if isRequired {
                        ThomasFormField.invalidField(
                            identifier: inputProperties.identifier,
                            input: .sms(input, selectedSMSLocale)
                        )
                    } else {
                        ThomasFormField.validField(
                            identifier: inputProperties.identifier,
                            input: .sms(input, selectedSMSLocale),
                            result: .init(value: .sms(nil, nil))
                        )
                    }
                }

                let request: AirshipInputValidation.Request = .sms(
                    AirshipInputValidation.Request.SMS(
                        rawInput: input,
                        validationOptions: .prefix(prefix: selectedSMSLocale.prefix),
                        validationHints: .init(
                            minDigits: selectedSMSLocale.validationHints?.minDigits,
                            maxDigits: selectedSMSLocale.validationHints?.maxDigits
                        )
                    )
                )

                return ThomasFormField.asyncField(
                    identifier: inputProperties.identifier,
                    input: .sms(input, selectedSMSLocale)
                ) { [weak self, inputValidator] in
                    guard let inputValidator else { return .invalid }

                    let result = try await inputValidator.validateRequest(request)
                    guard let self else { return .invalid }

                    switch (result) {
                    case .invalid:
                        return .invalid
                    case .valid(let address):
                        return .valid(
                            .init(
                                value: .sms(address, selectedSMSLocale),
                                channels: self.makeChannels(
                                    value: address,
                                    selectedSMSLocale: selectedSMSLocale
                                ),
                                attributes: self.makeAttributes(value: address)
                            )
                        )
                    }
                }
            case .number, .text, .textMultiline:
                return if trimmed.isEmpty, isRequired {
                    ThomasFormField.invalidField(
                        identifier: inputProperties.identifier,
                        input: .text(input)
                    )
                } else {
                    ThomasFormField.validField(
                        identifier: inputProperties.identifier,
                        input: .text(input),
                        result: .init(
                            value: .text(trimmed),
                            attributes: self.makeAttributes(value: trimmed)
                        )
                    )
                }
            }
        }
    }
}

struct AirshipTextField: View {
    @Environment(\.sizeCategory) private var sizeCategory

    private let info: ThomasViewInfo.TextInput
    private let constraints: ViewConstraints
    private let alignment: Alignment

    @Binding private var binding: String
    @Binding private var isEditing: Bool

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var viewState: ThomasState

    @FocusState private var focused: Bool

    @State private var icon: ThomasViewInfo.TextInput.IconEndInfo?

    init(
        info: ThomasViewInfo.TextInput,
        constraints: ViewConstraints,
        alignment: Alignment,
        binding: Binding<String>,
        isEditing: Binding<Bool>
    ) {
        self.info = info
        self.constraints = constraints
        self.alignment = alignment
        self._binding = binding
        self._isEditing = isEditing
    }

    var body: some View {
        let isMultiline = self.info.properties.inputType == .textMultiline
        let axis: Axis = isMultiline ? .vertical : .horizontal

        return TextField("", text: $binding, axis: axis)
            .padding(5)
            .constraints(constraints, alignment: alignment)
            .focused($focused)
            .foregroundColor(self.info.properties.textAppearance.color.toColor(colorScheme))
            .contentShape(Rectangle())
            .onTapGesture {
                self.focused = true
            }
            .applyViewAppearance(self.info.properties.textAppearance, colorScheme: colorScheme)
            .airshipApplyIf(isUnderlined, transform: { content in
                content.underline()
            })
            .airshipOnChangeOf(focused) { newValue in
                if (newValue) {
                    self.thomasEnvironment.focusedID = self.info.properties.identifier
                } else if (self.thomasEnvironment.focusedID == self.info.properties.identifier) {
                    self.thomasEnvironment.focusedID = nil
                }

                isEditing = newValue
            }
            .airshipApplyIf(isMultiline) { view in
                view.airshipOnChangeOf(binding) { [binding] newValue in
                    let oldCount = binding.filter { $0 == "\n" }.count
                    let newCount = newValue.filter { $0 == "\n" }.count

                    if (newCount == oldCount + 1) {
                        // Only update if values are different
                        if newValue != binding {
                            self.binding = binding
                        }
                        self.focused = false
                    }
                }
            }
    }

    private var isUnderlined : Bool {
        if let styles = self.info.properties.textAppearance.styles {
            if styles.contains(.underlined) {
                return true
            }
        }
        return false
    }
    
}


fileprivate extension String {
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
}
