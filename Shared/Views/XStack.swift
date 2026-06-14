import SwiftUI

struct XStack<Content: View>: View {
    public let isVertical: Bool
    @ViewBuilder public let content: () -> Content
    
    var body: some View {
        if isVertical {
            VStack(spacing: 0) {
                content()
            }
        } else {
            HStack(spacing: 0) {
                content()
            }
        }
    }
}

#Preview {
    XStack(isVertical: true) {
        Text("Using VStack")
    }
    
    XStack(isVertical: false) {
        Text("Using HStack")
    }
}
