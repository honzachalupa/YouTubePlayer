import SwiftUI

struct MessageView: View {
    let message: String
    let tint: Color
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            
            Text(message)
                .padding(.vertical, 10)
                .frame(maxWidth: 500)
                #if os(iOS)
                .onTapGesture {
                    UIPasteboard.general.string = message
                }
                #endif
        
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .padding(5)
                    .glassEffect(.regular.interactive())
            }
        }
        .padding(.horizontal, 15)
        .glassEffect(.regular.tint(tint.opacity(0.1)))
        .padding()
    }
}

struct MessageOverlayModifier: ViewModifier {
    @StateObject private var messageService = MessageService.shared
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let message = messageService.currentMessage {
                MessageView(
                    message: message.text,
                    tint: message.type.tint,
                    onDismiss: messageService.dismissCurrentMessage
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

extension View {
    func messageOverlay() -> some View {
        modifier(MessageOverlayModifier())
    }
}

#Preview {
    ZStack(alignment: .top) {
        NavigationStack {
            List(1..<100) { i in
                Text("Item \(i)")
            }
            .navigationTitle("MessageBoxView")
        }
        
        MessageView(
            message: "Couldn't fetch data, request failed.",
            tint: .red,
            onDismiss: {}
        )
    }
}
