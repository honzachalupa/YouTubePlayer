import SwiftUI

struct HomeVideosView: View {
    @AppStorage("selectedHomeTab") private var selectedHomeTab: String = "recommended"
    
    var body: some View {
        NavigationStack {
            Group {
                switch selectedHomeTab {
                    case "trending":
                        TrendingVideosView()
                    default:
                        RecommendedVideosView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("", selection: $selectedHomeTab) {
                        Text("Recommended")
                            .tag("recommended")
                        
                        Text("Trending")
                            .tag("trending")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

#Preview {
    HomeVideosView()
}
