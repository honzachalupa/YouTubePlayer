import SwiftUI

struct PlaylistsListView: View {
    @StateObject private var playlistService = YouTubePlaylistService.shared
    @State private var showingCreatePlaylistSheet = false
    @State private var playlistToDelete: YouTubePlaylist?
    @State private var showingDeleteError = false
    @State private var deleteError: String?
    
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
                        ForEach(playlistService.playlists) { playlist in
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
            .task {
                do {
                    _ = try await playlistService.fetchPlaylists()
                } catch {
                    // Error is already handled by the service
                }
            }
            .refreshable {
                do {
                    _ = try await playlistService.fetchPlaylists()
                } catch {
                    // Error is already handled by the service
                }
            }
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
                "Are you sure you want to delete \"\(playlistToDelete?.snippet.title ?? "")\" playlist?",
                isPresented: .init(
                    get: { playlistToDelete != nil },
                    set: { if !$0 { playlistToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let playlist = playlistToDelete else { return }
                    
                    Task {
                        do {
                            _ = try await playlistService.deletePlaylist(playlist)
                            playlistToDelete = nil
                            _ = try await playlistService.fetchPlaylists()
                        } catch {
                            deleteError = error.localizedDescription
                            showingDeleteError = true
                        }
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    playlistToDelete = nil
                }
            }
            .alert("Failed to delete playlist", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) {
                    showingDeleteError = false
                    deleteError = nil
                }
            } message: {
                if let error = deleteError {
                    Text(error)
                }
            }
        }
    }
}

struct PlaylistRowView: View {
    let playlist: YouTubePlaylist
    
    var body: some View {
        HStack {
            Text(playlist.snippet.title)
            
            switch playlist.status.privacyStatus {
                case "private": Image(systemName: "lock.fill").foregroundStyle(.red)
                case "unlisted": Image(systemName: "link").foregroundStyle(.orange)
                case "public": Image(systemName: "globe").foregroundStyle(.green)
                default: EmptyView()
            }
        }
        .badge(playlist.contentDetails?.itemCount.description ?? "")
    }
}

#Preview {
    NavigationStack {
        PlaylistsListView()
    }
    .environmentObject(YouTubeServiceWrapper())
}

#Preview("Playlist Row") {
    PlaylistRowView(
        playlist: YouTubePlaylist(
            id: "test",
            snippet: .init(
                title: "My Awesome Playlist",
                description: nil,
                thumbnails: nil,
                channelId: "",
                channelTitle: ""
            ),
            status: .init(privacyStatus: "private"),
            contentDetails: .init(itemCount: 42)
        )
    )
    .padding()
    .environmentObject(YouTubeServiceWrapper())
}
