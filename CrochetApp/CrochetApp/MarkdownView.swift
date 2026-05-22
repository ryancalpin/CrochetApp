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
    static func htmlDocument(body: String, title: String = "Crochet Pattern", accentHex: String = "#7B6FA0") -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(title)</title>
        <style>
          :root {
            --bg: #fafaf8;
            --fg: #2c2c2e;
            --accent: \(accentHex);
            --accent-light: #f0f0ee;
            --border: #e0e0e0;
            --code-bg: #f0f0f0;
            --blockquote-bg: #f2f2f0;
            --link: \(accentHex);
            --h1: \(accentHex);
          }
          @media (prefers-color-scheme: dark) {
            :root {
              --bg: #1e1e1e;
              --fg: #f0f0f0;
              --accent: \(accentHex);
              --accent-light: #2a2a2a;
              --border: #3a3a3a;
              --code-bg: #252525;
              --blockquote-bg: #252525;
              --link: \(accentHex);
              --h1: \(accentHex);
            }
          }
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            font-size: 15px;
            line-height: 1.7;
            color: var(--fg);
            background: var(--bg);
            padding: 28px 36px 60px 36px;
            max-width: 820px;
            margin: 0 auto;
          }
          h1 { color: var(--h1); font-size: 2em; margin: 1.2em 0 0.5em; border-bottom: 2px solid var(--accent); padding-bottom: 0.3em; }
          h2 { color: var(--accent); font-size: 1.5em; margin: 1.1em 0 0.4em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
          h3 { font-size: 1.2em; margin: 1em 0 0.35em; color: var(--accent); }
          h4, h5, h6 { margin: 0.8em 0 0.3em; }
          p { margin: 0.6em 0; }
          a { color: var(--link); text-decoration: none; }
          a:hover { text-decoration: underline; }
          code {
            font-family: 'SF Mono', Menlo, Consolas, monospace;
            font-size: 0.88em;
            background: var(--code-bg);
            padding: 2px 5px;
            border-radius: 4px;
          }
          pre {
            background: var(--code-bg);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 16px;
            overflow-x: auto;
            margin: 1em 0;
          }
          pre code { background: none; padding: 0; font-size: 0.9em; }
          ul, ol { margin: 0.6em 0 0.6em 1.6em; }
          li { margin: 0.25em 0; }
          blockquote {
            border-left: 4px solid var(--accent);
            background: var(--blockquote-bg);
            margin: 1em 0;
            padding: 10px 16px;
            border-radius: 0 6px 6px 0;
            color: var(--fg);
            font-style: italic;
          }
          table {
            border-collapse: collapse;
            width: 100%;
            margin: 1em 0;
          }
          th, td {
            border: 1px solid var(--border);
            padding: 8px 12px;
            text-align: left;
          }
          th {
            background: var(--accent-light);
            font-weight: 600;
          }
          tr:nth-child(even) td { background: rgba(0,0,0,0.02); }
          hr {
            border: none;
            border-top: 2px solid var(--border);
            margin: 1.5em 0;
          }
          del { color: #888; }
          img { max-width: 100%; border-radius: 6px; }
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
    var scrollToRow: Int = 0
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

        if scrollToRow != context.coordinator.lastScrollRow, scrollToRow > 0 {
            context.coordinator.lastScrollRow = scrollToRow
            let js = """
            (function(){
                var pat=new RegExp('\\\\b(Row|Rnd|Round)\\\\s+\(scrollToRow)\\\\b','i');
                var els=document.querySelectorAll('p,li,h1,h2,h3,h4,h5,h6');
                for(var i=0;i<els.length;i++){
                    if(pat.test(els[i].textContent)){
                        els[i].scrollIntoView({behavior:'smooth',block:'start'});break;
                    }
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
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
        var lastScrollRow: Int = 0
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
                div.style.cssText = 'border-left:2px solid '+AMBER+';padding-left:10px;margin:4px 0 8px 0;font-style:italic;color:#999;font-size:11px;cursor:pointer';
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
                input.style.cssText = 'flex:1;border:none;border-bottom:1px solid '+AMBER+';background:transparent;font-style:italic;color:#999;font-size:11px;outline:none;padding:2px 0';
                input.addEventListener('keydown', function(e) {
                  if (e.key === 'Enter') { e.preventDefault(); saveNote(key, input.value, block, container); }
                  else if (e.key === 'Escape') { container.remove(); }
                });
                container.appendChild(input);
                if (existingText) {
                  var del = document.createElement('a');
                  del.textContent = 'Delete';
                  del.href = '#';
                  del.style.cssText = 'color:#999;font-size:10px;text-decoration:none';
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
    var scrollToRow: Int = 0
    var abbreviationDict: [String: String] = [:]

    @ObservedObject private var settings = AppSettings.shared
    @State private var markdownContent: String = ""
    @State private var htmlContent: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private let bridge: AnnotationBridge

    init(fileURL: URL?, library: PatternLibrary, scrollToRow: Int = 0, abbreviationDict: [String: String] = [:]) {
        self.fileURL = fileURL
        self.library = library
        self.scrollToRow = scrollToRow
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
                    scrollToRow: scrollToRow,
                    abbreviationDict: abbreviationDict
                )
            }
        }
        .onChange(of: fileURL) { newURL in
            loadFile(url: newURL)
        }
        .onChange(of: settings.rowColorHex) { _ in
            // Regenerate HTML so CSS accent color reflects the new theme color.
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
            accentHex: settings.rowColorHex
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

        let accentHex = settings.rowColorHex

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
                    accentHex: accentHex
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
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Pattern Open")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text("Add a pattern from the sidebar — click the ＋ button or drag a Markdown, PDF, or text file in.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
