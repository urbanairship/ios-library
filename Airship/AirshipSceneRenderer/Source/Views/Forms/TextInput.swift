/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

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
        AirshipFont.scaledSize(self.info.properties.textAppearance.fontSize)
    }

    init(
        info: ThomasViewInfo.TextInput,
        constraints: ViewConstraints,
        inputValidator: (any AirshipInputValidation.Validator)?,
        aiInferenceExecutor: (any SceneAIExecutor)?
    ) {
        self.info = info
        self.constraints = constraints

        self._viewModel = StateObject(
            wrappedValue: ViewModel(
                inputProperties: info.properties,
                isRequired: info.validation.isRequired ?? false,
                inputValidator: inputValidator,
                aiInferenceExecutor: aiInferenceExecutor
            )
        )
    }

#if !os(watchOS) && !os(macOS)
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

    private var showSMSPicker: Bool {
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

    private var textFieldAlignment: Alignment {
        return switch(self.info.properties.inputType) {
        case .email, .text, .number, .sms: .center
        case .textMultiline: .top
        }
    }

    private var placeHolderAlignment: Alignment {
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
#if !os(watchOS) && !os(macOS)
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
#if !os(watchOS) && !os(macOS)
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
            ) { [weak thomasState = thomasState, weak viewModel = viewModel] outcomes in
                guard let thomasState, let viewModel else { return }
                thomasState.processSync(
                    outcomes: outcomes,
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
    
    private func restoredValue() -> (String?, ThomasSMSLocale?) {
        let identifier = self.info.properties.identifier
        switch(self.info.properties.inputType, formState.fieldValue(identifier: identifier)) {
        case(.email, .email(let value)),
            (.number, .text(let value, _, _)),
            (.text, .text(let value, _, _)),
            (.textMultiline, .text(let value, _, _)):
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
    private final class ViewModel: ObservableObject {
        /// How long the input must be idle before it's sent to the on-device model.
        /// Longer than validation's delay — evaluations are expensive.
        private static let aiInferenceProcessDelay: TimeInterval = 2.0

        private let inputProperties: ThomasViewInfo.TextInput.Properties
        private let isRequired: Bool

        private let inputValidator: (any AirshipInputValidation.Validator)?
        private let aiInferenceExecutor: (any SceneAIExecutor)?

        /// The last completed inference, so unchanged text (e.g. the restore path
        /// re-making the field, or trailing-whitespace edits) reuses the result
        /// instead of re-running the model. Carries both the state projection payload
        /// and the reportable `ai_inference` payload.
        private var lastInference: (text: String, output: AirshipJSON, report: ThomasAIInferenceReport)?

        @Published
        fileprivate var formField: ThomasFormField?
        private var lastInput: String?

        @Published
        fileprivate var selectedSMSLocale: ThomasSMSLocale?
        fileprivate let availableLocales: [ThomasSMSLocale]?

        @Published
        fileprivate var input: String = "" {
            didSet {
                if !self.input.isEmpty, !didEdit {
                    didEdit = true
                }
                self.updateFormData()
            }
        }

        @Published
        private var didEdit: Bool = false

        init(
            inputProperties: ThomasViewInfo.TextInput.Properties,
            isRequired: Bool,
            inputValidator: (any AirshipInputValidation.Validator)?,
            aiInferenceExecutor: (any SceneAIExecutor)?
        ) {
            self.inputProperties = inputProperties
            self.isRequired = isRequired
            self.inputValidator = inputValidator
            self.aiInferenceExecutor = aiInferenceExecutor
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
                    @unknown default:
                        return .invalid
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
                    @unknown default:
                        return .invalid
                    }
                }
            case .number, .text, .textMultiline:
                guard !trimmed.isEmpty else {
                    return if isRequired {
                        ThomasFormField.invalidField(
                            identifier: inputProperties.identifier,
                            input: .text(input, aiInference: nil, isRedacted: nil)
                        )
                    } else {
                        ThomasFormField.validField(
                            identifier: inputProperties.identifier,
                            input: .text(input, aiInference: nil, isRedacted: nil),
                            result: .init(
                                value: .text(trimmed, aiInference: nil, isRedacted: inputProperties.redactInput),
                                attributes: self.makeAttributes(value: trimmed)
                            )
                        )
                    }
                }

                var result = ThomasFormField.Result(
                    value: .text(trimmed, aiInference: nil, isRedacted: inputProperties.redactInput),
                    attributes: self.makeAttributes(value: trimmed)
                )

                // Unchanged text — reuse the completed inference instead of
                // re-running the model.
                if let lastInference, lastInference.text == trimmed {
                    result.aiInference = lastInference.output
                    result.value = .text(trimmed, aiInference: lastInference.report, isRedacted: inputProperties.redactInput)
                    return ThomasFormField.validField(
                        identifier: inputProperties.identifier,
                        input: .text(input, aiInference: nil, isRedacted: nil),
                        result: result
                    )
                }

                guard
                    let aiInference = inputProperties.aiInference,
                    let executor = aiInferenceExecutor,
                    executor.isAvailable
                else {
                    // No model right now — fail open without the async settle delay
                    // so the form never waits on inference that can't happen. Mark
                    // the result failed so layouts can branch to a non-AI path.
                    if inputProperties.aiInference != nil {
                        result.aiInference = .object(["status": "failed"])
                        result.value = .text(trimmed, aiInference: ThomasAIInferenceReport.failed, isRedacted: inputProperties.redactInput)
                    }
                    return ThomasFormField.validField(
                        identifier: inputProperties.identifier,
                        input: .text(input, aiInference: nil, isRedacted: nil),
                        result: result
                    )
                }

                // Post-process the text through the on-device model like email/SMS
                // post-process through validation — the async field machinery provides
                // the settle delay, cancellation on newer input, and pending status
                // (the field resolves once inference lands, so its `ai` payload shows
                // up in the form state projection for predicates/branching).
                let request = ThomasAIInferenceRequest(
                    prompt: aiInference.prompt,
                    text: trimmed,
                    outputSchema: aiInference.outputSchema,
                    additionalContext: (aiInference.additionalContext ?? []).map { item in
                        ThomasAIContextItem(
                            content: item.content,
                            priority: item.priority ?? 0.0
                        )
                    },
                    subjectHints: aiInference.subjectHints ?? [:]
                )

                let identifier = inputProperties.identifier

                let redactInput = inputProperties.redactInput
                return ThomasFormField.asyncField(
                    identifier: inputProperties.identifier,
                    input: .text(input, aiInference: nil, isRedacted: nil),
                    processDelay: Self.aiInferenceProcessDelay
                ) { [weak self, executor] in
                    let output = await executor.run(request: request)

                    // A superseded field is cancelled by the form state — bail before
                    // resolving a stale result.
                    try Task.checkCancellation()

                    var ai: [String: AirshipJSON]
                    let report: ThomasAIInferenceReport
                    switch output {
                    case .some(let output):
                        ai = ["result": output, "status": "complete"]
                        // Reported output is filtered to properties opted in via
                        // x-ua-report-property — distinct from the full `ai` projection.
                        report = ThomasAIInferenceReport(
                            output: output,
                            schema: request.outputSchema
                        )
                    case .none:
                        // The executor logs why (unavailable/failed); this logs which
                        // input, the context the executor doesn't have.
                        AirshipLogger.debug("Scene AI inference produced no output for input \(identifier)")
                        ai = ["status": "failed"]
                        report = ThomasAIInferenceReport.failed
                    }

                    var result = result
                    result.aiInference = .object(ai)
                    result.value = .text(trimmed, aiInference: report, isRedacted: redactInput)
                    self?.lastInference = (trimmed, .object(ai), report)

                    // Fail open: inference never invalidates the field itself.
                    return .valid(result)
                }
            }
        }
    }
}

fileprivate struct AirshipTextField: View {
    @Environment(\.sizeCategory) private var sizeCategory

    private let info: ThomasViewInfo.TextInput
    private let constraints: ViewConstraints
    private let alignment: Alignment

    @Binding private var binding: String
    @Binding private var isEditing: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isVisible) private var isVisible
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var viewState: ThomasState

    /// The layout-wide focus authority, owned by RootView. A single source of truth keyed
    /// by input id means this field being recreated (branch re-layout) can't resurrect its
    /// own focus, and navigation resigns focus in one place.
    @Environment(\.thomasFocusedInput) private var focusedInput
    /// Fallback owner used only when there's no layout root (e.g. SwiftUI previews).
    @FocusState private var fallbackFocus: String?

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
        let identifier = self.info.properties.identifier
        // One source of truth for focus: the layout root's, or a local fallback outside one.
        let focusBinding = focusedInput ?? $fallbackFocus

        return TextField("", text: $binding, axis: axis)
            .padding(5)
            .constraints(constraints, alignment: alignment)
            .focused(focusBinding, equals: identifier)
            .foregroundColor(self.info.properties.textAppearance.color.toColor(colorScheme))
            .contentShape(Rectangle())
            // Remove the field from the focus system entirely while its page is
            // off-screen. Resigning focus after the fact loses the race — UIKit
            // re-asserts first responder on the offscreen field and keyboard
            // avoidance scrolls the pager back. Not-focusable can't be re-asserted.
            .airshipFocusableCompat(isVisible)
            .textFieldStyle(.plain)
            .onTapGesture {
                focusBinding.wrappedValue = identifier
            }
            .applyViewAppearance(self.info.properties.textAppearance, colorScheme: colorScheme)
            .airshipApplyIf(isUnderlined, transform: { content in
                content.underline()
            })
            .airshipOnChangeOf(focusBinding.wrappedValue) { newValue in
                // Focus is owned by the root, which mirrors it onto
                // thomasEnvironment.focusedID; here we only track editing state.
                // UIKit can re-assert first responder after a programmatic resign
                // (keyboard bring-up racing the resign, or focus restoration when the
                // lazy page view is recreated). The isVisible guard below can't catch
                // that — it only fires on visibility *transitions*, and these
                // re-asserts land while the page is already offscreen. Left alone, the
                // stale focus makes keyboard avoidance scroll the pager back to this
                // field, undoing navigation.
                if newValue == identifier, !isVisible {
                    focusBinding.wrappedValue = nil
                    return
                }
                isEditing = (newValue == identifier)
            }
            .airshipOnChangeOf(isVisible) { visible in
                // Resign focus when this input's page scrolls away. A focused field
                // stays first responder even off screen, and UIKit's keyboard
                // avoidance will animate the enclosing pager back to it — undoing
                // pager navigation. Clearing the shared authority resigns reliably.
                if !visible, focusBinding.wrappedValue == identifier {
                    focusBinding.wrappedValue = nil
                }
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
                        focusBinding.wrappedValue = nil
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
