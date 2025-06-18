import SwiftUI

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playlistService = YouTubePlaylistService.shared
    @State private var name = ""
    @State private var privacy = "private"
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    
                    Picker("Privacy", selection: $privacy) {
                        Text("Private").tag("private")
                        Text("Public").tag("public")
                    }
                }
            }
            .navigationTitle("Create playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        isCreating = true
                        Task {
                            defer { isCreating = false }
                            do {
                                if try await playlistService.createPlaylist(name: name, privacy: privacy) {
                                    await MainActor.run {
                                        dismiss()
                                    }
                                }
                            } catch {
                                print("Failed to create playlist:", error)
                            }
                        }
                    }
                    .disabled(name.isEmpty || isCreating || playlistService.isLoading)
                }
            }
            .overlay {
                if playlistService.isLoading || isCreating {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreatePlaylistView()
    }
    .environmentObject(YouTubeServiceWrapper())
} 
