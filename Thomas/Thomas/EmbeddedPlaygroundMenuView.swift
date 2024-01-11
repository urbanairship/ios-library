/* Copyright Urban Airship and Contributors */

import SwiftUI

struct Item {
    var icon: String
    var title: String
    var description: String
    var destination: AnyView
}

class EmbeddedPlaygroundMenuViewModel: ObservableObject {
    @Published var selectedID: String = ""
    @Published var isShowingPlaceholder: Bool = false

    private let viewsPath = "/Embedded"

    lazy var embeddedViewIds: [String] = {
        let fileManager = FileManager.default
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Error: Could not find resource path.")
            return []
        }

        let fullPath = resourcePath + viewsPath

        do {
            let fileNames = try fileManager.contentsOfDirectory(atPath: fullPath)
            return fileNames.map { (fileName) -> String in
                return (fileName as NSString).deletingPathExtension
            }
        } catch {
            print("Error while enumerating files \(fullPath): \(error.localizedDescription)")
            return []
        }
    }()
}

struct EmbeddedPlaygroundMenuView: View {
    @StateObject var model = EmbeddedPlaygroundMenuViewModel()

    private var listItems: [Item] {
        [
            Item(icon: "arrow.left.and.right.square",
                 title: "Unbounded horizontally",
                 description: "Embedded scene that can grow unbounded horizontally",
                 destination: AnyView(EmbeddedUnboundedHorizontalScrollView().environmentObject(model))),
            Item(icon: "arrow.up.and.down.square",
                 title: "Unbounded vertically",
                 description: "Embedded scene that can grow unbounded in a vertical scroll view",
                 destination: AnyView(EmbeddedUnboundedVerticalScrollView().environmentObject(model))),
            Item(icon: "arrow.left.arrow.right.square",
                 title: "Horizontal scroll",
                 description: "Embedded scene in a horizontal scroll view",
                 destination: AnyView(EmbeddedHorizontalScrollView().environmentObject(model))),
            Item(icon: "square",
                 title: "Fixed frame",
                 description: "Embedded scene that is bounded to a fixed frame size",
                 destination: AnyView(EmbeddedFixedFrameView()
                    .environmentObject(model)))
        ]
    }

    private var listView: some View {
        Form {
            Section {
                EmbeddedPlaygroundPicker(selectedID: $model.selectedID, embeddedIds:model.embeddedViewIds)
                    .frame(height:120)
            }

            ForEach(listItems, id: \.title) { item in
                    NavigationLink(destination: item.destination) {
                        HStack(spacing: 16) {
                            Image(systemName: item.icon)
                                .resizable()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text(item.title).font(.title3)
                                Text(item.description)
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }.frame(height: 54)
                    }
            }
        }
    }

    var body: some View {
        NavigationView() {
            listView
            .listStyle(.plain)
            .navigationBarTitle("Embedded Layouts")
        }
    }
}

#Preview {
    EmbeddedPlaygroundMenuView()
}
