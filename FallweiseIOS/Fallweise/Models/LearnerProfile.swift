import Foundation

enum LearningGoal: String, Codable, CaseIterable, Identifiable {
    case dailyLife, travel, work, exam, conversation
    var id: String { rawValue }
    var title: String {
        switch self { case .dailyLife: "Daily life"; case .travel: "Travel"; case .work: "Work"; case .exam: "Exam"; case .conversation: "Conversation" }
    }
    var icon: String {
        switch self { case .dailyLife: "house"; case .travel: "tram"; case .work: "briefcase"; case .exam: "checkmark.seal"; case .conversation: "bubble.left.and.bubble.right" }
    }
    var keywords: [String] {
        switch self {
        case .dailyLife: ["home", "food", "shopping", "health", "routine"]
        case .travel: ["travel", "transport", "weather", "hotel", "direction"]
        case .work: ["work", "office", "meeting", "communication", "job"]
        case .exam: ["grammar", "reading", "writing", "numbers", "time"]
        case .conversation: ["people", "greeting", "conversation", "feelings", "opinion"]
        }
    }
}

struct LearnerPreferences: Codable, Hashable {
    var goals: Set<LearningGoal> = [.dailyLife, .conversation]
    var reminderEnabled = false
    var reminderHour = 19
    var reminderMinute = 0
}

struct RetentionSnapshot: Identifiable, Hashable {
    let days: Int
    let attempted: Int
    let correct: Int
    var id: Int { days }
    var rate: Double { attempted == 0 ? 0 : Double(correct) / Double(attempted) }
}

struct RolePlayTurn: Identifiable, Hashable {
    let id: String
    let mia: String
    let cue: String
    let accepted: [String]
    let model: String
    let correction: String
}

struct RolePlayScenario: Identifiable, Hashable {
    let id: String
    let title: String
    let setting: String
    let icon: String
    let level: CourseLevel
    let goal: LearningGoal
    let turns: [RolePlayTurn]
}

enum RolePlayLibrary {
    static let scenarios: [RolePlayScenario] = [
        RolePlayScenario(id: "cafe", title: "Order at a café", setting: "Mia is your server.", icon: "cup.and.saucer.fill", level: .A1, goal: .dailyLife, turns: [
            .init(id: "greet", mia: "Guten Tag! Was möchten Sie?", cue: "Order a coffee politely.", accepted: ["ich möchte einen kaffee bitte", "einen kaffee bitte"], model: "Ich möchte einen Kaffee, bitte.", correction: "Use möchte for a polite request."),
            .init(id: "size", mia: "Klein oder groß?", cue: "Choose a small coffee.", accepted: ["klein bitte", "einen kleinen kaffee bitte"], model: "Klein, bitte.", correction: "Answer with klein, bitte."),
            .init(id: "close", mia: "Das macht drei Euro.", cue: "Thank the server.", accepted: ["danke", "vielen dank", "danke schön"], model: "Danke schön!", correction: "Close the exchange with Danke.")
        ]),
        RolePlayScenario(id: "station", title: "At the station", setting: "Mia works at the ticket desk.", icon: "tram.fill", level: .A1, goal: .travel, turns: [
            .init(id: "ticket", mia: "Guten Tag. Wohin möchten Sie fahren?", cue: "Say that you want to travel to Berlin.", accepted: ["ich möchte nach berlin fahren", "nach berlin bitte"], model: "Ich möchte nach Berlin fahren.", correction: "Use nach before a city."),
            .init(id: "time", mia: "Heute oder morgen?", cue: "Choose tomorrow.", accepted: ["morgen", "morgen bitte"], model: "Morgen, bitte.", correction: "Say Morgen, bitte."),
            .init(id: "ask", mia: "Der Zug fährt um zehn Uhr.", cue: "Ask which platform.", accepted: ["welches gleis", "von welchem gleis", "welches gleis bitte"], model: "Von welchem Gleis?", correction: "Ask: Von welchem Gleis?")
        ]),
        RolePlayScenario(id: "doctor", title: "At the doctor", setting: "Mia asks about your symptoms.", icon: "cross.case.fill", level: .A2, goal: .dailyLife, turns: [
            .init(id: "problem", mia: "Was fehlt Ihnen?", cue: "Say that you have a headache.", accepted: ["ich habe kopfschmerzen"], model: "Ich habe Kopfschmerzen.", correction: "Use Ich habe plus the symptom."),
            .init(id: "since", mia: "Seit wann haben Sie die Schmerzen?", cue: "Say: since yesterday.", accepted: ["seit gestern"], model: "Seit gestern.", correction: "Use seit for a continuing time period."),
            .init(id: "advice", mia: "Sie sollten sich ausruhen.", cue: "Say that you understand and thank the doctor.", accepted: ["ich verstehe danke", "danke ich verstehe"], model: "Ich verstehe, danke.", correction: "Say: Ich verstehe, danke.")
        ]),
        RolePlayScenario(id: "work", title: "Plan a meeting", setting: "Mia is a colleague.", icon: "briefcase.fill", level: .A2, goal: .work, turns: [
            .init(id: "suggest", mia: "Wann können wir uns treffen?", cue: "Suggest Monday morning.", accepted: ["am montagmorgen", "am montag am morgen", "montagmorgen"], model: "Am Montagmorgen.", correction: "Use am with a day or time period."),
            .init(id: "conflict", mia: "Da habe ich leider keine Zeit.", cue: "Suggest Tuesday instead.", accepted: ["dann am dienstag", "wie wäre es am dienstag", "am dienstag"], model: "Wie wäre es am Dienstag?", correction: "Offer an alternative with Wie wäre es …?"),
            .init(id: "confirm", mia: "Dienstag passt gut.", cue: "Confirm the meeting.", accepted: ["gut dann bis dienstag", "bis dienstag", "abgemacht"], model: "Gut, dann bis Dienstag.", correction: "Confirm with: Gut, dann bis Dienstag.")
        ]),
        RolePlayScenario(id: "opinion", title: "Discuss an opinion", setting: "Mia asks for your view.", icon: "quote.bubble.fill", level: .B1, goal: .conversation, turns: [
            .init(id: "view", mia: "Sollten Innenstädte autofrei sein?", cue: "Give your opinion.", accepted: ["meiner meinung nach", "ich denke dass", "ich finde dass"], model: "Meiner Meinung nach sollten Innenstädte autofrei sein.", correction: "Begin with Meiner Meinung nach or Ich denke, dass."),
            .init(id: "reason", mia: "Warum denken Sie das?", cue: "Give a reason using weil.", accepted: ["weil"], model: "Weil die Luft dann sauberer ist.", correction: "Use weil and put the conjugated verb at the end."),
            .init(id: "example", mia: "Haben Sie ein Beispiel?", cue: "Introduce an example.", accepted: ["ein beispiel dafür ist", "zum beispiel"], model: "Ein Beispiel dafür ist das Stadtzentrum.", correction: "Use Ein Beispiel dafür ist …")
        ])
    ]

    static func available(for level: CourseLevel, goals: Set<LearningGoal>) -> [RolePlayScenario] {
        scenarios.filter { $0.level == level && (goals.isEmpty || goals.contains($0.goal)) }
    }
}
