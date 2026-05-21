import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Top-level pattern viewer — dispatches to PDFKitView or MarkdownView based on file extension.
struct PatternContentView: View {
    let fileURL: URL?
    @ObservedObject var library: PatternLibrary

    var body: some View {
        Group {
            if let url = fileURL {
                if url.pathExtension.lowercased() == "pdf" {
                    PDFKitView(url: url)
                } else {
                    MarkdownView(fileURL: url, library: library)
                }
            } else {
                MarkdownView(fileURL: nil, library: library)
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
        view.backgroundColor = NSColor(named: "viewBackground") ?? .windowBackgroundColor
        return view
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
    }
}
