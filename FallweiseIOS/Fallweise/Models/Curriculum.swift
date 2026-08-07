import Foundation

enum CourseLevel: String, Codable, CaseIterable, Identifiable {
    case A1, A2, B1
    var id: String { rawValue }
    var title: String {
        switch self { case .A1: "Foundations"; case .A2: "Everyday German"; case .B1: "Independence" }
    }
}

struct VocabularyData: Codable {
    let units: [VocabularyUnit]
    let items: [VocabularyItem]
    let count: Int
}

struct VocabularyUnit: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let goal: String
    let items: [VocabularyItem]
}

struct VocabularyItem: Codable, Identifiable, Hashable {
    let id: String
    let unit: String
    let de: String
    let en: String
    let type: String
    let article: String
    let plural: String
    let example: String
    let exampleEn: String
    let unitTitle: String?

    var display: String { article.isEmpty ? de : "\(article) \(de)" }
}

struct LessonStep: Identifiable, Hashable {
    let id: String
    let kind: String
    let visual: String
    let hint: String
    let prompt: String
    let answers: [String]
    let success: String
    let retry: String
    let word: VocabularyItem?
}

struct VoiceLesson: Identifiable, Hashable {
    let id: String
    let level: CourseLevel
    let title: String
    let type: String
    let goal: String
    let unit: VocabularyUnit?
    let batch: Int?
    let wordStart: Int?
    let steps: [LessonStep]
}

enum CurriculumLoader {
    static func loadVocabulary(level: CourseLevel) throws -> VocabularyData {
        guard let url = Bundle.main.url(forResource: "\(level.rawValue.lowercased())-vocabulary", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(VocabularyData.self, from: Data(contentsOf: url))
    }

    static func lessons(from data: VocabularyData, level: CourseLevel) -> [VoiceLesson] {
        let vocabulary = vocabularyLessons(from: data, level: level)
        let cores = coreLessons(level: level)
        let base = data.units.count / cores.count
        let remainder = data.units.count % cores.count
        let distribution = cores.indices.map { base + ($0 < remainder ? 1 : 0) }
        var unitCursor = 0
        return cores.enumerated().flatMap { index, lesson in
            let unitCount = distribution[index]
            let sessions = Array(vocabulary[(unitCursor * 4)..<((unitCursor + unitCount) * 4)])
            unitCursor += unitCount
            return [lesson] + sessions
        }
    }

    static func coreLessons(level: CourseLevel) -> [VoiceLesson] {
        switch level {
        case .A1: a1CoreLessons
        case .A2: a2CoreLessons
        case .B1: b1CoreLessons
        }
    }

    static var a1CoreLessons: [VoiceLesson] {
        [
            core(.A1, "01-meet-greet", "WORDS", "Meet & greet", "Greet someone and introduce yourself.", [
                step("notice", "NOTICE", "Hallo! Ich heiße Mia.", "Hallo means hello. Ich heiße… introduces your name.", "Welcome to your A1 journey. Listen: Hallo! Ich heiße Mia. That means, hello, my name is Mia."),
                step("name", "YOUR TURN", "My name is… → Ich heiße …", "Say the German phrase with your name.", "Now introduce yourself. Say: Ich heiße, followed by your name.", ["ich heiße", "ich heisse"], "Sehr gut. You introduced yourself in German.", "Begin with Ich heiße, then say your name."),
                step("exchange", "REAL EXCHANGE", "Wie heißt du?", "Answer with: Ich heiße …", "I will ask your name. Wie heißt du?", ["ich heiße", "ich heisse"], "Freut mich! Nice to meet you.", "Answer: Ich heiße, and then your name.")
            ]),
            core(.A1, "02-who-does-what", "GRAMMAR", "Who does what?", "Build a sentence with a doer and an object.", [
                step("notice", "NOTICE", "Der Mann sieht den Hund.", "der Mann does it · den Hund receives it", "German cases show each word’s job. Der Mann sees. Den Hund is seen. Listen: Der Mann sieht den Hund."),
                step("object", "YOUR TURN", "the dog → der Hund / den Hund", "After sieht, masculine der becomes den.", "Complete this sentence: Der Mann sieht, the dog.", ["den hund"], "Exactly. Der Mann sieht den Hund.", "The dog is the object, so say: den Hund."),
                step("transfer", "TRANSFER", "The woman sees the man.", "Die Frau sieht den Mann.", "Now say: The woman sees the man.", ["die frau sieht den mann"], "Perfect. You marked the doer and object clearly.", "Say: Die Frau sieht den Mann.")
            ]),
            core(.A1, "03-talk-now", "SPEAKING", "Talk about now", "Use present-tense verbs in useful sentences.", [
                step("notice", "NOTICE", "ich lerne · du lernst", "The verb ending changes with the person.", "To talk about now, say: Ich lerne Deutsch. With du, the ending changes: Du lernst Deutsch."),
                step("learn", "YOUR TURN", "I learn German.", "ich + lerne", "How do you say: I learn German?", ["ich lerne deutsch"], "Richtig. Ich lerne Deutsch.", "Say: Ich lerne Deutsch."),
                step("live", "TRANSFER", "I live in Berlin.", "wohnen → ich wohne", "Now say: I live in Berlin.", ["ich wohne in berlin"], "Excellent. You can talk about what is happening now.", "Say: Ich wohne in Berlin.")
            ]),
            core(.A1, "04-everyday-world", "WORDS", "Your everyday world", "Connect vocabulary from home, food, travel, health, and work.", [
                step("set", "WORD SET", "das Haus · das Brot · der Zug", "home · bread · train", "Three useful everyday words: das Haus, the house. Das Brot, the bread. Der Zug, the train."),
                step("bread", "YOUR TURN", "the bread → ?", "Remember the neuter article.", "How do you say: the bread?", ["das brot"], "Yes. Das Brot.", "Say: das Brot."),
                step("train", "USE IT", "I travel by train.", "Ich fahre mit dem Zug.", "Say the useful sentence: I travel by train.", ["ich fahre mit dem zug"], "Great. Ich fahre mit dem Zug.", "Say: Ich fahre mit dem Zug.")
            ]),
            core(.A1, "05-questions-order", "GRAMMAR", "Questions & word order", "Ask for information with the verb in the right place.", [
                step("notice", "NOTICE", "Wo wohnst du?", "Question word · verb · person", "In a W question, put the verb directly after the question word. Wo wohnst du? Where do you live?"),
                step("where", "YOUR TURN", "Where do you live?", "Wo · wohnst · du?", "Ask me: Where do you live?", ["wo wohnst du"], "Exactly. Wo wohnst du?", "Say: Wo wohnst du?"),
                step("speak", "YES OR NO", "Sprichst du Deutsch?", "Verb comes first.", "Now ask: Do you speak German?", ["sprichst du deutsch"], "Perfect question word order.", "Say: Sprichst du Deutsch?")
            ]),
            core(.A1, "06-can-want-must", "SPEAKING", "Can, want, must", "Express ability, wishes, and needs with modal verbs.", [
                step("notice", "NOTICE", "Ich kann Deutsch sprechen.", "Modal in position 2 · main verb at the end", "With a modal verb, the second verb moves to the end. Ich kann Deutsch sprechen."),
                step("can", "YOUR TURN", "I can speak German.", "Ich kann · Deutsch · sprechen.", "Say: I can speak German.", ["ich kann deutsch sprechen"], "Genau. Ich kann Deutsch sprechen.", "Say: Ich kann Deutsch sprechen."),
                step("want", "TRANSFER", "I want to learn German.", "Ich will Deutsch lernen.", "Now say: I want to learn German.", ["ich will deutsch lernen", "ich möchte deutsch lernen", "ich mochte deutsch lernen"], "Very good. Your modal verb frame is working.", "Say: Ich will Deutsch lernen.")
            ]),
            core(.A1, "07-hear-spell", "SOUNDS", "Hear it, spell it", "Recognize German umlauts, ß, and reliable sound patterns.", [
                step("umlauts", "LISTEN", "a → ä · o → ö · u → ü", "Umlauts are distinct German sounds.", "Listen to the umlauts: ä, as in Käse. Ö, as in schön. Ü, as in fünf."),
                step("five", "YOUR TURN", "fünf", "Round your lips for ü.", "Repeat the number five: fünf.", ["fünf", "funf"], "Good. Fünf.", "Round your lips and say: fünf."),
                step("street", "SOUND LINK", "Straße", "ß sounds like a sharp s.", "Repeat this word with a clear s sound: Straße.", ["straße", "strasse"], "Sehr gut. Straße.", "Say: Straße.")
            ]),
            core(.A1, "08-numbers-time", "DAILY LIFE", "Numbers, time & dates", "Tell the time and make a simple appointment.", [
                step("notice", "NOTICE", "Es ist drei Uhr.", "It is three o’clock.", "To tell the hour, say: Es ist drei Uhr."),
                step("five", "YOUR TURN", "It is five o’clock.", "Es ist fünf Uhr.", "How do you say: It is five o’clock?", ["es ist fünf uhr", "es ist funf uhr"], "Correct. Es ist fünf Uhr.", "Say: Es ist fünf Uhr."),
                step("appointment", "APPOINTMENT", "am Montag um zehn Uhr", "on Monday at ten", "Say: on Monday at ten o’clock.", ["am montag um zehn uhr"], "Excellent. You can state an appointment time.", "Say: am Montag um zehn Uhr.")
            ]),
            core(.A1, "09-real-conversations", "DIALOGUE", "Real conversations", "Handle introductions, shopping, and polite exchanges.", [
                step("order", "DIALOGUE", "Ich möchte einen Kaffee, bitte.", "I would like a coffee, please.", "At a café, a friendly request is: Ich möchte einen Kaffee, bitte."),
                step("coffee", "YOUR TURN", "A coffee, please.", "Ich möchte …", "Order a coffee politely.", ["ich möchte einen kaffee bitte", "ich mochte einen kaffee bitte"], "Gern. Ein Kaffee. That sounded natural.", "Say: Ich möchte einen Kaffee, bitte."),
                step("thanks", "CLOSE", "Danke! · Bitte!", "thank you · you’re welcome", "I hand you the coffee. What do you say?", ["danke", "danke schön", "vielen dank"], "Bitte schön! You completed a real exchange.", "Say: Danke.")
            ]),
            core(.A1, "10-no-mine-yours", "GRAMMAR", "No, mine & yours", "Use nicht, kein, and possessive words.", [
                step("notice", "NOTICE", "ein Auto → kein Auto", "Use kein to negate a noun with ein.", "To say no car, change ein to kein. Ich habe kein Auto."),
                step("car", "YOUR TURN", "I have no car.", "Ich habe kein Auto.", "Say: I have no car.", ["ich habe kein auto"], "Exactly. Ich habe kein Auto.", "Say: Ich habe kein Auto."),
                step("book", "POSSESSION", "Das ist mein Buch.", "That is my book.", "Now say: That is my book.", ["das ist mein buch"], "Perfect. You can negate and show ownership.", "Say: Das ist mein Buch.")
            ]),
            core(.A1, "11-everyday-life", "SKILLS", "Everyday life lab", "Describe work, hobbies, shopping, and routines.", [
                step("routine", "ROUTINE", "Ich arbeite am Morgen.", "I work in the morning.", "Let’s build a routine. Listen: Ich arbeite am Morgen."),
                step("work", "YOUR TURN", "I work in the morning.", "Ich arbeite am Morgen.", "Now say the sentence yourself.", ["ich arbeite am morgen"], "Good. Ich arbeite am Morgen.", "Say: Ich arbeite am Morgen."),
                step("evening", "CONNECT", "Am Abend lerne ich Deutsch.", "Time first · verb second", "Say: In the evening I learn German.", ["am abend lerne ich deutsch"], "Excellent. Your routine now has two useful parts.", "Say: Am Abend lerne ich Deutsch.")
            ]),
            core(.A1, "12-speak-replay", "SPEAKING", "Speak & replay", "Bring your A1 patterns together in one introduction.", [
                step("mission", "MISSION", "Name · home · German", "Link three short ideas.", "Your final A1 speaking mission is a short introduction: your name, where you live, and that you learn German."),
                step("build", "BUILD", "Ich heiße … Ich wohne in …", "Say both sentences with your own details.", "Tell me your name and where you live.", ["ich heiße", "ich heisse"], "Wonderful. Now add your learning goal.", "Start with Ich heiße, then say: Ich wohne in, and your city."),
                step("final", "FINAL RECALL", "Ich lerne Deutsch.", "Finish confidently.", "Complete your introduction by saying: I learn German.", ["ich lerne deutsch"], "Ausgezeichnet. You completed your A1 voice journey.", "Say: Ich lerne Deutsch.")
            ])
        ]
    }

    private static func vocabularyLessons(from data: VocabularyData, level: CourseLevel) -> [VoiceLesson] {
        data.units.enumerated().flatMap { unitIndex, unit in
            (0..<4).map { batch in
                let words = Array(unit.items[(batch * 5)..<min(batch * 5 + 5, unit.items.count)])
                let introduction = LessonStep(
                    id: "intro", kind: "INTRODUCE",
                    visual: words.map(\.display).joined(separator: " · "),
                    hint: "Five new words from \(unit.title).",
                    prompt: "Here are five useful words. " + words.map { "\($0.display), \($0.en)" }.joined(separator: ". ") + ". Listen once, then retrieve them.",
                    answers: [], success: "", retry: "", word: nil
                )
                let recall = words.enumerated().map { index, word in
                    LessonStep(
                        id: word.id, kind: "SPOKEN RECALL", visual: "\(word.en) → ?",
                        hint: word.type == "noun" ? "Say the article and noun · word \(index + 1) of 5" : "Say the German · word \(index + 1) of 5",
                        prompt: "How do you say \(word.en) in German?",
                        answers: [word.display, word.de],
                        success: "Richtig. \(word.display) means \(word.en).",
                        retry: "Listen once more: \(word.display). Now say \(word.display).",
                        word: word
                    )
                }
                let use = words[0]
                let sentence = LessonStep(
                    id: "use-\(use.id)", kind: "USE IT", visual: use.example,
                    hint: "Use \(use.display) in a complete thought.",
                    prompt: "Now use one word in context. Repeat: \(use.example)",
                    answers: [use.example], success: "Excellent. \(use.example)",
                    retry: "Say the complete sentence: \(use.example)", word: use
                )
                return VoiceLesson(
                    id: level == .A1 ? "vocab-\(unit.id)-\(batch + 1)" : "\(level.rawValue.lowercased())-vocab-\(unit.id)-\(batch + 1)", level: level, title: "\(unit.title) · \(batch + 1)/4",
                    type: "VOCAB", goal: unit.goal, unit: unit, batch: batch,
                    wordStart: unitIndex * 20 + batch * 5,
                    steps: [introduction] + recall + [sentence]
                )
            }
        }
    }

    static func core(_ level: CourseLevel, _ id: String, _ type: String, _ title: String, _ goal: String, _ steps: [LessonStep]) -> VoiceLesson {
        VoiceLesson(id: level == .A1 ? id : "\(level.rawValue.lowercased())-\(id)", level: level, title: title, type: type, goal: goal, unit: nil, batch: nil, wordStart: nil, steps: steps)
    }

    static func step(_ id: String, _ kind: String, _ visual: String, _ hint: String, _ prompt: String, _ answers: [String] = [], _ success: String = "", _ retry: String = "") -> LessonStep {
        LessonStep(id: id, kind: kind, visual: visual, hint: hint, prompt: prompt, answers: answers, success: success, retry: retry, word: nil)
    }
}
