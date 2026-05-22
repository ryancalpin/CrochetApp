import WebKit

/// Receives messages from the annotation JavaScript running in WKWebView.
/// Message format: { "action": "save" | "delete", "key": String, "text": String }
/// Key is the first 64 characters of the block's text content (fingerprint).
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
              let key = body["key"] as? String
        else { return }

        switch action {
        case "save":
            let text = (body["text"] as? String) ?? ""
            library?.updateNote(key: key, text: text.isEmpty ? nil : text)
        case "delete":
            library?.updateNote(key: key, text: nil)
        default:
            break
        }
    }
}
