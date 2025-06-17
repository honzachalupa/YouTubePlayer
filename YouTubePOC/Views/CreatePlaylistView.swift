import SwiftUI
import YouTubeKit

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playlistService = YouTubePlaylistService.shared
    @State private var name = ""
    @State private var privacy = YTPrivacy.private
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    
                    Picker("Privacy", selection: $privacy) {
                        Text("Private").tag(YTPrivacy.private)
                        Text("Public").tag(YTPrivacy.public)
                    }
                }
            }
            .navigationTitle("Create playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await playlistService.createPlaylist(name: name, privacy: privacy) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreatePlaylistView()
        .environmentObject(YouTubeServiceWrapper(model: YTM.model))
} 
