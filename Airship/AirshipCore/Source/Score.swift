/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct Score: View {
    let info: ThomasViewInfo.Score
    let constraints: ViewConstraints

    @State var score: Int?
    @EnvironmentObject var formState: FormState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func makeNumberRangeScoreItems(style: ThomasViewInfo.Score.ScoreStyle.NumberRange, constraints: ViewConstraints) -> some View {
        ForEach((style.start...style.end), id: \.self) { index in
            let isOn = Binding(
                get: { self.score == index },
                set: { if $0 { updateScore(index) } }
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
                .accessibilityElement(children: .contain)
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
            .accessible(self.info.accessible)
            .formElement()
            .onAppear {
                self.restoreFormState()
                self.updateScore(self.score)
            }
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

    private func updateScore(_ value: Int?) {
        self.score = value
        let isValid = value != nil || self.info.validation.isRequired != true

        var attributeValue: ThomasAttributeValue?
        if let value = value {
            attributeValue = ThomasAttributeValue.number(Double(value))
        }

        let data = FormInputData(
            self.info.properties.identifier,
            value: .score(value),
            attributeName: self.info.properties.attributeName,
            attributeValue: attributeValue,
            isValid: isValid
        )

        self.formState.updateFormInput(data)
    }

    private func restoreFormState() {
        let formValue = self.formState.data.formValue(
            identifier: self.info.properties.identifier
        )

        guard
            case let .score(scoreValue) = formValue,
            let value = scoreValue
        else {
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
