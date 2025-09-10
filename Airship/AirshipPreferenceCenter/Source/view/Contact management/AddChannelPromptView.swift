/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

public enum AddChannelState {
    case failedInvalid
    case failedDefault
    case succeeded
    case ready
    case loading
}

struct AddChannelPromptView: View, Sendable {
    // MARK: - Constants
    private enum Layout {
        static let standardSpacing: CGFloat = 20
        static let buttonTopPadding: CGFloat = 10
        static let maxWidth: CGFloat = 500  // Consistent max width for sheets
    }

    // MARK: - Environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @StateObject private var viewModel: AddChannelPromptViewModel
    @State private var showSuccessAlert = false

    // MARK: - Initialization
    init(viewModel: AddChannelPromptViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Computed Properties
    private var errorMessage: String? {
        switch viewModel.state {
        case .failedInvalid:
            return viewModel.platform?.errorMessages?.invalidMessage
        case .failedDefault:
            return viewModel.platform?.errorMessages?.defaultMessage
        default:
            return nil
        }
    }

    private var isLoading: Bool {
        viewModel.state == .loading
    }

    private var isInputValid: Bool {
        !viewModel.inputText.isEmpty
    }

    private var hasError: Bool {
        viewModel.state == .failedInvalid || viewModel.state == .failedDefault
    }

    private var successAlertTitle: String {
        viewModel.item.onSubmit?.title ?? "Success"
    }

    // MARK: - Body
    var body: some View {
        #if os(tvOS)
        // On tvOS, use a simpler structure without NavigationView
        promptContentView
            .interactiveDismissDisabled(isLoading)
            .airshipOnChangeOf(viewModel.state) { newState in
                handleStateChange(newState)
            }
            .alert(
                successAlertTitle,
                isPresented: $showSuccessAlert,
                presenting: viewModel.item.onSubmit
            ) { successPrompt in
                successAlertButton(for: successPrompt)
            } message: { successPrompt in
                successAlertMessage(for: successPrompt)
            }
        #else
        NavigationView {
            promptContentView
                .frame(maxWidth: Layout.maxWidth)
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(isLoading)
        .airshipOnChangeOf(viewModel.state) { newState in
            handleStateChange(newState)
        }
        .alert(
            successAlertTitle,
            isPresented: $showSuccessAlert,
            presenting: viewModel.item.onSubmit
        ) { successPrompt in
            successAlertButton(for: successPrompt)
        } message: { successPrompt in
            successAlertMessage(for: successPrompt)
        }
        #endif
    }

    // MARK: - View Components

    @ViewBuilder
    private var promptContentView: some View {
        #if os(tvOS)
        // tvOS: Custom header with title and cancel button
        VStack(spacing: 0) {
            // Custom header bar
            HStack {
                Text(viewModel.item.display.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("ua_cancel_edit_messages".preferenceCenterLocalizedString) {
                    handleCancellation()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.standardSpacing) {
                    descriptionSection
                    inputSection
                    errorSection
                    submitButtonSection
                    footerSection
                    
                    Spacer(minLength: Layout.standardSpacing)
                }
                .padding()
            }
        }
        .airshipOnChangeOf(viewModel.inputText) { _ in
            resetErrorStateIfNeeded()
        }
        #else
        // iOS and other platforms: Use navigation bar
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.standardSpacing) {
                descriptionSection
                inputSection
                errorSection
                submitButtonSection
                footerSection

                Spacer(minLength: Layout.standardSpacing)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(viewModel.item.display.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }
        }
        .airshipOnChangeOf(viewModel.inputText) { _ in
            resetErrorStateIfNeeded()
        }
        #endif
    }

    @ViewBuilder
    private var descriptionSection: some View {
        if let bodyText = viewModel.item.display.body {
            Text(bodyText)
                .textAppearance(
                    viewModel.theme?.subtitleAppearance,
                    base: PreferenceCenterDefaults.sectionSubtitleAppearance,
                    colorScheme: colorScheme
                )
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        ChannelTextField(
            platform: viewModel.platform,
            selectedSender: $viewModel.selectedSender,
            inputText: $viewModel.inputText,
            theme: viewModel.theme
        )
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = errorMessage {
            ErrorLabel(
                message: errorMessage,
                theme: viewModel.theme
            )
        }
    }

    @ViewBuilder
    private var submitButtonSection: some View {
        submitButton
            .padding(.top, Layout.buttonTopPadding)
    }

    @ViewBuilder
    private var footerSection: some View {
        if let footer = viewModel.item.display.footer {
            FooterView(
                text: footer,
                textAppearance: viewModel.theme?.subtitleAppearance ?? PreferenceCenterDefaults.subtitleAppearance
            )
            .padding(.top, Layout.standardSpacing)
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        Button(action: handleSubmission) {
            HStack {
                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text(viewModel.item.submitButton.text)
                }

                Spacer()
            }
        }
        .buttonStyle(.borderedProminent)
#if !os(tvOS)
        .controlSize(.large)
#endif
        .disabled(isLoading || !isInputValid)
        .optAccessibilityLabel(
            string: viewModel.item.submitButton.contentDescription
        )
    }

    @ViewBuilder
    private var cancelButton: some View {
        Button("ua_cancel_edit_messages".preferenceCenterLocalizedString) {
            handleCancellation()
        }
        .disabled(isLoading)
    }

    // MARK: - Alert Components
    @ViewBuilder
    private func successAlertButton(for successPrompt: PreferenceCenterConfig.ContactManagementItem.ActionableMessage) -> some View {
        Button {
            handleSuccessCompletion()
        } label: {
            Text(successPrompt.button.text)
        }
    }

    @ViewBuilder
    private func successAlertMessage(for successPrompt: PreferenceCenterConfig.ContactManagementItem.ActionableMessage) -> some View {
        if let body = successPrompt.body {
            Text(body)
        }
    }

    // MARK: - Actions
    private func handleStateChange(_ newState: AddChannelState) {
        guard newState == .succeeded else { return }

        if viewModel.item.onSubmit != nil {
            showSuccessAlert = true
        } else {
            handleSuccessCompletion()
        }
    }

    private func handleSubmission() {
        viewModel.attemptSubmission()
    }

    private func handleCancellation() {
        viewModel.onCancel()
        dismiss()
    }

    private func handleSuccessCompletion() {
        viewModel.onSubmit()
        dismiss()
    }

    private func resetErrorStateIfNeeded() {
        guard hasError else { return }

        withAnimation {
            viewModel.state = .ready
        }
    }
}

// MARK: - Extensions
extension PreferenceCenterConfig.ContactManagementItem.Platform {
    var inputLabel: String {
        switch self {
        case .sms:
            return "Phone Number"
        case .email:
            return "Email Address"
        }
    }
}
