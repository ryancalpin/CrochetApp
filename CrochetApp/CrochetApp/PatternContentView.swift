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
        view.backgroundColor = ThemeColor.surfaceNS
        context.coordinator.pdfView = view
        context.coordinator.accessing = url.startAccessingSecurityScopedResource()
        view.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url
        return view
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var pdfView: PDFView?
        var accessing = false
        var loadedURL: URL?
    }
}
