import SwiftUI

/// Dynamic app configuration view that renders UI based on a JSON schema
struct DynamicAppConfigView: View {
    let schema: UISchema
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Schema description
                if let description = schema.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Render sections
                if let sections = schema.sections {
                    ForEach(sections) { section in
                        if shouldShowSection(section) {
                            SectionView(
                                section: section,
                                config: $config,
                                onConfigChange: onConfigChange
                            )
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func shouldShowSection(_ section: UISchemaSection) -> Bool {
        if let showIf = section.showIf {
            return evaluateCondition(showIf, config: config)
        }
        return true
    }
}

// MARK: - Section View

private struct SectionView: View {
    let section: UISchemaSection
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    @State private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                if let icon = section.icon {
                    Image(systemName: mapIcon(icon))
                        .foregroundStyle(.techniluxPrimary)
                }

                Text(section.title)
                    .font(.headline)

                Spacer()

                if section.collapsible == true {
                    Button {
                        withAnimation {
                            isCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            if let description = section.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            // Section fields
            if !isCollapsed {
                VStack(spacing: 16) {
                    ForEach(section.fields) { field in
                        if shouldShowField(field) {
                            FieldView(
                                field: field,
                                config: $config,
                                onConfigChange: onConfigChange
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.5))
        .onAppear {
            isCollapsed = section.collapsed == true
        }
    }

    private func shouldShowField(_ field: UISchemaField) -> Bool {
        if let showIf = field.showIf {
            return evaluateCondition(showIf, config: config)
        }
        if let hideIf = field.hideIf {
            return !evaluateCondition(hideIf, config: config)
        }
        return true
    }
}

// MARK: - Field View

private struct FieldView: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            Text(field.label)
                .font(.subheadline)
                .fontWeight(.medium)

            // Description
            if let description = field.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Field input
            fieldInput
        }
    }

    @ViewBuilder
    private var fieldInput: some View {
        switch field.type {
        case .switch:
            SwitchField(field: field, config: $config, onConfigChange: onConfigChange)

        case .number:
            NumberField(field: field, config: $config, onConfigChange: onConfigChange)

        case .text:
            TextField(field: field, config: $config, onConfigChange: onConfigChange)

        case .textarea:
            TextAreaField(field: field, config: $config, onConfigChange: onConfigChange)

        case .select:
            SelectField(field: field, config: $config, onConfigChange: onConfigChange)

        case .list:
            ListField(field: field, config: $config, onConfigChange: onConfigChange)

        case .urlList:
            URLListField(field: field, config: $config, onConfigChange: onConfigChange)

        case .keyValue:
            KeyValueField(field: field, config: $config, onConfigChange: onConfigChange)

        case .objectArray:
            ObjectArrayField(field: field, config: $config, onConfigChange: onConfigChange)

        case .tabs:
            TabsField(field: field, config: $config, onConfigChange: onConfigChange)

        case .clientSelector:
            ClientSelectorField(field: field, config: $config, onConfigChange: onConfigChange)

        case .group:
            GroupField(field: field, config: $config, onConfigChange: onConfigChange)

        case .table:
            TableField(field: field, config: $config, onConfigChange: onConfigChange)
        }
    }
}

// MARK: - Field Components

private struct SwitchField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        Toggle("", isOn: Binding(
            get: { getValue(at: field.path, in: config) as? Bool ?? field.default?.value as? Bool ?? false },
            set: { newValue in
                setValue(newValue, at: field.path, in: &config)
                onConfigChange()
            }
        ))
        .labelsHidden()
    }
}

private struct NumberField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        HStack {
            SwiftUI.TextField(
                field.placeholder ?? "",
                value: Binding(
                    get: { getValue(at: field.path, in: config) as? Int ?? field.default?.value as? Int ?? 0 },
                    set: { newValue in
                        setValue(newValue, at: field.path, in: &config)
                        onConfigChange()
                    }
                ),
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .keyboardType(.numberPad)

            if let suffix = field.suffix {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TextField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        SwiftUI.TextField(
            field.placeholder ?? "",
            text: Binding(
                get: { getValue(at: field.path, in: config) as? String ?? field.default?.value as? String ?? "" },
                set: { newValue in
                    setValue(newValue, at: field.path, in: &config)
                    onConfigChange()
                }
            )
        )
        .textFieldStyle(.roundedBorder)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }
}

private struct TextAreaField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        TextEditor(text: Binding(
            get: { getValue(at: field.path, in: config) as? String ?? field.default?.value as? String ?? "" },
            set: { newValue in
                setValue(newValue, at: field.path, in: &config)
                onConfigChange()
            }
        ))
        .frame(minHeight: CGFloat((field.rows ?? 4) * 20))
        .font(.system(.body, design: .monospaced))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct SelectField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        Picker("", selection: Binding(
            get: { getValue(at: field.path, in: config) as? String ?? field.default?.value as? String ?? "" },
            set: { newValue in
                setValue(newValue, at: field.path, in: &config)
                onConfigChange()
            }
        )) {
            ForEach(field.options ?? [], id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.menu)
    }
}

private struct ListField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    @State private var newItem = ""

    private var items: [String] {
        (getValue(at: field.path, in: config) as? [String]) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Add new item
            HStack {
                SwiftUI.TextField(field.itemPlaceholder ?? "Add item...", text: $newItem)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    if !newItem.isEmpty {
                        var newItems = items
                        newItems.append(newItem)
                        setValue(newItems, at: field.path, in: &config)
                        newItem = ""
                        onConfigChange()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.techniluxPrimary)
                }
                .disabled(newItem.isEmpty)
            }

            // List items
            ForEach(items.indices, id: \.self) { index in
                HStack {
                    Text(items[index])
                        .font(.subheadline)

                    Spacer()

                    Button {
                        var newItems = items
                        newItems.remove(at: index)
                        setValue(newItems, at: field.path, in: &config)
                        onConfigChange()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct URLListField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    @State private var newURL = ""

    private var urls: [String] {
        (getValue(at: field.path, in: config) as? [String]) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Add new URL
            HStack {
                SwiftUI.TextField("https://...", text: $newURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    if !newURL.isEmpty {
                        var newURLs = urls
                        newURLs.append(newURL)
                        setValue(newURLs, at: field.path, in: &config)
                        newURL = ""
                        onConfigChange()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.techniluxPrimary)
                }
                .disabled(newURL.isEmpty)
            }

            // URL list
            ForEach(urls.indices, id: \.self) { index in
                HStack {
                    Text(urls[index])
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        var newURLs = urls
                        newURLs.remove(at: index)
                        setValue(newURLs, at: field.path, in: &config)
                        onConfigChange()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct KeyValueField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    @State private var newKey = ""

    private var entries: [String: Any] {
        (getValue(at: field.path, in: config) as? [String: Any]) ?? [:]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Add new entry
            HStack {
                SwiftUI.TextField(field.keyPlaceholder ?? "Key", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    if !newKey.isEmpty && entries[newKey] == nil {
                        var newEntries = entries
                        newEntries[newKey] = [String: Any]()
                        setValue(newEntries, at: field.path, in: &config)
                        newKey = ""
                        onConfigChange()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.techniluxPrimary)
                }
                .disabled(newKey.isEmpty)
            }

            // Entries
            ForEach(Array(entries.keys).sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(key)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Button {
                            var newEntries = entries
                            newEntries.removeValue(forKey: key)
                            setValue(newEntries, at: field.path, in: &config)
                            onConfigChange()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct ObjectArrayField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    private var items: [[String: Any]] {
        (getValue(at: field.path, in: config) as? [[String: Any]]) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Items
            if items.isEmpty {
                Text(field.emptyMessage ?? "No items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(items.indices, id: \.self) { index in
                    ObjectArrayItemView(
                        index: index,
                        item: items[index],
                        field: field,
                        config: $config,
                        onConfigChange: onConfigChange
                    )
                }
            }

            // Add button
            Button {
                var newItems = items
                newItems.append([:])
                setValue(newItems, at: field.path, in: &config)
                onConfigChange()
            } label: {
                Label(field.addLabel ?? "Add Item", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct ObjectArrayItemView: View {
    let index: Int
    let item: [String: Any]
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    @State private var isExpanded = false

    private var title: String {
        if let titleField = field.itemSchema?.titleField {
            return (item[titleField] as? String) ?? "Item \(index + 1)"
        }
        return "Item \(index + 1)"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let schema = field.itemSchema {
                VStack(spacing: 12) {
                    ForEach(schema.fields) { subField in
                        let subPath = "\(field.path)[\(index)].\(subField.path)"
                        FieldView(
                            field: UISchemaField(
                                id: "\(field.id)_\(index)_\(subField.id)",
                                path: subPath,
                                type: subField.type,
                                label: subField.label,
                                description: subField.description,
                                default: subField.default,
                                min: subField.min,
                                max: subField.max,
                                suffix: subField.suffix,
                                step: subField.step,
                                placeholder: subField.placeholder,
                                maxLength: subField.maxLength,
                                rows: subField.rows,
                                options: subField.options,
                                allowCustom: subField.allowCustom,
                                itemType: subField.itemType,
                                itemPlaceholder: subField.itemPlaceholder,
                                urlListOptions: subField.urlListOptions,
                                keyLabel: subField.keyLabel,
                                keyPlaceholder: subField.keyPlaceholder,
                                valueSchema: subField.valueSchema,
                                itemSchema: subField.itemSchema,
                                addLabel: subField.addLabel,
                                emptyMessage: subField.emptyMessage,
                                minItems: subField.minItems,
                                maxItems: subField.maxItems,
                                tabsOptions: subField.tabsOptions,
                                clientSelectorOptions: subField.clientSelectorOptions,
                                optionsFrom: subField.optionsFrom,
                                groupFields: subField.groupFields,
                                groupLayout: subField.groupLayout,
                                groupColumns: subField.groupColumns,
                                showIf: subField.showIf,
                                hideIf: subField.hideIf,
                                required: subField.required,
                                pattern: subField.pattern,
                                patternMessage: subField.patternMessage
                            ),
                            config: $config,
                            onConfigChange: onConfigChange
                        )
                    }
                }
                .padding(.top, 8)
            }
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)

                Spacer()

                Button {
                    var items = (getValue(at: field.path, in: config) as? [[String: Any]]) ?? []
                    items.remove(at: index)
                    setValue(items, at: field.path, in: &config)
                    onConfigChange()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

private struct TabsField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    @State private var selectedTab = 0

    private var tabs: [[String: Any]] {
        (getValue(at: field.path, in: config) as? [[String: Any]]) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tab selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs.indices, id: \.self) { index in
                        let tabName = (tabs[index][field.tabsOptions?.nameField ?? "name"] as? String) ?? "Tab \(index + 1)"
                        Button {
                            selectedTab = index
                        } label: {
                            Text(tabName)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTab == index ? Color.techniluxPrimary : Color.secondary.opacity(0.2))
                                .foregroundStyle(selectedTab == index ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }

                    if field.tabsOptions?.allowAdd != false {
                        Button {
                            var newTabs = tabs
                            var newTab: [String: Any] = [:]
                            if let defaults = field.tabsOptions?.defaultItem {
                                for (key, value) in defaults {
                                    newTab[key] = value.value
                                }
                            }
                            newTab[field.tabsOptions?.nameField ?? "name"] = "New Tab"
                            newTabs.append(newTab)
                            setValue(newTabs, at: field.path, in: &config)
                            selectedTab = newTabs.count - 1
                            onConfigChange()
                        } label: {
                            Image(systemName: "plus")
                                .font(.subheadline)
                                .padding(6)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Tab content
            if !tabs.isEmpty && selectedTab < tabs.count {
                VStack(spacing: 12) {
                    if let schema = field.tabsOptions?.itemSchema {
                        ForEach(schema.fields) { subField in
                            let subPath = "\(field.path)[\(selectedTab)].\(subField.path)"
                            FieldView(
                                field: UISchemaField(
                                    id: "\(field.id)_\(selectedTab)_\(subField.id)",
                                    path: subPath,
                                    type: subField.type,
                                    label: subField.label,
                                    description: subField.description,
                                    default: subField.default,
                                    min: subField.min,
                                    max: subField.max,
                                    suffix: subField.suffix,
                                    step: subField.step,
                                    placeholder: subField.placeholder,
                                    maxLength: subField.maxLength,
                                    rows: subField.rows,
                                    options: subField.options,
                                    allowCustom: subField.allowCustom,
                                    itemType: subField.itemType,
                                    itemPlaceholder: subField.itemPlaceholder,
                                    urlListOptions: subField.urlListOptions,
                                    keyLabel: subField.keyLabel,
                                    keyPlaceholder: subField.keyPlaceholder,
                                    valueSchema: subField.valueSchema,
                                    itemSchema: subField.itemSchema,
                                    addLabel: subField.addLabel,
                                    emptyMessage: subField.emptyMessage,
                                    minItems: subField.minItems,
                                    maxItems: subField.maxItems,
                                    tabsOptions: subField.tabsOptions,
                                    clientSelectorOptions: subField.clientSelectorOptions,
                                    optionsFrom: subField.optionsFrom,
                                    groupFields: subField.groupFields,
                                    groupLayout: subField.groupLayout,
                                    groupColumns: subField.groupColumns,
                                    showIf: subField.showIf,
                                    hideIf: subField.hideIf,
                                    required: subField.required,
                                    pattern: subField.pattern,
                                    patternMessage: subField.patternMessage
                                ),
                                config: $config,
                                onConfigChange: onConfigChange
                            )
                        }
                    }

                    // Delete tab button
                    if field.tabsOptions?.allowDelete != false && tabs.count > (field.tabsOptions?.minTabs ?? 0) {
                        Button(role: .destructive) {
                            var newTabs = tabs
                            newTabs.remove(at: selectedTab)
                            setValue(newTabs, at: field.path, in: &config)
                            if selectedTab >= newTabs.count {
                                selectedTab = max(0, newTabs.count - 1)
                            }
                            onConfigChange()
                        } label: {
                            Label("Delete Tab", systemImage: "trash")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

private struct ClientSelectorField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    @State private var newIP = ""

    private var selectedClients: [String] {
        if field.clientSelectorOptions?.multiple == true {
            return (getValue(at: field.path, in: config) as? [String]) ?? []
        } else {
            if let single = getValue(at: field.path, in: config) as? String, !single.isEmpty {
                return [single]
            }
            return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Manual IP entry
            if field.clientSelectorOptions?.allowManualEntry != false {
                HStack {
                    SwiftUI.TextField("Enter IP address...", text: $newIP)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)

                    Button {
                        if !newIP.isEmpty {
                            if field.clientSelectorOptions?.multiple == true {
                                var clients = selectedClients
                                clients.append(newIP)
                                setValue(clients, at: field.path, in: &config)
                            } else {
                                setValue(newIP, at: field.path, in: &config)
                            }
                            newIP = ""
                            onConfigChange()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.techniluxPrimary)
                    }
                    .disabled(newIP.isEmpty)
                }
            }

            // Selected clients
            ForEach(selectedClients, id: \.self) { client in
                HStack {
                    Image(systemName: "laptopcomputer")
                        .foregroundStyle(.secondary)
                    Text(client)
                        .font(.subheadline)

                    Spacer()

                    Button {
                        if field.clientSelectorOptions?.multiple == true {
                            var clients = selectedClients.filter { $0 != client }
                            setValue(clients, at: field.path, in: &config)
                        } else {
                            setValue("", at: field.path, in: &config)
                        }
                        onConfigChange()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct GroupField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let groupFields = field.groupFields {
                ForEach(groupFields) { subField in
                    FieldView(
                        field: subField,
                        config: $config,
                        onConfigChange: onConfigChange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

private struct TableField: View {
    let field: UISchemaField
    @Binding var config: [String: Any]
    let onConfigChange: () -> Void

    private var rows: [[String: Any]] {
        (getValue(at: field.path, in: config) as? [[String: Any]]) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if rows.isEmpty {
                Text("No data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(rows.indices, id: \.self) { index in
                    HStack {
                        Text("Row \(index + 1)")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Helpers

/// Get a value from a nested config using dot-notation path (e.g., "groups[0].name")
private func getValue(at path: String, in config: [String: Any]) -> Any? {
    let components = parsePath(path)
    var current: Any = config

    for component in components {
        switch component {
        case .key(let key):
            guard let dict = current as? [String: Any],
                  let value = dict[key] else { return nil }
            current = value
        case .index(let index):
            guard let array = current as? [Any],
                  index < array.count else { return nil }
            current = array[index]
        }
    }

    return current
}

/// Set a value in a nested config using dot-notation path
private func setValue(_ value: Any, at path: String, in config: inout [String: Any]) {
    let components = parsePath(path)
    guard !components.isEmpty else { return }

    if components.count == 1 {
        if case .key(let key) = components[0] {
            config[key] = value
        }
        return
    }

    // Need to navigate and modify nested structure
    setNestedValue(value, components: components, index: 0, in: &config)
}

private func setNestedValue(_ value: Any, components: [PathComponent], index: Int, in config: inout [String: Any]) {
    guard index < components.count else { return }

    switch components[index] {
    case .key(let key):
        if index == components.count - 1 {
            config[key] = value
        } else {
            var nested = config[key] as? [String: Any] ?? [:]
            setNestedValue(value, components: components, index: index + 1, in: &nested)
            config[key] = nested
        }
    case .index(_):
        // Arrays need special handling - skip for now
        break
    }
}

private enum PathComponent {
    case key(String)
    case index(Int)
}

private func parsePath(_ path: String) -> [PathComponent] {
    var components: [PathComponent] = []
    var current = ""

    var i = path.startIndex
    while i < path.endIndex {
        let char = path[i]

        if char == "." {
            if !current.isEmpty {
                components.append(.key(current))
                current = ""
            }
        } else if char == "[" {
            if !current.isEmpty {
                components.append(.key(current))
                current = ""
            }
            // Find closing bracket
            let start = path.index(after: i)
            if let end = path[start...].firstIndex(of: "]") {
                let indexStr = String(path[start..<end])
                if let index = Int(indexStr) {
                    components.append(.index(index))
                }
                i = end
            }
        } else {
            current.append(char)
        }

        i = path.index(after: i)
    }

    if !current.isEmpty {
        components.append(.key(current))
    }

    return components
}

/// Evaluate a condition against the config
private func evaluateCondition(_ condition: UISchemaFieldCondition, config: [String: Any]) -> Bool {
    let value = getValue(at: condition.field, in: config)

    switch condition.operator {
    case "eq":
        return isEqual(value, condition.value?.value)
    case "neq":
        return !isEqual(value, condition.value?.value)
    case "contains":
        if let array = value as? [Any], let searchValue = condition.value?.value {
            return array.contains { isEqual($0, searchValue) }
        }
        return false
    case "notEmpty":
        return !isEmpty(value)
    case "empty":
        return isEmpty(value)
    default:
        return true
    }
}

private func isEqual(_ a: Any?, _ b: Any?) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }

    if let aString = a as? String, let bString = b as? String {
        return aString == bString
    }
    if let aInt = a as? Int, let bInt = b as? Int {
        return aInt == bInt
    }
    if let aBool = a as? Bool, let bBool = b as? Bool {
        return aBool == bBool
    }

    return String(describing: a) == String(describing: b)
}

private func isEmpty(_ value: Any?) -> Bool {
    guard let value = value else { return true }

    if let string = value as? String { return string.isEmpty }
    if let array = value as? [Any] { return array.isEmpty }
    if let dict = value as? [String: Any] { return dict.isEmpty }

    return false
}

/// Map web icon names to SF Symbols
private func mapIcon(_ icon: String) -> String {
    let iconMap: [String: String] = [
        "settings": "gear",
        "shield": "shield",
        "list": "list.bullet",
        "users": "person.2",
        "globe": "globe",
        "server": "server.rack",
        "lock": "lock",
        "clock": "clock",
        "database": "cylinder",
        "network": "network"
    ]
    return iconMap[icon] ?? icon
}
