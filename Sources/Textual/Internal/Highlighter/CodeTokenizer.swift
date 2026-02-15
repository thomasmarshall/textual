import Foundation
import os

#if canImport(JavaScriptCore)
  import JavaScriptCore
#endif

// MARK: - Overview
//
// CodeTokenizer wraps Prism.js via JavaScriptCore for syntax highlighting. The actor
// ensures thread-safe access to the JavaScript context.
//
// The tokenizer gracefully degrades when JavaScriptCore is unavailable, when the
// Prism bundle is missing, or when tokenization fails. In all cases, it returns
// a single plain token containing the entire code string.

public struct CodeToken: Hashable, Sendable {
  public let content: String
  public let type: StructuredText.HighlighterTheme.TokenType

  public init(content: String, type: StructuredText.HighlighterTheme.TokenType) {
    self.content = content
    self.type = type
  }
}

#if canImport(JavaScriptCore)
  public actor CodeTokenizer {
    private let context: JSContext
    private let logger = Logger(category: .codeTokenizer)

    public static let shared = CodeTokenizer()

    public init?() {
      guard let context = JSContext() else {
        logger.error("JavascriptCore is not available.")
        return nil
      }

      guard
        let bundleURL = Bundle.textual?.url(
          forResource: "prism-bundle",
          withExtension: "js"
        ),
        let script = try? String(contentsOf: bundleURL, encoding: .utf8)
      else {
        logger.error("Prism JavaScript bundle is missing.")
        return nil
      }

      context.evaluateScript(script)
      self.context = context
    }

    public func tokenize(code: String, language: String) -> [CodeToken] {
      guard
        let tokenizeCode = context.objectForKeyedSubscript("tokenizeCode"),
        let result = tokenizeCode.call(withArguments: [code, language]),
        let array = result.toArray() as? [[String: String]]
      else {
        logger.error("Tokenization failed.")
        return [CodeToken(content: code, type: .plain)]
      }

      return array.compactMap { token in
        guard
          let content = token["content"],
          let type = token["type"]
        else {
          return nil
        }
        return CodeToken(content: content, type: .init(rawValue: type))
      }
    }
  }
#else
  public actor CodeTokenizer {
    private let logger = Logger(category: .codeTokenizer)

    public static let shared = CodeTokenizer()

    public init?() {
      logger.error("JavascriptCore is not available in this platform.")
      return nil
    }

    public func tokenize(code: String, language: String) -> [CodeToken] {
      [CodeToken(content: code, type: .plain)]
    }
  }
#endif

extension Logger.Textual.Category {
  fileprivate static let codeTokenizer = Self(rawValue: "codeTokenizer")
}
