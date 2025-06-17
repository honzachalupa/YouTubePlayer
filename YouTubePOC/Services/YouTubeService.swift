import Foundation
import YouTubeKit
import SwiftUI
import CryptoKit

class YouTubeServiceWrapper: ObservableObject {
    let model: YouTubeModel
    
    @Published var cookies: String {
        didSet {
            model.cookies = cookies
            UserDefaults.standard.set(cookies, forKey: "ytm_cookies")
            model.alwaysUseCookies = !cookies.isEmpty
            UserDefaults.standard.set(!cookies.isEmpty, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var alwaysUseCookies: Bool {
        didSet {
            model.alwaysUseCookies = alwaysUseCookies
            UserDefaults.standard.set(alwaysUseCookies, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var accessToken: String?
    
    func getVisitorData() async {
        if model.visitorData.isEmpty {
            do {
                let response = try await HomeScreenResponse.sendThrowingRequest(
                    youtubeModel: model,
                    data: [:],
                    useCookies: true
                )
                
                if let visitorData = response.visitorData {
                    model.visitorData = visitorData
                } else {
                    print("Couldn't get visitorData, request may fail.")
                }
            } catch {
                print("Error getting visitor data:", error.localizedDescription)
            }
        }
    }
    
    init(model: YouTubeModel) {
        self.model = model
        self.cookies = UserDefaults.standard.string(forKey: "ytm_cookies") ?? ""
        self.alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        
        model.cookies = self.cookies
        model.alwaysUseCookies = self.alwaysUseCookies
    }
    
    func generateSAPISIDHASH(forCookies cookies: String, time: Int? = nil) -> String? {
        guard let SAPISID = cookies.ytkFirstGroupMatch(for: "SAPISID=([^\\s|;]*)") else {
            if cookies.contains("OAUTH_TOKEN=") {
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
        
        let currentTime = time ?? Int(Date().timeIntervalSince1970)
        let hashInput = "\(currentTime) \(SAPISID) https://www.youtube.com"
        let inputData = Data(hashInput.utf8)
        let hashed = Insecure.SHA1.hash(data: inputData)
        let hashString = hashed.map { String(format: "%02hhx", $0) }.joined()
        
        return "SAPISIDHASH \(currentTime)_\(hashString)"
    }
}

final class YTM {
    private init() {}
    
    private static let instance = YouTubeModel()
    private static let wrapper = YouTubeServiceWrapper(model: instance)
    
    static var shared: YouTubeServiceWrapper {
        return wrapper
    }
    
    static var cookies: String {
        get { shared.cookies }
        set { shared.cookies = newValue }
    }
    
    static var alwaysUseCookies: Bool {
        get { shared.alwaysUseCookies }
        set { shared.alwaysUseCookies = newValue }
    }
    
    static var accessToken: String? {
        get { shared.accessToken }
        set { shared.accessToken = newValue }
    }
    
    static func setup() {
        instance.selectedLocale = Bundle.main.preferredLocalizations.first ?? "en"
        
        if let savedCookies = UserDefaults.standard.string(forKey: "ytm_cookies") {
            cookies = savedCookies
            alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        } else {
            print("YTM: No saved cookies found during setup")
        }
    }
    
    static func reset() {
        print("YTM: Starting reset...")
        
        cookies = ""
        alwaysUseCookies = false
        
        // Clear all stored data
        UserDefaults.standard.removeObject(forKey: "ytm_cookies")
        UserDefaults.standard.removeObject(forKey: "ytm_always_use_cookies")
        UserDefaults.standard.removeObject(forKey: "youtube_access_token")
        UserDefaults.standard.removeObject(forKey: "youtube_user_info")
        UserDefaults.standard.synchronize()
    }
    
    static var model: YouTubeModel {
        return instance
    }
} 
