import SwiftUI
import YouTubeKit

struct PlaylistsListView: View {
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
                    
                    Text(playlist.videoCount ?? "")
                        .opacity(0.5)
                }
            }
            .task { await fetchPlaylists() }
            .refreshable { await fetchPlaylists() }
            .navigationTitle("Playlists")
        }
    }
}

#Preview {
    PlaylistsListView()
}
