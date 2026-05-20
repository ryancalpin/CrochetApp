import WebKit

/// Receives messages from the annotation JavaScript running in WKWebView.
/// Message format: { "action": "save" | "delete", "index": Int, "text": String }
final class AnnotationBridge: NSObject, WKScriptMessageHandler {

    weak var library: PatternLibrary?

    init(library: PatternLibrary) {
        self.library = library
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "AnnotationBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              let index = body["index"] as? Int
        else { return }

        switch action {
        case "save":
            let text = (body["text"] as? String) ?? ""
            library?.updateNote(index: index, text: text.isEmpty ? nil : text)
        case "delete":
            library?.updateNote(index: index, text: nil)
        default:
            break
        }
    }
}
