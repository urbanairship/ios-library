/* Copyright Urban Airship and Contributors */

import SwiftUI
import AirshipCore

protocol EmbeddedViewMaker {}
extension EmbeddedViewMaker {

    func makeEmbeddedView<Content: View>(
        id: String, 
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        isShowingPlaceholder: Bool,
        @ViewBuilder placeholder: @escaping () -> Content
    ) -> some View {
        AirshipEmbeddedView(
            embeddedID: isShowingPlaceholder ? "nonexistent view id" : id,
            embeddedSize: AirshipEmbeddedSize(maxWidth: maxWidth, maxHeight: maxHeight),
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
                    maxWidth: $size.wrappedValue?.width,
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
                    maxWidth: size?.width,
                    maxHeight: size?.height,
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
                    maxWidth: size?.width,
                    maxHeight: size?.height,
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

#Preview {
    EmbeddedUnboundedHorizontalScrollView()
}



