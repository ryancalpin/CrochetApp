import SwiftUI
import WebKit

// MARK: - Simple Markdown to HTML Converter
struct MarkdownConverter {
    static func convert(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var html = ""
        var inCodeBlock = false
        var inOrderedList = false
        var inUnorderedList = false
        var codeBuffer: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block fence
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // Close code block
                    let codeContent = codeBuffer.joined(separator: "\n")
                        .replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                    html += "<pre><code>\(codeContent)</code></pre>\n"
                    codeBuffer = []
                    inCodeBlock = false
                } else {
                    if inOrderedList { html += "</ol>\n"; inOrderedList = false }
                    if inUnorderedList { html += "</ul>\n"; inUnorderedList = false }
                    inCodeBlock = true
                }
                i += 1
                continue
            }

            if inCodeBlock {
                codeBuffer.append(line)
                i += 1
                continue
            }

            // Close lists if next line is not a list item
            let isOrderedItem = line.range(of: #"^\d+\. "#, options: .regularExpression) != nil
            let isUnorderedItem = line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")

            if inOrderedList && !isOrderedItem {
                html += "</ol>\n"
                inOrderedList = false
            }
            if inUnorderedList && !isUnorderedItem {
                html += "</ul>\n"
                inUnorderedList = false
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                html += "<br>\n"
                i += 1
                continue
            }

            // Horizontal rule
            if line == "---" || line == "***" || line == "___" {
                html += "<hr>\n"
                i += 1
                continue
            }

            // Headers
            if line.hasPrefix("######") {
                html += "<h6>\(inlineMarkdown(String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)))</h6>\n"
            } else if line.hasPrefix("#####") {
                html += "<h5>\(inlineMarkdown(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)))</h5>\n"
            } else if line.hasPrefix("####") {
                html += "<h4>\(inlineMarkdown(String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)))</h4>\n"
            } else if line.hasPrefix("###") {
                html += "<h3>\(inlineMarkdown(String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)))</h3>\n"
            } else if line.hasPrefix("##") {
                html += "<h2>\(inlineMarkdown(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)))</h2>\n"
            } else if line.hasPrefix("#") {
                html += "<h1>\(inlineMarkdown(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))</h1>\n"
            }
            // Blockquote
            else if line.hasPrefix("> ") {
                html += "<blockquote>\(inlineMarkdown(String(line.dropFirst(2))))</blockquote>\n"
            }
            // Ordered list
            else if isOrderedItem {
                if !inOrderedList {
                    html += "<ol>\n"
                    inOrderedList = true
                }
                if let range = line.range(of: #"^\d+\. "#, options: .regularExpression) {
                    let content = String(line[range.upperBound...])
                    html += "<li>\(inlineMarkdown(content))</li>\n"
                }
            }
            // Unordered list
            else if isUnorderedItem {
                if !inUnorderedList {
                    html += "<ul>\n"
                    inUnorderedList = true
                }
                let content = String(line.dropFirst(2))
                html += "<li>\(inlineMarkdown(content))</li>\n"
            }
            // Table row
            else if line.hasPrefix("|") {
                // Simple table: collect all pipe-delimited lines
                var tableLines: [String] = []
                var j = i
                while j < lines.count && lines[j].hasPrefix("|") {
                    tableLines.append(lines[j])
                    j += 1
                }
                if tableLines.count >= 2 {
                    html += buildTable(tableLines)
                    i = j
                    continue
                } else {
                    html += "<p>\(inlineMarkdown(line))</p>\n"
                }
            }
            // Normal paragraph
            else {
                html += "<p>\(inlineMarkdown(line))</p>\n"
            }

            i += 1
        }

        // Close any open lists
        if inOrderedList { html += "</ol>\n" }
        if inUnorderedList { html += "</ul>\n" }
        if inCodeBlock {
            let codeContent = codeBuffer.joined(separator: "\n")
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            html += "<pre><code>\(codeContent)</code></pre>\n"
        }

        return html
    }

    private static func buildTable(_ lines: [String]) -> String {
        var html = "<table>\n"
        for (index, line) in lines.enumerated() {
            // Skip separator row (contains only |, -, :, space)
            let stripped = line.trimmingCharacters(in: .whitespaces)
            let isSeparator = stripped.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
            if isSeparator { continue }

            let cells = line.components(separatedBy: "|")
                .dropFirst()  // drop empty before first |
                .dropLast()   // drop empty after last |
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let tag = index == 0 ? "th" : "td"
            html += "<tr>"
            for cell in cells {
                html += "<\(tag)>\(inlineMarkdown(cell))</\(tag)>"
            }
            html += "</tr>\n"
        }
        html += "</table>\n"
        return html
    }

    // MARK: - Inline Markdown (bold, italic, code, links, images)
    static func inlineMarkdown(_ text: String) -> String {
        var result = text

        // Escape HTML entities first
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")

        // Inline code (before bold/italic to avoid conflicts)
        result = applyPattern(result, pattern: #"`([^`]+)`"#, replacement: "<code>$1</code>")

        // Bold + italic (***text***)
        result = applyPattern(result, pattern: #"\*\*\*(.+?)\*\*\*"#, replacement: "<strong><em>$1</em></strong>")

        // Bold (**text** or __text__)
        result = applyPattern(result, pattern: #"\*\*(.+?)\*\*"#, replacement: "<strong>$1</strong>")
        result = applyPattern(result, pattern: #"__(.+?)__"#, replacement: "<strong>$1</strong>")

        // Italic (*text* or _text_)
        result = applyPattern(result, pattern: #"\*(.+?)\*"#, replacement: "<em>$1</em>")
        result = applyPattern(result, pattern: #"_(.+?)_"#, replacement: "<em>$1</em>")

        // Strikethrough (~~text~~)
        result = applyPattern(result, pattern: #"~~(.+?)~~"#, replacement: "<del>$1</del>")

        // Images ![alt](url)
        result = applyPattern(result, pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#, replacement: "<img alt=\"$1\" src=\"$2\" style=\"max-width:100%;\">")

        // Links [text](url)
        result = applyPattern(result, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, replacement: "<a href=\"$2\">$1</a>")

        return result
    }

    private static func applyPattern(_ input: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
    }

    // MARK: - Full HTML Document
    /// Renders the pattern document using the supplied theme palette so the document
    /// background, text, dividers, and accent all match the app's selected theme.
    static func htmlDocument(
        body: String,
        title: String = "Crochet Pattern",
        palette: AppTheme.Palette = AppSettings.shared.appTheme.palette
    ) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(title)</title>
        <style>
          /* Palette is sourced from the app's selected AppTheme (surface / text /
             divider / accent) so the document blends seamlessly with the rest of the UI. */
          :root {
            --bg: \(palette.surfaceL);        /* surface */
            --fg: \(palette.textL);        /* textPrimary */
            --muted: \(palette.text2L);     /* textSecondary */
            --accent: \(palette.accent);
            --border: \(palette.divL);    /* divider */
            --raised: \(palette.raisedL);    /* surfaceRaised */
            --row-alt: rgba(0, 0, 0, 0.04);
          }
          @media (prefers-color-scheme: dark) {
            :root {
              --bg: \(palette.surfaceD);
              --fg: \(palette.textD);
              --muted: \(palette.text2D);
              --accent: \(palette.accent);
              --border: \(palette.divD);
              --raised: \(palette.raisedD);
              --row-alt: rgba(255, 255, 255, 0.035);
            }
          }
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif;
            font-size: 16px;
            line-height: 1.65;
            color: var(--fg);
            background: var(--bg);
            padding: 32px 40px 72px 40px;
            max-width: 760px;
            margin: 0 auto;
            -webkit-font-smoothing: antialiased;
          }
          h1 {
            color: var(--fg); font-size: 1.9em; font-weight: 700; letter-spacing: -0.01em;
            margin: 0 0 0.6em; padding-bottom: 0.3em; border-bottom: 2px solid var(--accent);
          }
          h2 {
            color: var(--fg); font-size: 1.4em; font-weight: 650; letter-spacing: -0.01em;
            margin: 1.6em 0 0.5em; padding-bottom: 0.25em; border-bottom: 1px solid var(--border);
          }
          h3 { color: var(--fg); font-size: 1.15em; font-weight: 600; margin: 1.3em 0 0.4em; }
          h4, h5, h6 { color: var(--fg); font-weight: 600; margin: 1em 0 0.35em; }
          p { margin: 0.7em 0; }
          a { color: var(--accent); text-decoration: none; }
          a:hover { text-decoration: underline; }
          code {
            font-family: 'SF Mono', Menlo, Consolas, monospace;
            font-size: 0.86em;
            background: var(--raised);
            border: 1px solid var(--border);
            padding: 1px 5px;
            border-radius: 5px;
          }
          pre {
            background: var(--raised);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 16px;
            overflow-x: auto;
            margin: 1em 0;
          }
          pre code { background: none; border: none; padding: 0; font-size: 0.9em; }
          ul, ol { margin: 0.7em 0 0.7em 1.5em; }
          li { margin: 0.3em 0; }
          blockquote {
            border-left: 3px solid var(--accent);
            background: var(--raised);
            margin: 1em 0;
            padding: 12px 16px;
            border-radius: 8px;
            color: var(--fg);
          }
          table {
            border-collapse: separate;
            border-spacing: 0;
            width: 100%;
            margin: 1.2em 0;
            border: 1px solid var(--border);
            border-radius: 10px;
            overflow: hidden;
          }
          th, td { padding: 9px 14px; text-align: left; border-bottom: 1px solid var(--border); }
          tr:last-child td { border-bottom: none; }
          th { background: var(--raised); font-weight: 600; color: var(--fg); }
          tr:nth-child(even) td { background: var(--row-alt); }
          hr { border: none; border-top: 1px solid var(--border); margin: 1.8em 0; }
          del { color: var(--muted); }
          img { max-width: 100%; border-radius: 8px; }
          strong { font-weight: 700; }
          em { font-style: italic; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

// MARK: - WKWebView Wrapper
struct MarkdownWebView: NSViewRepresentable {
    let htmlContent: String
    let annotations: [String: String]
    let bridge: AnnotationBridge
    var abbreviationDict: [String: String] = [:]

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(bridge, name: "AnnotationBridge")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingAnnotations = annotations
        context.coordinator.pendingAbbreviationDict = abbreviationDict

        if htmlContent != context.coordinator.lastLoadedHTML {
            context.coordinator.lastLoadedHTML = htmlContent
            context.coordinator.lastAbbreviationDict = [:]
            webView.loadHTMLString(htmlContent, baseURL: nil)
            return
        }

        if !abbreviationDict.isEmpty, abbreviationDict != context.coordinator.lastAbbreviationDict {
            context.coordinator.lastAbbreviationDict = abbreviationDict
            context.coordinator.injectAbbreviationTooltips(into: webView, dict: abbreviationDict)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(annotations: annotations)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var pendingAnnotations: [String: String]
        var pendingAbbreviationDict: [String: String] = [:]
        var lastLoadedHTML: String = ""
        var lastAbbreviationDict: [String: String] = [:]

        init(annotations: [String: String]) {
            self.pendingAnnotations = annotations
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectAnnotationJS(into: webView, annotations: pendingAnnotations)
            if !pendingAbbreviationDict.isEmpty {
                lastAbbreviationDict = pendingAbbreviationDict
                injectAbbreviationTooltips(into: webView, dict: pendingAbbreviationDict)
            }
        }

        private func injectAnnotationJS(into webView: WKWebView, annotations: [String: String]) {
            let annotationsJSON: String
            if let data = try? JSONSerialization.data(withJSONObject: annotations),
               let str = String(data: data, encoding: .utf8) {
                annotationsJSON = str
            } else {
                annotationsJSON = "{}"
            }

            let js = """
            (function() {
              var AMBER = '#e8b84b';
              var existingNotes = \(annotationsJSON);
              var blocks = Array.from(document.querySelectorAll('p, li'));

              function fingerprint(text) {
                return text.trim().toLowerCase().slice(0, 64);
              }
              function safeId(fp) {
                return fp.replace(/[^a-z0-9]/g, '_').slice(0, 32);
              }
              function noteId(fp) { return 'ann-note-' + safeId(fp); }
              function editorId(fp) { return 'ann-editor-' + safeId(fp); }

              blocks.forEach(function(block) {
                var key = fingerprint(block.textContent);
                if (existingNotes[key]) {
                  insertNoteElement(block, key, existingNotes[key]);
                }
              });

              // Floating pencil button
              var noteBtn = document.createElement('div');
              noteBtn.id = '__notebtn';
              noteBtn.textContent = '✎';
              noteBtn.title = 'Add note';
              noteBtn.style.cssText = 'position:fixed;background:var(--accent);opacity:0.85;color:white;' +
                  'width:20px;height:20px;border-radius:50%;font-size:11px;display:none;' +
                  'align-items:center;justify-content:center;cursor:pointer;z-index:9000;' +
                  'box-shadow:0 1px 4px rgba(0,0,0,0.3);user-select:none;line-height:1;';
              document.body.appendChild(noteBtn);

              var hoveredBlock = null, hoveredKey = null, hideTimer = null;

              blocks.forEach(function(block) {
                block.addEventListener('mouseenter', function() {
                  clearTimeout(hideTimer);
                  hoveredBlock = block;
                  hoveredKey = fingerprint(block.textContent);
                  var rect = block.getBoundingClientRect();
                  noteBtn.style.left = (rect.right - 26) + 'px';
                  noteBtn.style.top = Math.max(4, rect.top) + 'px';
                  noteBtn.style.display = 'flex';
                });
                block.addEventListener('mouseleave', function(e) {
                  if (e.relatedTarget === noteBtn) return;
                  hideTimer = setTimeout(function() { noteBtn.style.display = 'none'; }, 120);
                });
              });

              noteBtn.addEventListener('mouseenter', function() { clearTimeout(hideTimer); });
              noteBtn.addEventListener('mouseleave', function() { noteBtn.style.display = 'none'; });
              noteBtn.addEventListener('click', function(e) {
                e.stopPropagation();
                noteBtn.style.display = 'none';
                openEditor(hoveredBlock, hoveredKey);
              });

              // Click outside editor to dismiss
              document.addEventListener('click', function(e) {
                var editor = document.querySelector('[id^="ann-editor-"]');
                if (editor && !editor.contains(e.target)) { editor.remove(); }
              });

              function insertNoteElement(block, key, text) {
                var existing = document.getElementById(noteId(key));
                if (existing) { existing.remove(); }
                var div = document.createElement('div');
                div.id = noteId(key);
                div.style.cssText = 'border-left:2px solid '+AMBER+';padding-left:10px;margin:6px 0 10px 0;font-style:italic;color:var(--muted);font-size:13px;cursor:pointer';
                div.textContent = text;
                div.addEventListener('click', function(e) {
                  e.stopPropagation();
                  openEditor(block, key, text);
                });
                block.insertAdjacentElement('afterend', div);
              }

              function openEditor(block, key, existingText) {
                document.querySelectorAll('[id^="ann-editor-"]').forEach(function(el) { el.remove(); });
                var container = document.createElement('div');
                container.id = editorId(key);
                container.style.cssText = 'border-left:2px solid '+AMBER+';padding-left:10px;margin:4px 0 8px 0;display:flex;align-items:center;gap:8px';
                var input = document.createElement('input');
                input.type = 'text';
                input.value = existingText || '';
                input.placeholder = 'Add a note…';
                input.style.cssText = 'flex:1;border:none;border-bottom:1px solid '+AMBER+';background:transparent;font-style:italic;color:var(--fg);font-size:13px;outline:none;padding:2px 0';
                input.addEventListener('keydown', function(e) {
                  if (e.key === 'Enter') { e.preventDefault(); saveNote(key, input.value, block, container); }
                  else if (e.key === 'Escape') { container.remove(); }
                });
                container.appendChild(input);
                if (existingText) {
                  var del = document.createElement('a');
                  del.textContent = 'Delete';
                  del.href = '#';
                  del.style.cssText = 'color:var(--muted);font-size:12px;text-decoration:none';
                  del.addEventListener('click', function(e) { e.preventDefault(); deleteNote(key, container); });
                  container.appendChild(del);
                }
                block.insertAdjacentElement('afterend', container);
                input.focus();
              }

              function saveNote(key, text, block, container) {
                container.remove();
                var noteEl = document.getElementById(noteId(key));
                if (noteEl) { noteEl.remove(); }
                if (text.trim()) {
                  insertNoteElement(block, key, text.trim());
                  window.webkit.messageHandlers.AnnotationBridge.postMessage({action:'save',key:key,text:text.trim()});
                } else {
                  window.webkit.messageHandlers.AnnotationBridge.postMessage({action:'delete',key:key,text:''});
                }
              }

              function deleteNote(key, container) {
                container.remove();
                var noteEl = document.getElementById(noteId(key));
                if (noteEl) { noteEl.remove(); }
                window.webkit.messageHandlers.AnnotationBridge.postMessage({action:'delete',key:key,text:''});
              }
            })();
            """

            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[AnnotationJS] \(error)")
                }
            }
        }

        func injectAbbreviationTooltips(into webView: WKWebView, dict: [String: String]) {
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let json = String(data: data, encoding: .utf8) else { return }
            let js = """
            (function(){
                var abbrevs=\(json);
                var keys=Object.keys(abbrevs).sort(function(a,b){return b.length-a.length;});
                if(!keys.length)return;

                // Floating tooltip element
                var tip=document.createElement('div');
                tip.id='__abbrtip';
                tip.style.cssText='position:fixed;background:rgba(30,30,30,0.92);color:#f2f2f7;' +
                    'padding:6px 10px;border-radius:7px;font-size:12px;line-height:1.4;' +
                    'z-index:9999;pointer-events:none;max-width:240px;display:none;' +
                    'box-shadow:0 2px 10px rgba(0,0,0,0.4);';
                document.body.appendChild(tip);

                function showTip(e,text){
                    tip.textContent=text;
                    var x=Math.min(e.clientX+14,window.innerWidth-254);
                    var y=e.clientY-44;
                    if(y<4)y=e.clientY+18;
                    tip.style.left=x+'px';tip.style.top=y+'px';tip.style.display='block';
                }
                function hideTip(){ tip.style.display='none'; }
                document.addEventListener('scroll',hideTip,true);

                var pattern=new RegExp('\\\\b('+keys.map(function(k){
                    return k.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&');
                }).join('|')+')\\\\b','g');

                function processNode(node){
                    if(node.nodeType===Node.TEXT_NODE){
                        var text=node.textContent;
                        if(!pattern.test(text))return;
                        pattern.lastIndex=0;
                        var frag=document.createDocumentFragment();
                        var last=0,m;
                        while((m=pattern.exec(text))!==null){
                            if(m.index>last)frag.appendChild(document.createTextNode(text.slice(last,m.index)));
                            var span=document.createElement('span');
                            var meaning=abbrevs[m[0]]||abbrevs[m[0].toLowerCase()]||m[0];
                            span.textContent=m[0];
                            span.style.cssText='border-bottom:1px dotted currentColor;cursor:help;';
                            span.addEventListener('mouseover',function(ev){showTip(ev,meaning);});
                            span.addEventListener('mouseout',hideTip);
                            frag.appendChild(span);
                            last=m.index+m[0].length;
                        }
                        if(last<text.length)frag.appendChild(document.createTextNode(text.slice(last)));
                        node.parentNode.replaceChild(frag,node);
                    } else if(node.nodeType===Node.ELEMENT_NODE &&
                              !['SPAN','CODE','PRE','SCRIPT','STYLE'].includes(node.tagName)){
                        Array.from(node.childNodes).forEach(processNode);
                    }
                }
                Array.from(document.querySelectorAll('p,li')).forEach(processNode);
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: - Markdown View
struct MarkdownView: View {
    let fileURL: URL?
    @ObservedObject var library: PatternLibrary
    var abbreviationDict: [String: String] = [:]

    @ObservedObject private var settings = AppSettings.shared
    @State private var markdownContent: String = ""
    @State private var htmlContent: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private let bridge: AnnotationBridge

    init(fileURL: URL?, library: PatternLibrary, abbreviationDict: [String: String] = [:]) {
        self.fileURL = fileURL
        self.library = library
        self.abbreviationDict = abbreviationDict
        self.bridge = AnnotationBridge(library: library)
    }

    var body: some View {
        ZStack {
            if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Could not load file")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if fileURL == nil {
                EmptyMarkdownPlaceholder()
            } else if isLoading {
                ProgressView("Loading pattern…")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                MarkdownWebView(
                    htmlContent: htmlContent,
                    annotations: (library.activeEntry?.annotations ?? [:]),
                    bridge: bridge,
                    abbreviationDict: abbreviationDict
                )
            }
        }
        .onChange(of: fileURL) { newURL in
            loadFile(url: newURL)
        }
        .onChange(of: settings.appTheme) { _ in
            // Regenerate HTML so the document palette reflects the new theme.
            reloadHTML()
        }
        .onAppear {
            loadFile(url: fileURL)
        }
    }

    private func reloadHTML() {
        guard !markdownContent.isEmpty, let url = fileURL else { return }
        let body = MarkdownConverter.convert(markdownContent)
        htmlContent = MarkdownConverter.htmlDocument(
            body: body,
            title: url.deletingPathExtension().lastPathComponent,
            palette: AppSettings.shared.appTheme.palette
        )
    }

    private func loadFile(url: URL?) {
        guard let url = url else {
            markdownContent = ""
            htmlContent = ""
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        let palette = AppSettings.shared.appTheme.palette

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Request access for sandboxed apps
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                let content = try String(contentsOf: url, encoding: .utf8)
                let body = MarkdownConverter.convert(content)
                let fullHTML = MarkdownConverter.htmlDocument(
                    body: body,
                    title: url.deletingPathExtension().lastPathComponent,
                    palette: palette
                )

                DispatchQueue.main.async {
                    self.markdownContent = content
                    self.htmlContent = fullHTML
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Empty State Placeholder
struct EmptyMarkdownPlaceholder: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text")
                .font(.system(size: 72))
                .foregroundColor(.textSecondary.opacity(0.5))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("No Pattern Open")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.textSecondary)

                Text("Add a pattern from the sidebar — click the ＋ button or drag a Markdown, PDF, or text file in.")
                    .font(.callout)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Resolve the surface explicitly from the live theme + appearance instead of
        // the dynamic `Color.surface` token, which AppKit caches per light/dark and
        // would otherwise keep the previous theme's background after a theme switch.
        .background(surfaceColor)
    }

    private var surfaceColor: Color {
        let p = settings.appTheme.palette
        return ThemeColor.color(colorScheme == .dark ? p.surfaceD : p.surfaceL)
    }
}
