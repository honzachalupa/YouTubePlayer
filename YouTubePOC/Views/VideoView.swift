import SwiftUI
import AVKit

struct VideoView: View {
    let video: YouTubeVideo
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Video Player
                    ZStack {
                        if let player = viewModel.player {
                            VideoPlayer(player: player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    viewModel.isLoading ? loadingOverlay : nil
                                )
                                .overlay(
                                    viewModel.showControls ? controlsOverlay : nil
                                )
                                .onTapGesture {
                                    withAnimation {
                                        viewModel.toggleControls()
                                    }
                                }
                        } else {
                            // Thumbnail
                            AsyncImage(url: URL(string: viewModel.thumbnailURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                viewModel.isLoading ? loadingOverlay : nil
                            )
                        }
                    }
                    .frame(height: viewModel.isFullScreen ? geometry.size.height : geometry.size.width * 9/16)
                    
                    if !viewModel.isFullScreen && viewModel.showVideoInfo {
                        // Video Info
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(viewModel.videoTitle)
                                    .font(.headline)
                                    .lineLimit(2)
                                
                                HStack {
                                    Text(viewModel.channelTitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 16) {
                                        Label(viewModel.viewCount, systemImage: "eye")
                                        Label(viewModel.likeCount, systemImage: "hand.thumbsup")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .statusBar(hidden: viewModel.isFullScreen)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error ?? "Unknown error")
        }
        .task {
            await viewModel.loadVideo(video)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        }
    }
    
    private var controlsOverlay: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack {
                // Top bar
                HStack {
                    Button {
                        if viewModel.isFullScreen {
                            viewModel.toggleFullScreen()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .imageScale(.large)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.toggleFullScreen()
                    } label: {
                        Image(systemName: viewModel.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .imageScale(.large)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                // Play/Pause button
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .imageScale(.large)
                        .foregroundColor(.white)
                        .padding(20)
                        .background(.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            VideoView(video: YouTubeVideo(
                id: "dQw4w9WgXcQ",
                snippet: .init(
                    publishedAt: "2009-10-25T06:57:33Z",
                    channelId: "UC-9-kyTW8ZkZNDHQJ6F4Y5A",
                    title: "Rick Astley - Never Gonna Give You Up (Official Music Video)",
                    description: "The official music video for \"Never Gonna Give You Up\" by Rick Astley",
                    thumbnails: .init(
                        default: .init(
                            url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg",
                            width: 120,
                            height: 90
                        ),
                        medium: .init(
                            url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg",
                            width: 320,
                            height: 180
                        ),
                        high: .init(
                            url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
                            width: 480,
                            height: 360
                        ),
                        standard: .init(
                            url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/sddefault.jpg",
                            width: 640,
                            height: 480
                        ),
                        maxres: .init(
                            url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
                            width: 1280,
                            height: 720
                        )
                    ),
                    channelTitle: "Rick Astley",
                    tags: ["Rick Astley", "Never Gonna Give You Up", "Music Video"],
                    categoryId: "10",
                    liveBroadcastContent: "none"
                ),
                contentDetails: .init(
                    duration: "PT3M33S",
                    dimension: "2d",
                    definition: "hd",
                    caption: "true",
                    licensedContent: true,
                    projection: "rectangular"
                ),
                statistics: .init(
                    viewCount: "1400000000",
                    likeCount: "15000000",
                    favoriteCount: "0",
                    commentCount: "1200000"
                )
            ))
        }
}
