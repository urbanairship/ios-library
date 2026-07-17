/* Copyright Airship and Contributors */

import SwiftUI
import Combine
@_spi(AirshipInternal) import AirshipBasement

/// Editable, recursive model of an ``AirshipJSONSchema`` node backing the visual builder.
///
/// A tree of reference types so the drill-down SwiftUI editor can observe each node
/// independently: field edits update the node that owns them, while structural edits
/// (adding/removing a property, retyping the array element) update the parent's
/// `@Published` collections.
@MainActor
final class SchemaNodeModel: ObservableObject, Identifiable {
    nonisolated let id = UUID()

    enum Kind: String, CaseIterable, Identifiable {
        case string = "String"
        case stringEnum = "Enum"
        case boolean = "Boolean"
        case integer = "Integer"
        case number = "Number"
        case object = "Object"
        case array = "Array"

        var id: String { rawValue }
    }

    /// A named property of an object node.
    struct Property: Identifiable {
        let id = UUID()
        var name: String
        var required: Bool
        var node: SchemaNodeModel
    }

    @Published var kind: Kind
    @Published var descriptionText: String
    /// Comma-separated choices for `.stringEnum`.
    @Published var choicesText: String
    /// Child properties for `.object`.
    @Published var properties: [Property]
    /// Element schema for `.array`.
    @Published var items: SchemaNodeModel?

    init(
        kind: Kind = .string,
        descriptionText: String = "",
        choicesText: String = "",
        properties: [Property] = [],
        items: SchemaNodeModel? = nil
    ) {
        self.kind = kind
        self.descriptionText = descriptionText
        self.choicesText = choicesText
        self.properties = properties
        self.items = items
    }

    /// Lazily materializes the children a newly-selected kind needs, so switching to
    /// an array immediately has an element to drill into.
    func ensureChildrenForKind() {
        switch kind {
        case .array where items == nil:
            items = SchemaNodeModel()
        default:
            break
        }
    }

    /// A short one-line summary of the node's type, for list rows.
    var typeSummary: String {
        switch kind {
        case .string: return "string"
        case .stringEnum: return "enum"
        case .boolean: return "boolean"
        case .integer: return "integer"
        case .number: return "number"
        case .object: return "object · \(properties.count) field\(properties.count == 1 ? "" : "s")"
        case .array: return "array of \(items?.typeSummary ?? "…")"
        }
    }

    /// Builds the immutable ``AirshipJSONSchema`` this subtree describes. Unnamed object
    /// properties are dropped so a half-typed row never produces an empty key.
    func build() -> AirshipJSONSchema {
        let description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description.isEmpty ? nil : description

        switch kind {
        case .string:
            return .string(description: desc)
        case .stringEnum:
            let choices = choicesText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return .string(choices: choices.isEmpty ? nil : choices, description: desc)
        case .boolean:
            return .boolean(description: desc)
        case .integer:
            return .integer(description: desc)
        case .number:
            return .number(description: desc)
        case .object:
            var props: [String: AirshipJSONSchema] = [:]
            var required: [String] = []
            for property in properties {
                let name = property.name.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                props[name] = property.node.build()
                if property.required { required.append(name) }
            }
            return .object(properties: props, required: required.isEmpty ? nil : required, description: desc)
        case .array:
            return .array(items: (items ?? SchemaNodeModel()).build(), description: desc)
        }
    }

    /// Replaces this node in place with a flat object of the given properties, so the
    /// observing editor updates without the tree object being swapped out. Used to drop
    /// in an AI-suggested schema.
    func applyObject(properties: [Property]) {
        self.kind = .object
        self.descriptionText = ""
        self.choicesText = ""
        self.items = nil
        self.properties = properties
    }

    /// Seeds the builder with the executor's default `{ result, reason }` contract.
    static func defaultContract() -> SchemaNodeModel {
        SchemaNodeModel(
            kind: .object,
            properties: [
                Property(
                    name: "result",
                    required: true,
                    node: SchemaNodeModel(descriptionText: "The value the instruction asks for")
                ),
                Property(
                    name: "reason",
                    required: true,
                    node: SchemaNodeModel(descriptionText: "Brief reason for the result")
                ),
            ]
        )
    }
}

// MARK: - Drill-down editor

/// One screen of the schema tree. Objects list their properties in a standard editable
/// list (swipe or edit-mode to remove; `+` opens a slide-up sheet to add); each property
/// drills into its own screen.
struct SchemaNodeEditorView: View {
    @ObservedObject var node: SchemaNodeModel

    /// Set when this node is a named property of its parent, exposing name/required.
    var propertyBinding: Binding<SchemaNodeModel.Property>?

    var title: String = "Schema"

    @State private var showingAddProperty = false

    var body: some View {
        List {
            if let propertyBinding {
                Section("Property") {
                    TextField("name", text: propertyBinding.name)
                        .freeInput()
                    Toggle("Required", isOn: propertyBinding.required)
                }
            }

            Section("Type") {
                Picker("Type", selection: $node.kind) {
                    ForEach(SchemaNodeModel.Kind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .onChange(of: node.kind) { _ in node.ensureChildrenForKind() }

                TextField("Description (optional)", text: $node.descriptionText, axis: .vertical)

                if node.kind == .stringEnum {
                    TextField("Choices, comma-separated", text: $node.choicesText, axis: .vertical)
                        .font(.system(.footnote, design: .monospaced))
                        .autocorrectionDisabled()
                }
            }

            switch node.kind {
            case .object:
                propertiesSection
            case .array:
                arraySection
            case .string, .stringEnum, .boolean, .integer, .number:
                EmptyView()
            }
        }
        .navigationTitle(title)
#if !os(tvOS) && !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            if node.kind == .object {
#if !os(tvOS) && !os(macOS)
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
#endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddProperty = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProperty) {
            AddPropertySheet { name, kind, required, description in
                let child = SchemaNodeModel(kind: kind, descriptionText: description)
                child.ensureChildrenForKind()
                node.properties.append(
                    SchemaNodeModel.Property(name: name, required: required, node: child)
                )
            }
        }
    }

    @ViewBuilder
    private var propertiesSection: some View {
        Section("Properties") {
            if node.properties.isEmpty {
                Text("No properties — tap + to add one")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach($node.properties) { $property in
                NavigationLink {
                    SchemaNodeEditorView(
                        node: property.node,
                        propertyBinding: $property,
                        title: property.name.isEmpty ? "Property" : property.name
                    )
                } label: {
                    propertyRow(property)
                }
            }
            .onDelete { node.properties.remove(atOffsets: $0) }
        }
    }

    @ViewBuilder
    private var arraySection: some View {
        Section("Array element") {
            if let items = node.items {
                NavigationLink {
                    SchemaNodeEditorView(node: items, title: "Element")
                } label: {
                    HStack {
                        Text("Element schema")
                        Spacer()
                        Text(items.typeSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func propertyRow(_ property: SchemaNodeModel.Property) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(property.name.isEmpty ? "(unnamed)" : property.name)
                    .foregroundStyle(property.name.isEmpty ? .secondary : .primary)
                Text(property.node.typeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if property.required {
                Text("required")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add-property sheet

/// Slide-up form for defining a new object property before it's appended.
private struct AddPropertySheet: View {
    let onAdd: (_ name: String, _ kind: SchemaNodeModel.Kind, _ required: Bool, _ description: String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var kind: SchemaNodeModel.Kind = .string
    @State private var required: Bool = false
    @State private var description: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("property name", text: $name)
                        .freeInput()
                }
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(SchemaNodeModel.Kind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Toggle("Required", isOn: $required)
                }
                Section("Description (optional)") {
                    TextField("what this field means", text: $description, axis: .vertical)
                }
            }
            .navigationTitle("Add Property")
#if !os(tvOS) && !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name, kind, required, description)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
