import SwiftUI
import YouTubeKit

class VideoStateManager: ObservableObject {
    @Published var selectedVideo: YTVideo?
    @Published var isVideoSheetPresented: Bool = false
    
    var selectedVideoBinding: Binding<YTVideo?> {
        Binding(
            get: { self.selectedVideo },
            set: { self.selectedVideo = $0 }
        )
    }
    
    func selectVideo(_ video: YTVideo) {
        selectedVideo = video
        isVideoSheetPresented = true
    }
    
    func dismissVideo() {
        isVideoSheetPresented = false
    }
}
