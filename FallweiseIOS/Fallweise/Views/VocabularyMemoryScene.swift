import SwiftUI

struct VocabularyMemoryScene: View {
    let word: VocabularyItem

    private var identity: GenderIdentity {
        switch word.article {
        case "der": .max
        case "die": .mia
        case "das": .bot
        default: .word
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(identity.background)
            Circle().fill(identity.accent.opacity(0.9)).frame(width: 100, height: 100).offset(x: 132, y: -42)
            WaveShape().fill(.white.opacity(0.7)).frame(height: 58).frame(maxHeight: .infinity, alignment: .bottom)

            HStack(spacing: 18) {
                guide
                    .frame(width: 72)
                VStack(spacing: 7) {
                    Text((word.article.isEmpty ? word.type : word.article).uppercased())
                        .font(.caption2.bold()).tracking(1.5)
                    Text(word.symbol ?? "💬")
                        .font(.system(size: 48))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 105)
                .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(FallweiseTheme.ink, lineWidth: 1.5))
            }
            .padding(18)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Memory illustration for \(word.display). \(identity.accessibilityText)")
    }

    private var guide: some View {
        VStack(spacing: 4) {
            ZStack {
                if identity == .bot {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(FallweiseTheme.lime)
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "face.smiling").font(.title2))
                } else if identity == .word {
                    Image(systemName: "text.bubble.fill").font(.system(size: 46)).foregroundStyle(identity.accent)
                } else {
                    Circle().fill(Color(red: 0.88, green: 0.64, blue: 0.48)).frame(width: 39, height: 39)
                    Image(systemName: identity == .mia ? "person.crop.circle.fill" : "person.fill")
                        .font(.system(size: 45)).foregroundStyle(identity.accent)
                }
            }
            Text(identity.label).font(.caption2.bold()).tracking(1)
        }
    }
}

private enum GenderIdentity: Equatable {
    case max, mia, bot, word

    var label: String { switch self { case .max: "MAX"; case .mia: "MIA"; case .bot: "BOT"; case .word: "WORT" } }
    var accessibilityText: String {
        switch self {
        case .max: "Max and blue represent masculine der."
        case .mia: "Mia and coral represent feminine die."
        case .bot: "Bot and green represent neuter das."
        case .word: "Purple represents a word without a noun gender."
        }
    }
    var background: Color {
        switch self {
        case .max: FallweiseTheme.blue
        case .mia: FallweiseTheme.coral
        case .bot: Color(red: 0.46, green: 0.71, blue: 0.55)
        case .word: Color(red: 0.57, green: 0.50, blue: 0.70)
        }
    }
    var accent: Color {
        switch self {
        case .max: Color(red: 0.91, green: 0.74, blue: 0.28)
        case .mia: Color(red: 1, green: 0.83, blue: 0.78)
        case .bot: FallweiseTheme.lime
        case .word: Color(red: 0.85, green: 0.81, blue: 0.93)
        }
    }
}

private struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.45))
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.4),
            control1: CGPoint(x: rect.width * 0.3, y: 0),
            control2: CGPoint(x: rect.width * 0.67, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
