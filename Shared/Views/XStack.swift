import SwiftUI

struct XStack<Content: View>: View {
    public let isVertical: Bool
    @ViewBuilder public let content: () -> Content
    
    var body: some View {
        if isVertical {
            VStack {
                content()
            }
        } else {
            HStack {
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
