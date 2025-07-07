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

struct AddChannelPromptView: View, Sendable {
    @Environment(\.colorScheme)
    private var colorScheme

    @StateObject
    private var viewModel: AddChannelPromptViewModel

    init(viewModel: AddChannelPromptViewModel) {
        _viewModel = StateObject(
            wrappedValue: viewModel
        )
    }

    private var errorMessage: String? {
        switch self.viewModel.state {
        case .failedInvalid:
            return self.viewModel.platform?.errorMessages?.invalidMessage
        case .failedDefault:
            return self.viewModel.platform?.errorMessages?.defaultMessage
        default:
            return nil
        }
    }

    @ViewBuilder
    var foregroundContent: some View {
        switch self.viewModel.state {
        case .succeeded:
            if self.viewModel.item.onSubmit != nil {
                /// When we have submitted successfully users see a follow up prompt telling them to check their messaging app, email inbox, etc.
                ResultPromptView(
                    item: self.viewModel.item.onSubmit,
                    theme: viewModel.theme
                ) {
                    viewModel.onSubmit()
                }
                .transition(.opacity)
            } else {
                Rectangle()
                    .foregroundColor(Color.clear)
                    .onAppear {
                        viewModel.onSubmit()
                    }
            }
        case .ready, .loading, .failedInvalid, .failedDefault:
            promptView
        }
    }

    @ViewBuilder
    var body: some View {
        foregroundContent.backgroundWithCloseAction {
            self.viewModel.onCancel()
        }
        .frame(
            minWidth: PreferenceCenterDefaults.promptMinWidth,
            maxWidth: PreferenceCenterDefaults.promptMaxWidth
        )
    }

    // MARK: Prompt view
    @ViewBuilder
    private var titleText: some View {
        Text(self.viewModel.item.display.title)
            .textAppearance(
                viewModel.theme?.titleAppearance,
                base: PreferenceCenterDefaults.sectionTitleAppearance,
                colorScheme: colorScheme
            )
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var bodyText: some View {
        if let bodyText = self.viewModel.item.display.body {
            Text(bodyText)
                .textAppearance(
                    viewModel.theme?.subtitleAppearance,
                    base: PreferenceCenterDefaults.sectionSubtitleAppearance,
                    colorScheme: colorScheme
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
                isEnabled: true,
                isLoading: viewModel.state == .loading,
                theme: viewModel.theme
            ) {
                viewModel.attemptSubmission()
            }
            .disabled(isLoading)
            .airshipApplyIf(isLoading) { content in
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
            FooterView(text: footer, textAppearance: viewModel.theme?.subtitleAppearance ?? PreferenceCenterDefaults.subtitleAppearance)
        }
    }

    @ViewBuilder
    private var promptViewContent: some View {
        VStack(alignment: .leading) {
            titleText
                .padding(.bottom)
                .padding(.trailing) // Pad out to prevent aliasing with the close button

            bodyText
            ChannelTextField(
                platform: viewModel.platform,
                selectedSender: $viewModel.selectedSender,
                inputText: $viewModel.inputText,
                theme: viewModel.theme
            )
            errorText
            submitButton
            footer
        }
    }

    @ViewBuilder
    private var promptView: some View {
        let dismissButtonColor = colorScheme.airshipResolveColor(
            light: viewModel.theme?.buttonLabelAppearance?.color,
            dark: viewModel.theme?.buttonLabelAppearance?.colorDark
        )

        GeometryReader { proxy in
            promptViewContent
                .padding()
                .addPromptBackground(
                    theme: viewModel.theme,
                    colorScheme: colorScheme
                )
                .addPreferenceCloseButton(
                    dismissButtonColor: dismissButtonColor ?? .primary,
                    dismissIconResource: "xmark",
                    contentDescription: nil,
                    onUserDismissed: {
                        self.viewModel.onCancel()
                    }
                )
                .padding()
                .position(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
                .transition(.opacity)
                .airshipOnChangeOf(viewModel.inputText) { newValue in
                    /// Resets the text to valid ready state since user is trying
                    withAnimation {
                        self.viewModel.state = .ready
                    }
                }
        }
        .accessibilityAddTraits(.isModal)
    }
}
