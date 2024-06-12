/* Copyright Airship and Contributors */

import SwiftUI
import Combine

public enum AddChannelState {
    case failedInvalid
    case failedDefault
    case succeeded
    case ready
    case loading
}

struct AddChannelPromptView: View, @unchecked Sendable {
    @StateObject
    private var viewModel: AddChannelPromptViewModel

    /// The minimum alert width - as defined by Apple
    private let promptMinWidth = 270.0

    /// The maximum alert width
    private let promptMaxWidth = 420.0

    init(viewModel: AddChannelPromptViewModel) {
        _viewModel = StateObject(
            wrappedValue: viewModel
        )
    }

    private var errorMessage: String? {
        switch self.viewModel.state {
        case .failedInvalid:
            return self.viewModel.item.errorMessages?.invalidMessage
        case .failedDefault:
            return self.viewModel.item.errorMessages?.defaultMessage
        default:
            return nil
        }
    }

    @ViewBuilder
    var foregroundContent: some View {
        switch self.viewModel.state {
        case .succeeded:
            /// When we have submitted successfully users see a follow up prompt telling them to check their messaging app, email inbox, etc.
            ResultPromptView(
                item: self.viewModel.item.onSuccess,
                theme: viewModel.theme
            ) {
                viewModel.onSubmit() 
            }
            .transition(.opacity)
        case .ready, .loading, .failedInvalid, .failedDefault:
            promptView
        }
    }

    @ViewBuilder
    var body: some View {
        foregroundContent.backgroundWithCloseAction {
            self.viewModel.onCancel()
        }
        .frame(minWidth: promptMinWidth, maxWidth: promptMaxWidth)
    }

    // MARK: Prompt view
    @ViewBuilder
    private var titleText: some View {
        Text(self.viewModel.item.display.title)
            .textAppearance(
                viewModel.theme?.titleAppearance,
                base: DefaultContactManagementSectionStyle.titleAppearance
            )
    }

    @ViewBuilder
    private var bodyText: some View {
        if let bodyText = self.viewModel.item.display.body {
            Text(bodyText)
                .textAppearance(
                    viewModel.theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if self.viewModel.state == .failedDefault || self.viewModel.state == .failedInvalid,
           let errorMessage = errorMessage {
            ErrorLabel(
                message: errorMessage,
                theme: viewModel.theme
            )
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        let isLoading = viewModel.state == .loading
        HStack {
            Spacer()

            /// Submit button
            LabeledButton(
                item: viewModel.item.submitButton,
                isEnabled: viewModel.isInputFormatValid,
                isLoading: viewModel.state == .loading,
                theme: viewModel.theme
            ) {
                viewModel.attemptSubmission()
            }
            .disabled(isLoading)
            .applyIf(isLoading) { content in
                content.overlay(
                    ProgressView(),
                    alignment: .center
                )
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        /// Footer
        if let footer = self.viewModel.item.display.footer {
            Text(LocalizedStringKey(footer)) /// Markdown parsing in iOS15+
                .textAppearance(
                    viewModel.theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var promptViewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleText.padding(.trailing, 16) // Pad out to prevent aliasing with the close button
            bodyText

            /// Channel Input text fields
            ChannelTextField(
                registrationOptions: viewModel.registrationOptions,
                selectedSender: $viewModel.selectedSender,
                inputText: $viewModel.inputText,
                theme: viewModel.theme
            )

            errorText
            submitButton
            footer
        }
    }

    private var promptView: some View {
        GeometryReader { proxy in
            promptViewContent
                .padding(16)
                .addBackground(theme: viewModel.theme)
                .addPreferenceCloseButton(dismissButtonColor: .primary, dismissIconResource: "xmark", onUserDismissed: {
                    self.viewModel.onCancel()
                })
                .padding(16)
                .position(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
                .transition(.opacity)
                .onChange(of: viewModel.inputText) { newValue in
                    let isValid = viewModel.validateInputFormat()

                    withAnimation {
                        self.viewModel.isInputFormatValid = isValid

                        if isValid {
                            self.viewModel.state = .ready
                        }
                    }
                }
        }
    }
}
