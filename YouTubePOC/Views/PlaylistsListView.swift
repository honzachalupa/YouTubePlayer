import SwiftUI
import YouTubeKit

struct PlaylistsListView: View {
    @StateObject private var playlistService = YouTubePlaylistService.shared
    @State private var showingCreatePlaylistSheet = false
    @State private var playlistToDelete: YTPlaylist?
    @State private var showingDeleteError = false
    
    var body: some View {
        NavigationStack {
            Group {
                if playlistService.isLoading && playlistService.playlists.isEmpty {
                    ProgressView()
                        .controlSize(.large)
                } else if let error = playlistService.error {
                    ContentUnavailableView(error, systemImage: "exclamationmark.triangle.fill")
                } else if playlistService.playlists.isEmpty {
                    ContentUnavailableView("No playlists found", systemImage: "play.square.stack")
                } else {
                    List {
                        ForEach(playlistService.playlists, id: \.playlistId) { playlist in
                            NavigationLink {
                                PlaylistView(playlist: playlist)
                            } label: {
                                PlaylistRowView(playlist: playlist)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    playlistToDelete = playlist
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    playlistToDelete = playlist
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                }
            }
            .task { await playlistService.fetchPlaylists() }
            .refreshable { await playlistService.fetchPlaylists() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreatePlaylistSheet = true
                    } label: {
                        Label("Create playlist", systemImage: "plus")
                    }
                }
                
                AccountToolbarItem()
            }
            .sheet(isPresented: $showingCreatePlaylistSheet) {
                CreatePlaylistView()
            }
            .confirmationDialog(
                "Are you sure you want to delete \"\(playlistToDelete?.title ?? "")\" playlist?",
                isPresented: .init(
                    get: { playlistToDelete != nil },
                    set: { if !$0 { playlistToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let playlist = playlistToDelete {
                        Task {
                            let success = await playlistService.deletePlaylist(playlist)
                            if success {
                                playlistToDelete = nil
                            } else {
                                showingDeleteError = true
                            }
                        }
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    playlistToDelete = nil
                }
            }
            .alert("Failed to delete playlist \"\(playlistToDelete?.title ?? "")\".", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) {
                    showingDeleteError = false
                }
            } message: {
                if let error = playlistService.error {
                    Text(error)
                }
            }
        }
    }
}

struct PlaylistRowView: View {
    let playlist: YTPlaylist
    
    var body: some View {
        HStack {
            Text(playlist.title ?? "")
            
            switch playlist.privacy {
                case .private: Image(systemName: "lock.fill").foregroundStyle(.red)
                case .unlisted: Image(systemName: "link").foregroundStyle(.orange)
                case .public: Image(systemName: "globe").foregroundStyle(.green)
                case .none: EmptyView()
            }
        }
        .badge(playlist.videoCount ?? "")
    }
}

#Preview("Playlists List") {
    NavigationStack {
        PlaylistsListView()
    }
    .environmentObject(YouTubeServiceWrapper(model: YTM.model))
}

#Preview("Playlist Row") {
    PlaylistRowView(
        playlist: YTPlaylist(
            playlistId: "test",
            title: "My Awesome Playlist",
            videoCount: "42 videos",
            privacy: .private
        )
    )
    .padding()
    .environmentObject(YouTubeServiceWrapper(model: YTM.model))
}
