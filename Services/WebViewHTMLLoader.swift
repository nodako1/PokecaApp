//
//  WebViewHTMLLoader.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/07.
//

import Foundation
import WebKit

// JavaScript実行後のHTMLを取得するためのユーティリティクラス
final class WebViewHTMLLoader: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var htmlCompletion: ((Result<String, Error>) -> Void)?
    private var loadTimeoutTimer: Timer?
    
    // HTMLを読み込み、レンダリング後のDOMを返す
    func loadHTML(from url: URL, timeout: TimeInterval = 30) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            config.websiteDataStore = .nonPersistent() // クッキーを残さない一時的WebView
            
            let webView = WKWebView(frame: .zero, configuration: config)
            self.webView = webView
            webView.navigationDelegate = self
            
            let request = URLRequest(url: url)
            webView.load(request)
            
            htmlCompletion = { result in
                continuation.resume(with: result)
            }
            
            // タイムアウト処理（指定秒数経過したら失敗として返す）
            loadTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                self?.finish(result: .failure(NSError(domain: "WebViewHTMLLoader", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "ページの読み込みがタイムアウトしました"
                ])))
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // JavaScriptを実行してHTML文字列を取得
        webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { [weak self] result, error in
            if let error = error {
                self?.finish(result: .failure(error))
                return
            }
            if let html = result as? String {
                self?.finish(result: .success(html))
            } else {
                self?.finish(result: .failure(NSError(domain: "WebViewHTMLLoader", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "HTMLの取得に失敗しました"
                ])))
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(result: .failure(error))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(result: .failure(error))
    }
    
    // MARK: - 完了処理
    
    private func finish(result: Result<String, Error>) {
        loadTimeoutTimer?.invalidate()
        loadTimeoutTimer = nil
        htmlCompletion?(result)
        htmlCompletion = nil
        webView = nil
    }
}
