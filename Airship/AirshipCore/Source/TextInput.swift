/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

struct TextInput: View {

    let info: ThomasViewInfo.TextInput
    let constraints: ViewConstraints

    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var thomasState: ThomasState

    @State private var isEditing: Bool = false
    @State private var lastResult: ThomasInputValidator.Result? = nil

    @StateObject private var viewModel: ViewModel

    init(info: ThomasViewInfo.TextInput, constraints: ViewConstraints) {
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
        }
    }
#endif

    @ViewBuilder
    private func createTextEditor() -> some View {
        if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            AirshipTextField(
                info: self.info,
                constraints: constraints,
                binding: self.$viewModel.input,
                isEditing: $isEditing
            )
        } else {
#if !os(watchOS)
            AirshipTextView(
                textAppearance: self.info.properties.textAppearance,
                text: self.$viewModel.input,
                isEditing: $isEditing
            )
            .constraints(constraints, alignment: .topLeading)
            .airshipOnChangeOf(self.isEditing) { newValue in
                let focusedID = newValue ? self.info.properties.identifier : nil
                self.thomasEnvironment.focusedID = focusedID
            }

#endif
        }
    }

    @ViewBuilder
    var body: some View {
        ZStack {
            if let hint = self.info.properties.placeholder {
                Text(hint)
                    .textAppearance(placeHolderTextAppearance())
                    .padding(5)
                    .constraints(constraints, alignment: self.info.properties.textAppearance.alignment?.placeholderAlignment ?? .topLeading)
                    .opacity(self.viewModel.input.isEmpty && !isEditing ? 1 : 0)
                    .animation(.linear(duration: 0.1), value: self.info.properties.placeholder)
            }
            HStack {
                createTextEditor()
#if !os(watchOS)
                    .airshipApplyIf(self.info.properties.inputType == .email) { view in
                        view.textInputAutocapitalization(.never)
                    }
#endif
                    .id(self.info.properties.identifier)

                if let resolvedIconEndInfo = resolvedIconEndInfo?.icon {
                    let maxIconWidth = self.info.properties.textAppearance.fontSize
                    let maxIconHeight = maxIconWidth

                    Icons.icon(info: resolvedIconEndInfo, colorScheme: colorScheme, resizable: false)
                        .frame(maxWidth: maxIconWidth, maxHeight: maxIconHeight)
                        .padding(5)
                }
            }
        }
#if !os(watchOS)
        .keyboardType(keyboardType)
        .airshipApplyIf(self.info.properties.inputType == .email) { view in
            view.textContentType(.emailAddress)
        }
#endif
        .thomasCommon(self.info)
        .accessible(self.info.accessible)
        .formElement()
        .onAppear {
            restoreFormState()
        }
        .airshipOnChangeOf(self.formState.validationIssues) { _ in
            // We only want to update the validation status on change
            // of validation issues when we are in immediate mode. The
            // onValidate mode we only update when the status updates
            // or if we edit the value.
            guard self.formState.validationMode == .immediate else { return }
            updateValidationState()
        }
        .airshipOnChangeOf(self.formState.status) { status in
            // Only update if the status is valid or invalid
            guard status == .valid || status == .invalid else { return }
            updateValidationState()
        }
        .onReceive(self.viewModel.$formData) { data in
            if let data {
                self.formState.updateFormInput(data)
                switch(self.formState.validationMode) {
                case .onDemand:
                    self.info.validation.onEdit?.stateActions.map(handleStateActions)
                case .immediate:
                    updateValidationState()
                }
            }
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
        thomasState.processStateActions(stateActions, formInput: self.viewModel.formData)
    }

    private func restoreFormState() {
        guard
            case let .text(value) = self.formState.data.input(
                identifier: self.info.properties.identifier
            )?.value,
            let value = value
        else {
            return
        }

        if (self.viewModel.input != value) {
            self.viewModel.input = value
        }
    }

    @MainActor
    private func updateValidationState() {
        let currentStatus = self.formState.childValidationStatus(
            child: self.info.properties.identifier
        )

        guard let currentStatus else {
            self.info.validation.onEdit?.stateActions.map(handleStateActions)
            return
        }

        switch(currentStatus) {
        case .valid:
            if self.viewModel.trimmedInput.isEmpty, let onEdit = self.info.validation.onEdit {
                onEdit.stateActions.map(handleStateActions)
            } else {
                self.info.validation.onValid?.stateActions.map(handleStateActions)
            }
        case .invalid:
            // Only update for an error state if the field has been edited
            // or if the form is in onValidate mode to prevent the intial
            // error on required fields.
            guard self.viewModel.didEdit || self.formState.validationMode == .onDemand else {
                return
            }
            self.info.validation.onError?.stateActions.map(handleStateActions)
        case .error:
            // ignore
            break
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
        private let inputValidator: AirshipInputValidator = AirshipInputValidator()

        @Published
        var formData: ThomasFormInput?
        private var lastInput: String?

        @Published
        var input: String = "" {
            didSet {
                if !self.input.isEmpty, !didEdit {
                    didEdit = true
                }
                self.updateFormData()
            }
        }

        var trimmedInput: String {
            self.input.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        @Published
        var didEdit: Bool = false

        init(inputProperties: ThomasViewInfo.TextInput.Properties, isRequired: Bool) {
            self.inputProperties = inputProperties
            self.isRequired = isRequired
            updateFormData()
        }

        private func attribute(value: String) -> ThomasFormInput.Attribute? {
            guard
                !value.isEmpty,
                let name = inputProperties.attributeName
            else {
                return nil
            }

            return ThomasFormInput.Attribute(
                attributeName: name,
                attributeValue: .string(value)
            )
        }

        private func updateFormData() {
            let trimmedInput = self.trimmedInput
            guard lastInput != trimmedInput else {
                return
            }
            self.lastInput = trimmedInput

            guard !trimmedInput.isEmpty else {
                let value: ThomasFormInput.Value = switch(self.inputProperties.inputType) {
                case .email: .emailText(nil)
                case .number, .text, .textMultiline: .text(nil)
                }

                self.formData = ThomasFormInput(
                    inputProperties.identifier,
                    value: value,
                    validator: .just(!isRequired)
                )

                return
            }

            switch(self.inputProperties.inputType) {
            case .email:
                let email = AirshipInputValidator.Email(trimmedInput)

                var channelRegistration: ThomasFormInput.ChannelRegistration?
                if let options = inputProperties.emailRegistration {
                    channelRegistration = .email(email.address, options)
                }

                self.formData = ThomasFormInput(
                    inputProperties.identifier,
                    value: .emailText(input),
                    attribute: self.attribute(value: input),
                    channelRegistration: channelRegistration,
                    validator: .async { [inputValidator] in
                        return inputValidator.validate(email: email)
                    }
                )
            case .number, .text, .textMultiline:
                self.formData = ThomasFormInput(
                    inputProperties.identifier,
                    value: .text(trimmedInput),
                    attribute: self.attribute(value: trimmedInput),
                    validator: .just(true)
                )
            }
        }
    }

}

@available(iOS 16.0, tvOS 16, watchOS 9.0, *)
struct AirshipTextField: View {

    let info: ThomasViewInfo.TextInput
    let constraints: ViewConstraints

    @Binding var binding: String
    @Binding var isEditing: Bool

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject var viewState: ThomasState

    @FocusState private var focused: Bool

    @State var icon: ThomasViewInfo.TextInput.IconEndInfo?

    var body: some View {
        let isMultiline = self.info.properties.inputType == .textMultiline
        let axis: Axis = isMultiline ? .vertical : .horizontal

        return TextField("", text: $binding, axis: axis)
            .padding(5)
            .constraints(constraints, alignment: .topLeading)
            .focused($focused)
            .foregroundColor(self.info.properties.textAppearance.color.toColor(colorScheme))
            .contentShape(Rectangle())
            .onTapGesture {
                self.focused = true
            }
            .applyViewAppearance(self.info.properties.textAppearance)
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


#if !os(watchOS)
/// TextView

internal struct AirshipTextView: UIViewRepresentable {
    let textAppearance: ThomasTextAppearance
    @Binding var text: String
    @Binding var isEditing: Bool

    @Environment(\.colorScheme) var colorScheme
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        /// Set textView background color to clear to can set the parent background color instead
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator

#if os(iOS)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: textView,
            action: #selector(textView.resignFirstResponder)
        )

        let flexSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        toolbar.items = [flexSpace, done]
        textView.inputAccessoryView = toolbar
#endif

        textView.applyTextAppearance(self.textAppearance, colorScheme)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.applyTextAppearance(self.textAppearance, colorScheme)
        uiView.textModifyAppearance(self.textAppearance)
        if uiView.text.isEmpty && !self.text.isEmpty {
            uiView.text = self.text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator($text, isEditing: $isEditing)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isEditing: Binding<Bool>

        let subject = PassthroughSubject<String, Never>()
        let cancellable: any Cancellable

        init(_ text: Binding<String>, isEditing: Binding<Bool>) {
            self.text = text
            self.isEditing = isEditing
            self.cancellable =
            subject
                .debounce(for: .seconds(0.2), scheduler: RunLoop.main)
                .sink {
                    text.wrappedValue = $0
                }
        }

        func textViewDidChange(_ textView: UITextView) {
            subject.send(textView.text)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            self.isEditing.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            self.isEditing.wrappedValue = false
        }
    }
}

extension UITextView {
    func applyTextAppearance(
        _ textAppearance: ThomasTextAppearance?,
        _ colorScheme: ColorScheme
    ) {
        if let textAppearance = textAppearance {
            self.textAlignment =
            textAppearance.alignment?.toNSTextAlignment() ?? .center
            self.textColor =
            textAppearance.color.toUIColor(colorScheme)
            self.font = UIFont.resolveUIFont(textAppearance)
        }
    }

    func textModifyAppearance(
        _ textAppearance: ThomasTextAppearance
    ) {
        underlineText(textAppearance)
    }

    func underlineText(
        _ textAppearance: ThomasTextAppearance
    ) {
        if let styles = textAppearance.styles {
            if styles.contains(.underlined) {
                let textRange = NSRange(
                    location: 0,
                    length: self.text.count
                )
                let attributeString = NSMutableAttributedString(
                    attributedString:
                        self.attributedText
                )
                attributeString.addAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: textRange
                )
                self.attributedText = attributeString
            }
        }
    }
}
#endif

extension ThomasTextAppearance.TextAlignement {
    fileprivate var placeholderAlignment: Alignment {
        switch self {
        case .start:
            return Alignment.topLeading
        case .end:
            return Alignment.topTrailing
        case .center:
            return Alignment.top
        }
    }
}

fileprivate extension String {
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
}
