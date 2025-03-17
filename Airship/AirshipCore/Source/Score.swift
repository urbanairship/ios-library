/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct Score: View {
    let info: ThomasViewInfo.Score
    let constraints: ViewConstraints

    @State var score: Int?

    @Environment(\.pageIdentifier) var pageID
    @EnvironmentObject var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var thomasState: ThomasState
    @Environment(\.colorScheme) var colorScheme
    @State private var isValid: Bool?

    @ViewBuilder
    private func makeNumberRangeScoreItems(style: ThomasViewInfo.Score.ScoreStyle.NumberRange, constraints: ViewConstraints) -> some View {
        ForEach((style.start...style.end), id: \.self) { index in
            let isOn = Binding(
                get: { self.score == index },
                set: { if $0 { self.score = index } }
            )
            Toggle(isOn: isOn.animation()) {}
                .toggleStyle(
                    AirshipNumberRangeToggleStyle(
                        style: style,
                        viewConstraints: constraints,
                        value: index,
                        colorScheme: colorScheme,
                        disabled: !formState.isFormInputEnabled
                    )
                )
                .airshipGeometryGroupCompat()
        }
    }

    @ViewBuilder
    private func createScore(_ constraints: ViewConstraints) -> some View {
        switch self.info.properties.style {
        case .numberRange(let style):
            if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *), style.wrapping != nil {
                let itemSpacing = CGFloat(style.spacing ?? 0)
                let lineSpacing = CGFloat(style.wrapping?.lineSpacing ?? 0)
                let maxItemsPerLine = style.wrapping?.maxItemsPerLine
                WrappingLayout(
                    viewConstraints: constraints,
                    itemSpacing: itemSpacing,
                    lineSpacing: lineSpacing,
                    maxItemsPerLine: maxItemsPerLine
                ) {
                    makeNumberRangeScoreItems(style: style, constraints: constraints)
                }
            } else {
                HStack(spacing: style.spacing ?? 0) {
                    makeNumberRangeScoreItems(style: style, constraints: constraints)
                }
                .constraints(constraints)
            }
        }
    }

    var body: some View {
        let constraints = modifiedConstraints()
        createScore(constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(self.info.accessible, hideIfDescriptionIsMissing: false)
            .formElement()
            .airshipOnChangeOf(self.score) { score in
                self.updateScore(score)
                if self.isValid != nil {
                    self.info.validation.onEdit?.stateActions.map(handleStateActions)
                    self.isValid = nil
                }
                updateValidationState(self.formState.status)
            }
            .airshipOnChangeOf(self.formState.status) { status in
                guard self.formState.validationMode == .onDemand else { return }
                updateValidationState(status)
            }
            .onAppear {
                self.restoreFormState()
            }
    }

    @MainActor
    private func updateValidationState(
        _ status: ThomasFormState.Status
    ) {
        guard self.formState.validationMode == .onDemand else { return }

        switch (status) {
        case .valid:
            guard self.isValid == true else {
                self.info.validation.onValid?.stateActions.map(handleStateActions)
                self.isValid = true
                return
            }
        case .error, .invalid:
            guard let fieldStatus = self.formState.lastFieldStatus(
                identifier: self.info.properties.identifier
            ) else {
                return
            }

            if fieldStatus.isValid {
                guard self.isValid == true else {
                    self.info.validation.onValid?.stateActions.map(handleStateActions)
                    self.isValid = true
                    return
                }
            } else if fieldStatus == .invalid {
                guard
                    self.isValid == false
                else {
                    self.info.validation.onError?.stateActions.map(handleStateActions)
                    self.isValid = false
                    return
                }
            }
        case .validating, .pendingValidation, .submitted: return
        }
    }

    private func handleStateActions(_ stateActions: [ThomasStateAction]) {
        thomasState.processStateActions(
            stateActions,
            formFieldValue: .score(self.score)
        )
    }
    
    private func modifiedConstraints() -> ViewConstraints {
        var constraints = self.constraints
        if self.constraints.width == nil && self.constraints.height == nil {
            constraints.height = 32
        } else {
            switch self.info.properties.style {
            case .numberRange(let style):
                constraints.height = self.calculateHeight(
                    style: style,
                    width: constraints.width
                )
            }
        }
        return constraints
    }

    func calculateHeight(
        style: ThomasViewInfo.Score.ScoreStyle.NumberRange,
        width: CGFloat?
    ) -> CGFloat? {
        guard let width = width else {
            return nil
        }
        let count = Double((style.start...style.end).count)
        let spacing = (count - 1.0) * (style.spacing ?? 0.0)
        let remainingSpace = width - spacing
        if remainingSpace <= 0 {
            return nil
        }
        return min(remainingSpace / count, 66.0)
    }

    private func attributes(value: Int?) -> [ThomasFormField.Attribute]? {
        guard
            let value,
            let name = info.properties.attributeName
        else {
            return nil
        }

        return [
            ThomasFormField.Attribute(
                attributeName: name,
                attributeValue: .number(Double(value))
            )
        ]
    }

    private func checkValid(_ value: Int?) -> Bool {
        return value != nil || self.info.validation.isRequired != true
    }

    private func updateScore(_ value: Int?) {
        let field: ThomasFormField = if checkValid(value) {
            ThomasFormField.validField(
                identifier: self.info.properties.identifier,
                input: .score(value),
                result: .init(
                    value: .score(value),
                    attributes: self.attributes(value: value)
                )
           )
        } else {
            ThomasFormField.invalidField(
                identifier: self.info.properties.identifier,
                input: .score(value)
            )
        }

        self.formDataCollector.updateField(field, pageID: pageID)
    }

    private func restoreFormState() {
        guard
            case .score(let value) = self.formState.field(
                identifier: self.info.properties.identifier
            )?.input,
            let value
        else {
            self.updateScore(self.score)
            return
        }

        self.score = value
    }
}

private struct AirshipNumberRangeToggleStyle: ToggleStyle {
    let style: ThomasViewInfo.Score.ScoreStyle.NumberRange
    let viewConstraints: ViewConstraints
    let value: Int
    let colorScheme: ColorScheme
    let disabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn

        // Pick which text appearance we should use
        let selectedAppearance = style.bindings.selected.textAppearance
        let unselectedAppearance = style.bindings.unselected.textAppearance
        let appearance = isOn ? selectedAppearance : unselectedAppearance

        let measuredSize = measureTextSize("\(style.end)", with: appearance)

        let minTappableDimension: CGFloat = 44.0

        let fontMetrics = UIFontMetrics.default
        let scaledWidthSpacing = fontMetrics.scaledValue(for: measuredSize.width)
        let scaledHeightSpacing = fontMetrics.scaledValue(for: measuredSize.height)

        let minWidth = max(minTappableDimension, measuredSize.width + scaledWidthSpacing)
        let minHeight = max(minTappableDimension, measuredSize.height + scaledHeightSpacing)

        let maxDimension = max(minWidth, minHeight)

        /// Inject new constraints
        let viewConstraints = ViewConstraints(width: maxDimension,
                                              height: maxDimension,
                                              maxWidth: viewConstraints.maxWidth,
                                              maxHeight: viewConstraints.maxHeight,
                                              isHorizontalFixedSize: viewConstraints.isHorizontalFixedSize,
                                              isVerticalFixedSize: viewConstraints.isVerticalFixedSize,
                                              safeAreaInsets: viewConstraints.safeAreaInsets)

        return Button(action: { configuration.isOn.toggle() }) {
            ZStack {
                // Drawing both with 1 hidden in case the content size changes between the two
                // it will prevent the parent from resizing on toggle
                Group {
                    if let shapes = style.bindings.selected.shapes {
                        ForEach(0..<shapes.count, id: \.self) { index in
                            Shapes.shape(
                                info: shapes[index],
                                constraints: viewConstraints,
                                colorScheme: colorScheme
                            )
                        }
                        .opacity(isOn ? 1 : 0)
                    }
                    Text(String(self.value))
                        .textAppearance(style.bindings.selected.textAppearance)
                }
                .opacity(isOn ? 1 : 0)
                .airshipApplyIf(disabled) { view in
                    view.colorMultiply(ThomasConstants.disabledColor)
                }

                Group {
                    if let shapes = style.bindings.unselected.shapes {
                        ForEach(0..<shapes.count, id: \.self) { index in
                            Shapes.shape(
                                info: shapes[index],
                                constraints: viewConstraints,
                                colorScheme: colorScheme
                            )
                        }
                    }
                    Text(String(self.value))
                        .textAppearance(
                            style.bindings.unselected.textAppearance
                        )
                }
                .opacity(isOn ? 0 : 1)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .animation(Animation.easeInOut(duration: 0.05), value: configuration.isOn)
#if os(tvOS)
        .buttonStyle(TVButtonStyle())
#endif
    }

    private func measureTextSize(_ text: String, with appearance: ThomasTextAppearance?) -> CGSize {
        guard let appearance = appearance else {
            return CGSizeZero
        }

        let font = UIFont.resolveUIFont(appearance)
        return (text as NSString).size(withAttributes: [.font: font])
    }

    private func measureTextHeight(_ text: String, with appearance: ThomasTextAppearance?) -> CGFloat {
        guard let appearance = appearance else {
            return 0
        }

        let font = UIFont.resolveUIFont(appearance)
        return (text as NSString).size(withAttributes: [.font: font]).height
    }
}
