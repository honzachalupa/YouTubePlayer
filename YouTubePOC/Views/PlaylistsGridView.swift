import SwiftUI
import YouTubeKit

struct PlaylistsGridView: View {
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    @State private var playlists: [YTPlaylist] = []
    
    func fetchPlaylists() async {
        do {
            await youtubeService.getVisitorData()
            
            let response = try await AccountPlaylistsResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [:]
            )
            
            withAnimation {
                playlists = response.results
                
                response.results.forEach { playlist in
                    print("playlists", playlist.title ?? "-", playlist.videoCount ?? "-", playlist.frontVideos.count)
                }
            }
        } catch {
            print(error.localizedDescription)
            
            withAnimation {
                playlists = []
            }
        }
    }
    var body: some View {
        NavigationStack {
            List(playlists, id: \.playlistId) { playlist in
                NavigationLink {
                    PlaylistView(playlist: playlist)
                } label: {
                    Text(playlist.title ?? "")
                    
                    Spacer()
                    
                    Text(playlist.videoCount ?? "")
                        .opacity(0.3)
                }
            }
            .task { await fetchPlaylists() }
            .navigationTitle("Playlists")
        }
    }
}

#Preview {
    PlaylistsGridView()
}
