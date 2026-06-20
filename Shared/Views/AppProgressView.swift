import SwiftUI

struct AppProgressView: View {
    enum Style {
        case centered
        case inline
        case overlay
    }

    let style: Style

    init(_ style: Style = .centered) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .centered:
            VStack {
                Spacer()
                progress
                    .controlSize(.large)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .inline:
            progress
                .controlSize(.regular)

        case .overlay:
            progress
                .controlSize(.large)
        }
    }

    private var progress: some View {
        ProgressView()
            .tint(.accentColor)
    }
}
