/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine
@_spi(AirshipInternal) import AirshipBasement

struct Score: View {
    private let info: ThomasViewInfo.Score
    private let constraints: ViewConstraints

    @MainActor
    private final class ViewModel: ObservableObject {

        private let style: ThomasViewInfo.Score.ScoreStyle

        init(style: ThomasViewInfo.Score.ScoreStyle) {
            self.style = style
        }

        @Published
        fileprivate var score: AirshipJSON?

        @Published
        fileprivate var index: Int?

        func accessibilityValue(format: String) -> String? {
            guard let index else { return nil }
            switch(style) {
            case .numberRange(let rangeStyle):
                let totalItems = rangeStyle.end - rangeStyle.start + 1
                return String(format: format, index.airshipLocalizedForVoiceOver(), totalItems.airshipLocalizedForVoiceOver())
            }
        }

        func incrementScore() {
            switch(style) {
            case .numberRange(let rangeStyle):
                guard var index else {
                    self.index = rangeStyle.start
                    self.score = .number(Double(rangeStyle.start))
                    return
                }

                index = min(rangeStyle.end, index + 1)
                if self.index != index {
                    self.index = index
                    self.score = .number(Double(index))
                }
            }
        }

        func decrementScore() {
            switch(style) {
            case .numberRange(let rangeStyle):
                guard var index else {
                    self.index = rangeStyle.start
                    self.score = .number(Double(rangeStyle.start))
                    return
                }

                index = max(rangeStyle.start, index - 1)
                if self.index != index {
                    self.index = index
                    self.score = .number(Double(index))
                }
            }
        }
    }

    @Environment(\.pageIdentifier)
    private var pageID

    @EnvironmentObject
    private var formDataCollector: ThomasFormDataCollector

    @EnvironmentObject
    private var formState: ThomasFormState

    @EnvironmentObject
    private var thomasState: ThomasState

    @Environment(\.colorScheme)
    private var colorScheme

    @EnvironmentObject
    private var validatableHelper: ValidatableHelper

    @EnvironmentObject
    private var thomasEnvironment: ThomasEnvironment

    @Environment(\.thomasAssociatedLabelResolver)
    private var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .score,
            thomasState: thomasState
        )
    }

    @StateObject
    private var viewModel: ViewModel

    init(info: ThomasViewInfo.Score, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
        _viewModel = .init(wrappedValue: ViewModel(style: info.properties.style))
    }

    @ViewBuilder
    private func makeNumberRangeScoreItems(style: ThomasViewInfo.Score.ScoreStyle.NumberRange, constraints: ViewConstraints) -> some View {
        ForEach((style.start...style.end), id: \.self) { index in
            let isOn = Binding<Bool>(
                get: {
                    self.viewModel.index == index
                },
                set: {
                    if $0 {
                        self.viewModel.index = index
                        self.viewModel.score = .number(Double(index))
                    }
                }
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
            if style.wrapping != nil {
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
            .accessibilityElement(children: .ignore)
            .accessible(
                self.info.accessible,
                associatedLabel: associatedLabel,
                hideIfDescriptionIsMissing: false
            )
            .accessibilityAdjustableAction { direction in
                switch(direction) {
                case .increment:
                    viewModel.incrementScore()
                case .decrement:
                    viewModel.decrementScore()
                @unknown default:
                    break
                }
            }
            .accessibilityValue(self.viewModel.accessibilityValue(format: self.thomasEnvironment.localizedString(key: "ua_x_of_y", fallback: "%@ of %@")) ?? "")
            .formElement()
            .airshipOnChangeOf(self.viewModel.score) { score in
                self.updateScore(score)
            }
            .onAppear {
                self.restoreFormState()
                if self.formState.validationMode == .onDemand {
                    validatableHelper.subscribe(
                        forIdentifier: info.properties.identifier,
                        formState: formState,
                        initialValue: self.viewModel.score,
                        valueUpdates: self.viewModel.$score,
                        validatables: info.validation
                    ) { [weak thomasState = thomasState, weak viewModel = viewModel] outcomes in
                        guard let thomasState, let viewModel else { return }
                        thomasState.processSync(
                            outcomes: outcomes,
                            formFieldValue: .score(viewModel.score)
                        )
                    }
                }
            }
    }

    private func modifiedConstraints() -> ViewConstraints {
        var constraints = self.constraints

        switch self.info.properties.style {
        case .numberRange(let style):
            // The row divides whatever width it has between its items, so what it needs is a width
            // — a length if it was given one, and otherwise the space it has to work in. Reading
            // only the length gave up whenever there wasn't one, and a score alone on the stack
            // axis of a horizontal layout is exactly that case: a percentage there is a share of a
            // sum it belongs to, so it settles no length, and the row fell back to laying its items
            // out at their own size, overflowing the width it was standing in.
            //
            // A declared height caps the result rather than being replaced by it. Both are ceilings
            // on the same square and the smaller wins, so a row with no usable width still has
            // something to go on. Android and web both size against the width they turn out to have
            // — a chain of square items in their parent, and `min` of the share, the maximum and
            // the row height — so neither has a length to give up on.
            let available = constraints.width ?? constraints.maxWidth
            let fromWidth = self.calculateHeight(style: style, width: available)

            constraints.height = [fromWidth, constraints.height]
                .compactMap { $0 }
                .min() ?? 32
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

    private func attributes(value: AirshipJSON?) -> [ThomasFormField.Attribute]? {
        guard
            let value,
            let name = info.properties.attributeName
        else {
            return nil
        }

        let attributeValue: ThomasAttributeValue? = if let string = value.string {
            .string(string)
        } else if let number = value.number {
            .number(number)
        } else {
            nil
        }

        guard let attributeValue else { return nil }

        return [
            ThomasFormField.Attribute(
                attributeName: name,
                attributeValue: attributeValue
            )
        ]
    }

    private func checkValid(_ value: AirshipJSON?) -> Bool {
        return value != nil || self.info.validation.isRequired != true
    }

    private func updateScore(_ value: AirshipJSON?) {
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
            case .score(let value) = self.formState.fieldValue(
                identifier: self.info.properties.identifier
            ),
            let value,
            let index = value.number
        else {
            self.updateScore(self.viewModel.score)
            return
        }

        self.viewModel.score = value
        self.viewModel.index = Int(index)
    }
}

private struct AirshipNumberRangeToggleStyle: ToggleStyle {
    fileprivate let style: ThomasViewInfo.Score.ScoreStyle.NumberRange
    fileprivate let viewConstraints: ViewConstraints
    fileprivate let value: Int
    fileprivate let colorScheme: ColorScheme
    fileprivate let disabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn

        // Pick which text appearance we should use
        let selectedAppearance = style.bindings.selected.textAppearance
        let unselectedAppearance = style.bindings.unselected.textAppearance

        // What the text needs, and what the row has room for. A wrapping row has as many lines as
        // it takes, so its items are as big as their numbers; a single row divides one width
        // between all of them, and that share is a ceiling the text does not get to exceed. Taking
        // the text alone is what put eleven 24pt numbers in a row 282pt wide and left five of them
        // visible — the row had already worked out that each item had 23pt, and nothing read it.
        let textDimension = max(measureForAppearance(selectedAppearance), measureForAppearance(unselectedAppearance))
        let maxDimension: CGFloat = if style.wrapping == nil, let share = viewConstraints.height {
            min(textDimension, share)
        } else {
            textDimension
        }

        /// Inject new constraints
        let viewConstraints = ViewConstraints(
            width: maxDimension,
            height: maxDimension,
            maxWidth: viewConstraints.maxWidth,
            maxHeight: viewConstraints.maxHeight,
            isHorizontalFixedSize: viewConstraints.isHorizontalFixedSize,
            isVerticalFixedSize: viewConstraints.isVerticalFixedSize,
            isHorizontalAbsoluteSize: true,
            isVerticalAbsoluteSize: true,
            safeAreaInsets: viewConstraints.safeAreaInsets
        )

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
                        .textAppearance(style.bindings.selected.textAppearance, colorScheme: colorScheme)
                        .scoreItemText()
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
                        .textAppearance(style.bindings.unselected.textAppearance, colorScheme: colorScheme)
                        .scoreItemText()
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
    
    private func measureForAppearance(_ appearance: ThomasTextAppearance?) -> CGFloat {
        let measuredSize = measureTextSize("\(style.end)", with: appearance)

        let minTappableDimension: CGFloat = 44.0

        let scaledWidthSpacing = AirshipFont.scaledSize(measuredSize.width)
        let scaledHeightSpacing = AirshipFont.scaledSize(measuredSize.height)

        let minWidth = max(minTappableDimension, measuredSize.width + scaledWidthSpacing)
        let minHeight = max(minTappableDimension, measuredSize.height + scaledHeightSpacing)

        return max(minWidth, minHeight)
    }

    private func measureTextSize(_ text: String, with appearance: ThomasTextAppearance?) -> CGSize {
        guard let appearance = appearance else {
            return CGSizeZero
        }

        let font = appearance.nativeFont
        return (text as String).size(withAttributes: [.font: font])
    }

    private func measureTextHeight(_ text: String, with appearance: ThomasTextAppearance?) -> CGFloat {
        guard let appearance = appearance else {
            return 0
        }

        let font = appearance.nativeFont
        return (text as String).size(withAttributes: [.font: font]).height
    }
}

fileprivate extension View {
    /// A number that shrinks to fit its item rather than being cut short by it.
    ///
    /// An item is sized for the longest number in the range, but a single row divides one width
    /// between all of them and the share can be less than that — eleven items across 282pt leaves
    /// 23pt each, where "10" at 24pt wants nearer 50. Truncating turns the last number into an
    /// ellipsis, which is the one number a 0-10 scale cannot do without.
    ///
    /// Web has the same squeeze and never shows it: its number is drawn inside the item's SVG, so
    /// it scales with the box. This is that, said to a `Text`.
    func scoreItemText() -> some View {
        self.lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}
