import SwiftUI

struct ProgressViewScreen: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppPageHeader(kicker: "Your learning", title: "Progress that helps", subtitle: "See what is becoming familiar and choose your next useful step.")
                    summary
                    ForEach(CourseLevel.allCases) { level in levelCard(level) }
                    syncCard
                }.padding(20).padding(.bottom, 16)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .fallweiseBackground()
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            metric("\(store.totalCompletedCount)", "sessions", FallweiseTheme.coral)
            metric("\(store.totalLearnedCount)", "words", FallweiseTheme.blue)
            metric("3", "levels", FallweiseTheme.lime)
        }
    }

    private func metric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) { Text(value).font(.title.bold()); Text(label.uppercased()).font(.caption2.bold()) }
            .frame(maxWidth: .infinity).padding(.vertical, 18).background(color.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }

    private func levelCard(_ level: CourseLevel) -> some View {
        let vocab = store.vocabularies[level]!
        let learned = store.learnedCount(for: level)
        let chapters = store.completedCoreCount(for: level)
        return Button {
            store.selectLevel(level); store.selectedTab = .learn
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    ZStack { Circle().fill(level == .A1 ? FallweiseTheme.lime : level == .A2 ? FallweiseTheme.blue : FallweiseTheme.coral); Text(level.rawValue).font(.headline) }.frame(width: 48, height: 48)
                    VStack(alignment: .leading) { Text(level.title).font(.headline); Text("\(store.completedSessionCount(for: level)) sessions completed").font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Image(systemName: "chevron.right")
                }
                statLine("Course chapters", chapters, 12)
                statLine("Vocabulary", learned, vocab.count)
            }.padding(18).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain)
    }

    private func statLine(_ title: String, _ value: Int, _ total: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title).font(.caption.bold()); Spacer(); Text("\(value)/\(total)").font(.caption).foregroundStyle(.secondary) }
            ProgressView(value: Double(value), total: Double(total)).tint(FallweiseTheme.green)
        }
    }

    private var syncCard: some View {
        HStack(spacing: 13) {
            Image(systemName: "icloud.fill").font(.title2).foregroundStyle(FallweiseTheme.green)
            VStack(alignment: .leading, spacing: 3) { Text("Progress protection").font(.headline); Text(store.errorMessage ?? "Saved on this iPhone and synced securely.").font(.caption).foregroundStyle(.secondary) }
        }.padding(17).background(FallweiseTheme.lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
    }
}
