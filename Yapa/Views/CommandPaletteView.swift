import SwiftUI

struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let keywords: [String]
    let systemImage: String
    let action: () -> Void

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let haystack = ([title, subtitle].compactMap { $0 } + keywords).joined(separator: " ").lowercased()
        return haystack.contains(query.lowercased())
    }
}

struct CommandPaletteView: View {
    let items: [CommandPaletteItem]
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [CommandPaletteItem] {
        items.filter { $0.matches(searchText) }.prefix(12).map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if !filteredItems.isEmpty {
                resultsList
            } else if !searchText.isEmpty {
                emptyState
            }
        }
        .frame(width: 560, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear { isSearchFocused = true }
        .onDisappear {
            searchText = ""
            selectedIndex = 0
        }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "command")
                .foregroundColor(.secondary)

            TextField("Type a command...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)

            Button(action: { isPresented = false }) {
                Text("Esc")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        CommandPaletteRow(item: item, isSelected: index == selectedIndex)
                            .id(index)
                            .onTapGesture { selectItem(item) }
                            .onHover { hovering in
                                if hovering { selectedIndex = index }
                            }
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredItems.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.return) {
            if !filteredItems.isEmpty { selectItem(filteredItems[selectedIndex]) }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "command.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No commands found")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectItem(_ item: CommandPaletteItem) {
        item.action()
        isPresented = false
    }
}

private struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
    }
}
