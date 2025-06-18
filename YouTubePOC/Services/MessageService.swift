import SwiftUI

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: MessageType
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageType {
    case error
    case success
    case warning
    case info
    
    var tint: Color {
        switch self {
        case .error: .red
        case .success: .green
        case .warning: .orange
        case .info: .blue
        }
    }
}

@MainActor
class MessageService: ObservableObject {
    static let shared = MessageService()
    private init() {}
    
    @Published private(set) var currentMessage: Message? = nil
    private var messageQueue: [Message] = []
    private var isShowingMessage = false
    
    func show(message: String, type: MessageType) {
        let newMessage = Message(text: message, type: type)
        
        if type == .error {
            print(message)
        }
        
        if isShowingMessage {
            messageQueue.append(newMessage)
        } else {
            displayMessage(newMessage)
        }
    }
    
    func dismissCurrentMessage() {
        withAnimation {
            currentMessage = nil
            isShowingMessage = false
        }
        
        // Show next message if any
        if let nextMessage = messageQueue.first {
            messageQueue.removeFirst()
            displayMessage(nextMessage)
        }
    }
    
    private func displayMessage(_ message: Message) {
        withAnimation {
            currentMessage = message
            isShowingMessage = true
        }
        
        // Auto-dismiss after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            if currentMessage?.id == message.id {
                dismissCurrentMessage()
            }
        }
    }
} 
