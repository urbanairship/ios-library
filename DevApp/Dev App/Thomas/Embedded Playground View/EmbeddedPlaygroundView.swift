/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore
import AirshipScenes

protocol EmbeddedViewMaker {}
extension EmbeddedViewMaker {

    @MainActor
    func makeEmbeddedView<Content: View>(
        id: String, 
        parentWidth: CGFloat? = nil,
        parentHeight: CGFloat? = nil,
        isShowingPlaceholder: Bool,
        @ViewBuilder placeholder: @escaping () -> Content
    ) -> some View {
        AirshipEmbeddedView(
            embeddedID: isShowingPlaceholder ? "nonexistent view id" : id,
            embeddedSize: AirshipEmbeddedSize(parentWidth: parentWidth, parentHeight: parentHeight),
            placeholder:placeholder
        )
    }
}

struct EmbeddedUnboundedHorizontalScrollView: View, EmbeddedViewMaker {
    @EnvironmentObject var model: EmbeddedPlaygroundMenuViewModel

    @State
    private var size: CGSize?

    @ViewBuilder
    private var embeddedView: some View {
        let keyItems = [KeyItem(name: "Embedded view frame",
                                color: .red),
                        KeyItem(name: "Scroll view frame",
                                color: .gray),
                        KeyItem(name: "Placeholder view",
                                color: .green)]

        ScrollView(.horizontal) {
            let exampleItem = Text("Example item")
                .font(.largeTitle)
                .frame(width: 200, height: 200)
                .background(Color.orange)

            HStack(spacing: 20) {
                exampleItem
                exampleItem

                makeEmbeddedView(
                    id: model.selectedEmbeddedID,
                    parentWidth: $size.wrappedValue?.width,
                    isShowingPlaceholder: model.isShowingPlaceholder
                ) {
                    Text("Placeholder")
                        .font(.largeTitle)
                        .frame(width: 200, height: 200)
                        .background(Color.green)
                }
                .id(model.isShowingPlaceholder)

                exampleItem
                exampleItem
            }
        }
        .airshipMeasureView($size)
        .border(Color.gray, width: 3)
        .addKeyView(keyItems:keyItems)
        .addPlaceholderToggle(state: $model.isShowingPlaceholder)
        .navigationTitle(model.selectedFileID)
    }

    var body: some View {
        embeddedView
    }
}

struct EmbeddedUnboundedVerticalScrollView: View, EmbeddedViewMaker {
    @EnvironmentObject var model: EmbeddedPlaygroundMenuViewModel
    
    @State
    private var size: CGSize?

    private var embeddedView: some View {
        let keyItems = [KeyItem(name: "Embedded view frame",
                                color: .red),
                        KeyItem(name: "Scroll view frame",
                                color: .gray),
                        KeyItem(name: "Placeholder view",
                                color: .green)]

        let exampleItem = Text("Example item")
            .font(.largeTitle)
            .frame(width: 200, height: 200)
            .background(Color.orange)

        return ScrollView(.vertical) {

            VStack(spacing: 20) {
                exampleItem
                exampleItem
                makeEmbeddedView(
                    id: model.selectedEmbeddedID,
                    parentWidth: size?.width,
                    parentHeight: size?.height,
                    isShowingPlaceholder: model.isShowingPlaceholder
                ) {
                    Text("Placeholder")
                        .font(.largeTitle)
                        .frame(width: 200, height: 200)
                        .background(Color.green)
                }
                .id(model.isShowingPlaceholder)
                exampleItem
                exampleItem
            }
        }
        .airshipMeasureView($size)
        .border(Color.gray, width: 3)
        .addKeyView(keyItems:keyItems)
        .addPlaceholderToggle(state: $model.isShowingPlaceholder)
        .navigationTitle(model.selectedFileID)

    }

    var body: some View {
        embeddedView
    }
}

struct EmbeddedHorizontalScrollView: View, EmbeddedViewMaker {
    @EnvironmentObject var model: EmbeddedPlaygroundMenuViewModel

    @State
    private var size: CGSize?


    var embeddedView: some View {
        let keyItems = [KeyItem(name: "Embedded view frame",
                                color: .red),
                        KeyItem(name: "Scroll view frame",
                                color: .gray),
                        KeyItem(name: "Placeholder view",
                                color: .green)]

        return ScrollView(.horizontal) {
            let exampleItem = Text("Example item")
                .font(.largeTitle)
                .frame(width: 200, height: 200)
                .background(Color.orange)

            HStack(spacing: 20) {
                exampleItem
                exampleItem
                makeEmbeddedView(
                    id: model.selectedEmbeddedID,
                    parentWidth: size?.width,
                    parentHeight: size?.height,
                    isShowingPlaceholder: model.isShowingPlaceholder
                ) {
                    Text("Placeholder")
                        .font(.largeTitle)
                        .frame(width: 200, height: 200)
                        .background(Color.green)
                }.id(model.isShowingPlaceholder)
                exampleItem
                exampleItem
            }
        }
        .airshipMeasureView($size)
        .border(Color.gray, width: 3)
        .addKeyView(keyItems:keyItems)
        .addPlaceholderToggle(state: $model.isShowingPlaceholder)
        .navigationTitle(model.selectedFileID)


    }

    var body: some View {
        embeddedView
    }
}

struct EmbeddedFixedFrameView: View, EmbeddedViewMaker {
    @EnvironmentObject var model: EmbeddedPlaygroundMenuViewModel

    let keyItems = [KeyItem(name: "Fixed size frame",
                            color: .red),
                    KeyItem(name: "Placeholder view",
                            color: .green)]

    private var embeddedView: some View {
        Group {
            makeEmbeddedView(
                id: model.selectedEmbeddedID,
                isShowingPlaceholder: model.isShowingPlaceholder
            ) {
                Text("Placeholder")
                    .font(.largeTitle)
                    .frame(width: 200, height: 200)
                    .background(Color.green)
            }
            .frame(maxWidth: 200, maxHeight:200)
            .border(Color.red, width: 3)
            .id(model.isShowingPlaceholder)
            .addKeyView(keyItems: keyItems)
            .addPlaceholderToggle(state: $model.isShowingPlaceholder)
        }
        .navigationTitle(model.selectedFileID)
    }

    var body: some View {
        embeddedView
    }
}

/// Lets the on-device model pick which pending instance to show, using each scene's
/// `content_description`.
///
/// To exercise it: select every `ai-selection-*` scene in the picker (each one stacks a
/// pending instance under the shared `ai selection` embedded ID), then open this screen.
/// The user context below is what the model ranks against — flip it to dogs and the
/// winner should change.
struct EmbeddedAISelectionView: View {

    private static let catContext = "User interests: cats"
    private static let dogContext = "User interests: dogs"

    /// Holds the context the provider hands back. A box rather than a captured snapshot:
    /// toggling re-creates the embedded view (via `.id`), and that re-ask races the
    /// `onChange` that would reinstall a snapshot provider — so the provider reads live
    /// state instead of being replaced. Seeded to match `likesCats`, so a re-ask that
    /// lands before the first `onChange` still sees real context.
    @MainActor
    final class ContextBox {
        var summary: String = EmbeddedAISelectionView.catContext
    }

    @EnvironmentObject var model: EmbeddedPlaygroundMenuViewModel

    @State private var likesCats: Bool = true
    @State private var box = ContextBox()

    private var contextSummary: String {
        likesCats ? Self.catContext : Self.dogContext
    }

    var body: some View {
        VStack(spacing: 16) {
            Toggle("User likes cats", isOn: $likesCats)

            Text("Context: \(contextSummary)")
                .font(.caption2)
                .foregroundColor(.secondary)

            AirshipEmbeddedView(
                embeddedID: model.selectedEmbeddedID,
                selection: .ai(
                    prompt: "Show content that matches the user's interests.",
                    fallback: .priority
                )
            ) {
                Text("Deciding…")
                    .font(.callout)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(Color.green.opacity(0.3))
            }
            // The model runs once per pending set; rebuild the view so toggling the
            // context re-asks rather than showing the previous winner.
            .id(likesCats)
            .border(Color.red, width: 3)

            Spacer()
        }
        .padding()
        .navigationTitle("AI selection")
        .onChangeOfCompat(likesCats, initial: true) { _ in
            box.summary = contextSummary
        }
        .onAppear {
            let box = box
            Airship.ai.setContextProvider(for: AirshipAI.EmbeddedSelection.usage) { _ in
                AirshipAI.Context(items: [.init(content: await box.summary)])
            }
        }
        .onDisappear {
            Airship.ai.setContextProvider(for: AirshipAI.EmbeddedSelection.usage, nil)
        }
    }
}

#Preview {
    EmbeddedUnboundedHorizontalScrollView()
}



