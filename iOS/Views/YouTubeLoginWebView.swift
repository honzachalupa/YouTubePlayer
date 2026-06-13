import SwiftUI
import WebKit

struct YouTubeLoginWebView: UIViewRepresentable {
    // This closure will be called with the cookie string when login is successful
    let onComplete: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator
        
        // Load the YouTube sign-in page
        let url = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Dm%26hl%3Den%26next%3D%252F&uilel=3&hl=en")!
        webView.load(URLRequest(url: url))
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubeLoginWebView

        init(_ parent: YouTubeLoginWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // After a navigation event, check if we have the necessary login cookies
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let youtubeCookies = cookies.filter { $0.domain.contains("youtube.com") }
                
                // The presence of 'SAPISID' is a good indicator of being logged in.
                let hasSapisid = youtubeCookies.contains(where: { $0.name == "SAPISID" })
                
                // The URL can also tell us if we've been redirected back to YouTube main page
                let onYouTubeHomepage = webView.url?.host?.contains("youtube.com") ?? false

                if onYouTubeHomepage && hasSapisid {
                    // We are logged in. Extract all cookies and call the completion handler.
                    let cookieString = youtubeCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    
                    DispatchQueue.main.async {
                        self.parent.onComplete(cookieString)
                    }
                }
            }
        }
    }
} 
