import SwiftUI

struct WeeklyPracticeCard: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Kicker(text: "Your learning rhythm")
                    Text(heading).font(.title3.bold())
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(PracticeCalendarMath.week(), id: \.self) { date in
                    practiceDay(date)
                }
            }
            HStack {
                Label("\(store.currentPracticeStreak) day rhythm", systemImage: "flame.fill")
                Spacer()
                Text("\(store.completedPracticeDaysThisWeek) OF 5 THIS WEEK")
            }.font(.caption2.bold()).foregroundStyle(FallweiseTheme.green)
            Text(todayMessage).font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(FallweiseTheme.ink.opacity(0.1)))
    }

    private func practiceDay(_ date: Date) -> some View {
        let status = store.practiceStatus(on: date)
        let today = Calendar.current.isDateInToday(date)
        return VStack(spacing: 6) {
            Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption2.bold()).foregroundStyle(.secondary)
            ZStack {
                Circle().fill(fill(for: status))
                Circle().stroke(today ? FallweiseTheme.ink : .clear, lineWidth: 2)
                if status == .complete { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
                else if status == .partial { Circle().fill(FallweiseTheme.coral).frame(width: 7, height: 7) }
                else { Text(date.formatted(.dateTime.day())).font(.caption.bold()).foregroundStyle(.secondary) }
            }.frame(width: 34, height: 34)
        }.frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: date, status: status))
    }

    private var heading: String {
        if store.completedPracticeDaysThisWeek >= 5 { return "Weekly goal reached" }
        if store.currentPracticeStreak > 1 { return "\(store.currentPracticeStreak) meaningful days in a row" }
        return "Small sessions add up"
    }

    private var todayMessage: String {
        switch store.practiceStatus(on: .now) {
        case .complete: "Today counts—you did meaningful practice."
        case .partial: "A little more recall will complete today."
        case .none: "One lesson or five reviews earns today’s tick."
        }
    }

    private func fill(for status: PracticeDayStatus) -> Color {
        status == .complete ? FallweiseTheme.green : status == .partial ? FallweiseTheme.coral.opacity(0.16) : Color.black.opacity(0.045)
    }

    private func accessibilityLabel(for date: Date, status: PracticeDayStatus) -> String {
        "\(date.formatted(date: .complete, time: .omitted)), \(status == .complete ? "practice completed" : status == .partial ? "practice started" : "no practice")"
    }
}

struct PracticeCalendarView: View {
    @Environment(LearningStore.self) private var store
    @State private var month = PracticeCalendarView.startOfMonth(.now)
    @State private var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppPageHeader(kicker: "Consistency without pressure", title: "Practice calendar", subtitle: "Ticks mark meaningful learning—not merely opening the app.")
                rhythmSummary
                monthCard
                if let selectedDate { dayDetail(selectedDate) }
                rulesCard
            }.padding(20).padding(.bottom, 24)
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .fallweiseBackground()
    }

    private var rhythmSummary: some View {
        HStack(spacing: 10) {
            metric("\(store.currentPracticeStreak)", "current rhythm", FallweiseTheme.lime)
            metric("\(store.bestPracticeStreak)", "best rhythm", FallweiseTheme.blue)
            metric("\(store.completedPracticeDaysThisWeek)/5", "this week", FallweiseTheme.coral)
        }
    }

    private var monthCard: some View {
        VStack(spacing: 15) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year())).font(.title3.bold())
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
                    .accessibilityLabel("Next month")
            }.buttonStyle(.bordered)

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2.bold()).foregroundStyle(.secondary)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    if let date { calendarDay(date) }
                    else { Color.clear.frame(height: 39) }
                }
            }
            HStack(spacing: 15) {
                legend(color: FallweiseTheme.green, text: "Meaningful")
                legend(color: FallweiseTheme.coral, text: "Some practice", dot: true)
                legend(color: .gray.opacity(0.22), text: "Rest day")
            }
        }.padding(18).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private func calendarDay(_ date: Date) -> some View {
        let status = store.practiceStatus(on: date)
        let today = Calendar.current.isDateInToday(date)
        let selected = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
        return Button { withAnimation(.snappy) { selectedDate = date } } label: {
            ZStack {
                Circle().fill(status == .complete ? FallweiseTheme.green : status == .partial ? FallweiseTheme.coral.opacity(0.13) : Color.black.opacity(0.035))
                Circle().stroke(selected ? FallweiseTheme.coral : today ? FallweiseTheme.ink : .clear, lineWidth: selected ? 3 : 2)
                if status == .complete { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
                else {
                    Text(date.formatted(.dateTime.day())).font(.subheadline.bold()).foregroundStyle(.secondary)
                    if status == .partial { Circle().fill(FallweiseTheme.coral).frame(width: 6, height: 6).offset(y: 12) }
                }
            }.frame(height: 39)
        }.buttonStyle(.plain).disabled(date > .now)
            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(status.rawValue)")
    }

    private func dayDetail(_ date: Date) -> some View {
        let day = store.practiceDay(on: date)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Kicker(text: date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    Text(detailTitle(day?.status ?? .none)).font(.title3.bold())
                }
                Spacer()
                Image(systemName: day?.status == .complete ? "checkmark.seal.fill" : day?.status == .partial ? "circle.dotted" : "moon.stars.fill")
                    .font(.title).foregroundStyle(day?.status == .complete ? FallweiseTheme.green : .secondary)
            }
            if let day {
                HStack {
                    detailStat("\(day.attempts)", "reviews")
                    detailStat("\(day.completedLessons)", "lessons")
                    detailStat("\(day.focusedMinutes)", "minutes")
                    detailStat(day.attempts == 0 ? "—" : "\(Int(day.accuracy * 100))%", "accuracy")
                }
            } else {
                Text("Rest is part of learning too. Nothing was lost on this day.").font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(18).background(FallweiseTheme.lime.opacity(0.22), in: RoundedRectangle(cornerRadius: 22))
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What earns a tick?").font(.headline)
            Label("Complete one lesson", systemImage: "book.pages.fill")
            Label("Or make five retrieval attempts", systemImage: "brain.head.profile")
            Text("An amber dot means you began. Missing a day never erases your learning.").font(.caption).foregroundStyle(.secondary)
        }.padding(18).background(FallweiseTheme.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 22))
    }

    private var monthCells: [Date?] {
        let calendar = PracticeCalendarMath.calendar
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }.map(Optional.some)
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    private func moveMonth(_ offset: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: offset, to: month) { withAnimation(.snappy) { month = next; selectedDate = nil } }
    }

    private func legend(color: Color, text: String, dot: Bool = false) -> some View {
        HStack(spacing: 5) { Circle().fill(color).frame(width: dot ? 7 : 11, height: dot ? 7 : 11); Text(text) }.font(.caption2).foregroundStyle(.secondary)
    }

    private func metric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) { Text(value).font(.title2.bold()); Text(label).font(.caption2).multilineTextAlignment(.center) }
            .frame(maxWidth: .infinity).padding(.vertical, 14).background(color.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
    }

    private func detailStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) { Text(value).font(.headline); Text(label).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }

    private func detailTitle(_ status: PracticeDayStatus) -> String {
        switch status { case .complete: "Meaningful practice"; case .partial: "You made a start"; case .none: "A gentle rest day" }
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: parts) ?? date
    }
}
