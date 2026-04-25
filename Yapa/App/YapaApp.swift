import SwiftUI
import AppKit

@main
struct YapaApp: App {
    @StateObject private var fileSystemService = FileSystemService.shared
    @StateObject private var searchService = SearchService.shared
    @State private var helpWindowController: NSWindowController?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileSystemService)
                .environmentObject(searchService)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("New Project") {
                    NotificationCenter.default.post(name: .createNewFolder, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .sidebar) {
                Button("Select Yapa Folder...") {
                    fileSystemService.selectRootFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            
            CommandGroup(after: .toolbar) {
                Button("Find in Document") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Fuzzy Search") {
                    NotificationCenter.default.post(name: .openFuzzySearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Button("Quick Open") {
                    NotificationCenter.default.post(name: .openQuickSwitcher, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command])
                
                Button("Insert Template") {
                    NotificationCenter.default.post(name: .insertTemplate, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Rename Item") {
                    NotificationCenter.default.post(name: .renameSelectedItem, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .help) {
                Button("Yapa Help") {
                    openHelp()
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
    }
    
    private func openHelp() {
        if let helpWindowController {
            helpWindowController.showWindow(nil)
            helpWindowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let helpView = YapaHelpView()
        let hostingController = NSHostingController(rootView: helpView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Yapa Help"
        window.setContentSize(NSSize(width: 760, height: 680))
        window.minSize = NSSize(width: 620, height: 520)
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        helpWindowController = controller
    }
}

private struct YapaHelpView: View {
    var body: some View {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yapa Help")
                            .font(.title2.weight(.semibold))
                    Text("Features, shortcuts, and how the app is organized.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(nsColor: .controlBackgroundColor))

                HStack {
                    Spacer()
                    Text("Version \(AppVersionInfo.current.displayString)")
                        .font(.caption2)
                        .foregroundColor(Color.orange.opacity(0.9))
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                MarkdownPreviewView(content: yapaHelpMarkdown)
                    .background(Color(nsColor: .textBackgroundColor))
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var yapaHelpMarkdown: String {
        """
        # Yapa Help

        Yapa is a local-first macOS Markdown notes app. Your notes stay in a folder you choose, and the app treats each top-level folder as a project.

        ## Core Features

        - Plain Markdown notes stored in the filesystem
        - YAML frontmatter metadata for title and timestamps
        - Sidebar with projects, pinned notes, and recent notes
        - Drag and drop for moving folders and notes
        - Markdown preview and note statistics
        - Quick Open and Fuzzy Search for fast navigation
        - Autosave while editing

        ## How Yapa Is Organized

        - A Yapa folder is the root folder you open in the app
        - Each top-level folder is shown as a project
        - Notes are `.md` files inside those project folders
        - Search indexes your notes locally using SQLite FTS5

        ## Keyboard Shortcuts

        - `⌘N` New Note
        - `⌘⇧N` New Project
        - `⌘O` Select Yapa Folder
        - `⌘F` Find in Document
        - `⌘⇧F` Fuzzy Search
        - `⌘K` Quick Open
        - `⌘M` Move Note
        - `⌘⇧R` Rename item from context menus
        - `⌘⇧/` Open Yapa Help

        ## Tips

        - Use the top toolbar in the sidebar to create notes, create projects, or change the Yapa root folder.
        - New notes focus the title field automatically so you can start naming them immediately.
        - Drop folders onto other folders to reorganize projects.
        - Drop a folder onto the Projects section to make it top-level again.
        - Use Quick Open when you know the note title, and Fuzzy Search when you want content matches.
        """
    }
}

extension Notification.Name {
    static let createNewNote = Notification.Name("createNewNote")
    static let createNewFolder = Notification.Name("createNewFolder")
    static let focusSearch = Notification.Name("focusSearch")
    static let openQuickSwitcher = Notification.Name("openQuickSwitcher")
    static let openFuzzySearch = Notification.Name("openFuzzySearch")
    static let insertTemplate = Notification.Name("insertTemplate")
    static let renameSelectedItem = Notification.Name("renameSelectedItem")
}
