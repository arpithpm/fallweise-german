enum WatchSessionSyncPolicy {
    /// Progress acknowledgements from the phone must not replace an active
    /// Watch session. A replacement is only needed for initial content or an
    /// intentional level change.
    static func shouldReplaceSession(currentLevel: String, incomingLevel: String?, hasActiveWords: Bool) -> Bool {
        guard hasActiveWords else { return true }
        guard let incomingLevel else { return false }
        return incomingLevel != currentLevel
    }
}
