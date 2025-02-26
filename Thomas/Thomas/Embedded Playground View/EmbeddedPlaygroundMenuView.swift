/* Copyright Urban Airship and Contributors */

import SwiftUI
import Yams

struct Item {
    var icon: String
    var title: String
    var description: String
    var destination: AnyView
}

@MainActor
class EmbeddedPlaygroundMenuViewModel: ObservableObject {
    @Published var selectedFileID: String = "" {
        didSet {
            selectedEmbeddedID = extractEmbeddedId(selectedFileID: selectedFileID) ?? ""
        }
    }

    @Published var isShowingPlaceholder: Bool = false

    @Published var selectedEmbeddedID: String = ""

    private let viewsPath = "/Scenes/Embedded"

    func extractEmbeddedId(selectedFileID: String) -> String? {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Error: Could not find resource path.")
            return nil
        }

        let filePath = resourcePath + viewsPath + "/\(self.selectedFileID).yml"

        // Parse the YAML string into a dictionary
        if let fileContents = try? String(contentsOfFile: filePath, encoding: String.Encoding.utf8), let parsedYaml = try? Yams.load(yaml: fileContents) as? [String: Any] {

            // Navigate through the dictionary to retrieve the embedded_id
            if let presentation = parsedYaml["presentation"] as? [String: Any],
               let embeddedId = presentation["embedded_id"] as? String {
                return embeddedId
            }
        }

        return nil
    }

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
                EmbeddedPlaygroundPicker(selectedID: $model.selectedFileID, embeddedIds:model.embeddedViewIds)
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
        listView
        .listStyle(.plain)
    }
}

#Preview {
    EmbeddedPlaygroundMenuView()
}
