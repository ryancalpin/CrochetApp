import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Top-level pattern viewer — dispatches to PDFKitView or MarkdownView based on file extension.
struct PatternContentView: View {
    let fileURL: URL?
    @ObservedObject var library: PatternLibrary
    var abbreviationDict: [String: String] = [:]

    var body: some View {
        Group {
            if let url = fileURL {
                if url.pathExtension.lowercased() == "pdf" {
                    PDFKitView(url: url)
                } else {
                    MarkdownView(fileURL: url, library: library, abbreviationDict: abbreviationDict)
                }
            } else {
                MarkdownView(fileURL: nil, library: library, abbreviationDict: abbreviationDict)
            }
        }
    }
}

// MARK: - PDFKit viewer

struct PDFKitView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = Self.themeSurface(for: view.effectiveAppearance)
        context.coordinator.pdfView = view
        context.coordinator.accessing = url.startAccessingSecurityScopedResource()
        view.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url
        return view
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Re-resolve the background against the current theme each update so a theme
        // switch refreshes it (the parent re-renders on theme change).
        pdfView.backgroundColor = Self.themeSurface(for: pdfView.effectiveAppearance)
        // Only reload the document if the URL changed, re-scoping security access.
        if context.coordinator.loadedURL != url {
            if context.coordinator.accessing, let old = context.coordinator.loadedURL {
                old.stopAccessingSecurityScopedResource()
            }
            context.coordinator.accessing = url.startAccessingSecurityScopedResource()
            pdfView.document = PDFDocument(url: url)
            context.coordinator.loadedURL = url
        }
    }

    static func dismantleNSView(_ pdfView: PDFView, coordinator: Coordinator) {
        if coordinator.accessing, let u = coordinator.loadedURL {
            u.stopAccessingSecurityScopedResource()
        }
    }

    /// Theme surface resolved as a plain NSColor for the given appearance (avoids
    /// AppKit's per-appearance dynamic-color cache, which would go stale on a theme switch).
    private static func themeSurface(for appearance: NSAppearance) -> NSColor {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let p = AppSettings.shared.appTheme.palette
        return ThemeColor.ns(isDark ? p.surfaceD : p.surfaceL)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var pdfView: PDFView?
        var accessing = false
        var loadedURL: URL?
    }
}
