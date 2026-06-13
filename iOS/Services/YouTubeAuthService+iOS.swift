import Foundation
import WebKit
import UIKit

// Platform-specific implementation
class YouTubeiOSAuthDelegate: YouTubeAuthPlatformDelegate {
    private func clearWebData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            let youtubeRecords = records.filter { $0.displayName.contains("youtube") || $0.displayName.contains("google") }
            
            if !youtubeRecords.isEmpty {
                dataStore.removeData(ofTypes: dataTypes, for: youtubeRecords) { }
            }
        }
    }
    
    func performPlatformSpecificSignOut() {
        clearWebData()
    }
}

extension YouTubeAuthService {
    func setupPlatformSpecific() {
        platformDelegate = retainedPlatformDelegate
    }
}

private let retainedPlatformDelegate = YouTubeiOSAuthDelegate()
