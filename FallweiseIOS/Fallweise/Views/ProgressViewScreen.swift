import SwiftUI

struct ProgressViewScreen: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppPageHeader(kicker: "Your learning", title: "Progress that helps", subtitle: "See what is becoming familiar and choose your next useful step.")
                    summary
                    NavigationLink { PracticeCalendarView() } label: { WeeklyPracticeCard() }
                        .buttonStyle(.plain)
                    retentionCard
                    weeklyGoalCard
                    preferencesCard
                    retentionHistoryCard
                    canDoCard
                    weakMemoryCard
                    ForEach(CourseLevel.allCases) { level in levelCard(level) }
                    syncCard
                }.padding(20).padding(.bottom, 16)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .fallweiseBackground()
        }
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Make German relevant").font(.headline)
            Text("Goals influence new examples and the role-play scenes Mia offers.").font(.caption).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(LearningGoal.allCases) { goal in
                    Button { store.toggleGoal(goal) } label: { Label(goal.title, systemImage: goal.icon) }
                        .buttonStyle(.bordered).tint(store.preferences.goals.contains(goal) ? FallweiseTheme.green : .gray)
                }
            }
            Divider()
            Toggle("Gentle daily review reminder", isOn: Binding(get: { store.preferences.reminderEnabled }, set: { value in Task { await store.configureReminder(enabled: value) } }))
            if store.preferences.reminderEnabled {
                DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute).datePickerStyle(.compact)
            }
            Text("Reminders are scheduled privately on this iPhone. Missing one never breaks a streak.").font(.caption2).foregroundStyle(.secondary)
        }.padding(18).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 22))
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: store.preferences.reminderHour, minute: store.preferences.reminderMinute)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            Task { await store.configureReminder(enabled: true, hour: parts.hour, minute: parts.minute) }
        }
    }

    private var retentionHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Delayed recall").font(.headline); Spacer(); Text("1 · 7 · 30 DAYS").font(.caption2.bold()).foregroundStyle(FallweiseTheme.green) }
            Text("This measures what was still retrievable after time passed—not what was completed once.").font(.caption).foregroundStyle(.secondary)
            ForEach(store.retentionSnapshots) { snapshot in
                HStack {
                    Text("After \(snapshot.days) day\(snapshot.days == 1 ? "" : "s")").font(.subheadline.bold()).frame(width: 100, alignment: .leading)
                    ProgressView(value: snapshot.rate).tint(FallweiseTheme.green)
                    Text(snapshot.attempted == 0 ? "Collecting" : "\(Int(snapshot.rate * 100))%").font(.caption.bold()).frame(width: 60, alignment: .trailing)
                }
            }
            Text("Scheduler calibration: \(Int(store.calibratedIntervalFactor * 100))%").font(.caption2).foregroundStyle(.secondary)
        }.padding(18).background(FallweiseTheme.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 22))
    }

    private var summary: some View {
        HStack(spacing: 10) {
            metric("\(store.strongMemoryCount)", "strong", FallweiseTheme.coral)
            metric("\(store.dueReviewCount)", "due", FallweiseTheme.blue)
            metric("\(Int(store.averageRetention * 100))%", "retention", FallweiseTheme.lime)
        }
    }

    private var retentionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Memory health").font(.title3.bold()); Spacer(); Image(systemName: "brain.head.profile").foregroundStyle(FallweiseTheme.green) }
            Text("Completion tells us where you have been. Retention estimates what you can still retrieve now.").font(.caption).foregroundStyle(.secondary)
            statLine("Estimated retention", Int(store.averageRetention * 100), 100)
            HStack { Label("\(store.fragileCount) fragile", systemImage: "leaf"); Spacer(); Label("\(store.strongMemoryCount) durable", systemImage: "shield.checkered") }.font(.caption.bold())
            Button("Practice what is due") { store.beginAdaptiveSession() }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
        }.padding(18).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 22))
    }

    private var weeklyGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Flexible weekly goal").font(.headline); Spacer(); Text("\(store.practicedMinutesThisWeek)/\(store.weeklyGoalMinutes) MIN").font(.caption.bold()).foregroundStyle(FallweiseTheme.green) }
            ProgressView(value: Double(store.practicedMinutesThisWeek), total: Double(store.weeklyGoalMinutes)).tint(FallweiseTheme.coral)
            Text("Missing a day never erases progress. Choose a weekly pace that fits your life.").font(.caption).foregroundStyle(.secondary)
            Picker("Weekly minutes", selection: Binding(get: { store.weeklyGoalMinutes }, set: { store.setWeeklyGoal($0) })) {
                ForEach([20, 35, 60, 90], id: \.self) { Text("\($0) min").tag($0) }
            }.pickerStyle(.segmented)
        }.padding(18).background(FallweiseTheme.blue.opacity(0.22), in: RoundedRectangle(cornerRadius: 22))
    }

    private var canDoCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Kicker(text: "CEFR can-do growth")
            Text("What your German can do").font(.title3.bold())
            canDo("Handle a simple introduction", chapter: 1)
            canDo("Ask and answer everyday questions", chapter: 5)
            canDo("Express needs and plans", chapter: 6)
            canDo("Complete a short real-world exchange", chapter: 9)
        }.padding(18).background(FallweiseTheme.lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 22))
    }

    private func canDo(_ text: String, chapter: Int) -> some View {
        let achieved = store.completedCoreCount >= chapter
        return Label(text, systemImage: achieved ? "checkmark.circle.fill" : "circle.dashed")
            .font(.subheadline).foregroundStyle(achieved ? FallweiseTheme.green : .secondary)
    }

    private var weakMemoryCard: some View {
        let weak = store.weakSkills(limit: 4)
        return Group {
            if !weak.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Worth strengthening next").font(.headline)
                    ForEach(weak) { memory in
                        HStack { Text(memory.kind.title).font(.caption.bold()); Text(memory.skillID.components(separatedBy: ":").suffix(2).joined(separator: " · ")).font(.caption).lineLimit(1); Spacer(); Text("\(Int(memory.mastery * 100))%").font(.caption.bold()).foregroundStyle(FallweiseTheme.coral) }
                    }
                }.padding(18).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 22))
            }
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
