import SwiftUI
import RadialCore

/// The core supplies both endpoints; the view does not calculate item geometry.
struct MenuDirectionGuide: View {
    let guide: DirectionGuide
    let diameter: Double
    let selectedID: String?

    var body: some View {
        ZStack {
            Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
                .frame(width: guide.radius * 2, height: guide.radius * 2)
            ForEach(guide.connections, id: \.itemID) { connection in
                let selected = connection.itemID == selectedID
                let color = selected ? Color.accentColor : Color(nsColor: .windowBackgroundColor)
                Path { path in
                    path.move(to: CGPoint(x: diameter / 2 + connection.marker.x, y: diameter / 2 + connection.marker.y))
                    path.addLine(to: CGPoint(x: diameter / 2 + connection.labelEdge.x, y: diameter / 2 + connection.labelEdge.y))
                }
                .stroke(color, lineWidth: selected ? 3 : 1.5)
                Circle().fill(color)
                    .frame(width: guide.markerRadius * 2, height: guide.markerRadius * 2)
                    .position(x: diameter / 2 + connection.marker.x, y: diameter / 2 + connection.marker.y)
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.3), radius: 1)
    }
}
