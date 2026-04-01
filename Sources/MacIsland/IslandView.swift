import SwiftUI

struct IslandView: View {
    @State private var expanded = false

    var body: some View {
        RoundedRectangle(cornerRadius: expanded ? 26 : 20)
            .fill(Color.black)
            .frame(
                width: expanded ? 360 : 120,
                height: expanded ? 80 : 34
            )
            .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: expanded)
            .onHover { hovering in
                expanded = hovering
            }
    }
}
