import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Top-level pattern viewer — dispatches to PDFKitView or MarkdownView based on file extension.
struct PatternContentView: View {
    let fileURL: URL?
    @ObservedObject var library: PatternLibrary
    var scrollToRow: Int = 0
    var abbreviationDict: [String: String] = [:]

    var body: some View {
        Group {
            if let url = fileURL {
                if url.pathExtension.lowercased() == "pdf" {
                    PDFKitView(url: url, scrollToRow: scrollToRow)
                } else {
                    MarkdownView(fileURL: url, library: library,
                                 scrollToRow: scrollToRow, abbreviationDict: abbreviationDict)
                }
            } else {
                MarkdownView(fileURL: nil, library: library,
                             scrollToRow: scrollToRow, abbreviationDict: abbreviationDict)
            }
        }
    }
}

// MARK: - PDFKit viewer

struct PDFKitView: NSViewRepresentable {
    let url: URL
    var scrollToRow: Int = 0

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(named: "viewBackground") ?? .windowBackgroundColor
        context.coordinator.pdfView = view
        return view
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        // Only reload document if URL changed
        if context.coordinator.lastURL != url {
            context.coordinator.lastURL = url
            context.coordinator.lastScrollRow = 0
            if let doc = PDFDocument(url: url) {
                pdfView.document = doc
            }
        }

        // Scroll to row if changed
        if scrollToRow != context.coordinator.lastScrollRow, scrollToRow > 0,
           let doc = pdfView.document {
            context.coordinator.lastScrollRow = scrollToRow
            let terms = ["Row \(scrollToRow)", "Rnd \(scrollToRow)", "Round \(scrollToRow)"]
            for term in terms {
                if let sel = doc.findString(term, withOptions: .caseInsensitive).first {
                    pdfView.go(to: sel)
                    pdfView.setCurrentSelection(sel, animate: true)
                    break
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var pdfView: PDFView?
        var lastURL: URL?
        var lastScrollRow: Int = 0
    }
}
