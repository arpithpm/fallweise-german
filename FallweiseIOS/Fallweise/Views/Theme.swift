import SwiftUI

enum FallweiseTheme {
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.11)
    static let cream = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let paper = Color(red: 1, green: 0.99, blue: 0.96)
    static let green = Color(red: 0.15, green: 0.31, blue: 0.24)
    static let lime = Color(red: 0.85, green: 0.93, blue: 0.45)
    static let coral = Color(red: 0.95, green: 0.53, blue: 0.44)
    static let blue = Color(red: 0.55, green: 0.78, blue: 0.85)
}

struct Kicker: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.caption2.bold()).tracking(1.6).foregroundStyle(FallweiseTheme.green) }
}
