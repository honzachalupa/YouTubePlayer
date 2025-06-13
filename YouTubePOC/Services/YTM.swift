//
//  YTM.swift
//  YouTubePOC
//

import Foundation
import YouTubeKit
import SwiftUI
import CryptoKit

class YouTubeModelWrapper: ObservableObject {
    let model: YouTubeModel
    
    @Published var cookies: String {
        didSet {
            print("YouTubeModelWrapper: Setting cookies to: \(cookies)")
            model.cookies = cookies
            UserDefaults.standard.set(cookies, forKey: "ytm_cookies")
            model.alwaysUseCookies = !cookies.isEmpty
            UserDefaults.standard.set(!cookies.isEmpty, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var alwaysUseCookies: Bool {
        didSet {
            print("YouTubeModelWrapper: Setting alwaysUseCookies to: \(alwaysUseCookies)")
            model.alwaysUseCookies = alwaysUseCookies
            UserDefaults.standard.set(alwaysUseCookies, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var accessToken: String? {
        didSet {
            print("YouTubeModelWrapper: Setting accessToken to: \(accessToken ?? "nil")")
            // If YouTubeKit supports setting a token, set it here. Otherwise, store for use in API calls.
        }
    }
    
    init(model: YouTubeModel) {
        print("YouTubeModelWrapper: Initializing with model")
        self.model = model
        self.cookies = UserDefaults.standard.string(forKey: "ytm_cookies") ?? ""
        self.alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        model.cookies = self.cookies
        model.alwaysUseCookies = self.alwaysUseCookies
        print("YouTubeModelWrapper: Initial state:")
        print("- Cookies: \(self.cookies)")
        print("- Always use cookies: \(self.alwaysUseCookies)")
    }
    
    func generateSAPISIDHASH(forCookies cookies: String, time: Int? = nil) -> String? {
        // Extract SAPISID from cookies
        guard let SAPISID = cookies.ytkFirstGroupMatch(for: "SAPISID=([^\\s|;]*)") else {
            // If no SAPISID in cookies, check if it's an OAuth token
            if cookies.contains("OAUTH_TOKEN=") {
                // Use part of the OAuth token as SAPISID
                guard let token = cookies.ytkFirstGroupMatch(for: "OAUTH_TOKEN=([^\\s|;]*)") else {
                    return nil
                }
                let sapisidValue = String(token.prefix(40))
                let currentTime = time ?? Int(Date().timeIntervalSince1970)
                let hashInput = "\(currentTime) \(sapisidValue) https://www.youtube.com"
                let inputData = Data(hashInput.utf8)
                let hashed = Insecure.SHA1.hash(data: inputData)
                let hashString = hashed.map { String(format: "%02hhx", $0) }.joined()
                return "SAPISIDHASH \(currentTime)_\(hashString)"
            }
            return nil
        }
        
        // Generate hash using SAPISID
        let currentTime = time ?? Int(Date().timeIntervalSince1970)
        let hashInput = "\(currentTime) \(SAPISID) https://www.youtube.com"
        let inputData = Data(hashInput.utf8)
        let hashed = Insecure.SHA1.hash(data: inputData)
        let hashString = hashed.map { String(format: "%02hhx", $0) }.joined()
        return "SAPISIDHASH \(currentTime)_\(hashString)"
    }
}

final class YTM {
    // Private initializer to enforce singleton pattern
    private init() {}
    
    // The single shared instance
    private static let instance = YouTubeModel()
    private static let wrapper = YouTubeModelWrapper(model: instance)
    
    static var shared: YouTubeModelWrapper {
        return wrapper
    }
    
    static var cookies: String {
        get { shared.cookies }
        set { 
            print("YTM: Setting cookies to: \(newValue)")
            shared.cookies = newValue 
        }
    }
    
    static var alwaysUseCookies: Bool {
        get { shared.alwaysUseCookies }
        set { 
            print("YTM: Setting alwaysUseCookies to: \(newValue)")
            shared.alwaysUseCookies = newValue 
        }
    }
    
    static var accessToken: String? {
        get { shared.accessToken }
        set { shared.accessToken = newValue }
    }
    
    static func setup() {
        print("YTM: Setting up...")
        // Initialize with default settings
        instance.selectedLocale = "en-US"
        
        // Restore cookies if available
        if let savedCookies = UserDefaults.standard.string(forKey: "ytm_cookies") {
            print("YTM: Found saved cookies: \(savedCookies)")
            cookies = savedCookies
            alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
            print("YTM: Restored settings:")
            print("- Cookies: \(cookies)")
            print("- Always use cookies: \(alwaysUseCookies)")
        } else {
            print("YTM: No saved cookies found during setup")
        }
        
        // Verify the setup
        print("YTM: Setup complete. Current state:")
        print("- Model cookies: \(model.cookies)")
        print("- Wrapper cookies: \(shared.cookies)")
        print("- Stored cookies: \(UserDefaults.standard.string(forKey: "ytm_cookies") ?? "nil")")
    }
    
    static func reset() {
        print("YTM: Starting reset...")
        
        // Clear the model state
        cookies = ""
        alwaysUseCookies = false
        
        // Clear all stored data
        UserDefaults.standard.removeObject(forKey: "ytm_cookies")
        UserDefaults.standard.removeObject(forKey: "ytm_always_use_cookies")
        UserDefaults.standard.removeObject(forKey: "youtube_access_token")
        UserDefaults.standard.removeObject(forKey: "youtube_user_info")
        
        // Force UserDefaults to save immediately
        UserDefaults.standard.synchronize()
        
        print("YTM: Reset complete. Current state:")
        print("- Model cookies: \(model.cookies)")
        print("- Wrapper cookies: \(shared.cookies)")
        print("- Stored cookies: \(UserDefaults.standard.string(forKey: "ytm_cookies") ?? "nil")")
    }
    
    static var model: YouTubeModel {
        return instance
    }
} 