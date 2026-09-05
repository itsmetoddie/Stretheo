//
//  WatchConnectivityManager.swift
//  Stretheo (iOS + watchOS — include in both app targets)
//

import Foundation
import OSLog
import SwiftData
@preconcurrency import WatchConnectivity

enum WatchConnectivityPayloadKey: String {
    case stressLevel
    case category
    case measuredAt
    case trigger
    case hrv
    case heartRate
    case notificationsEnabled
    case stressAlertThreshold
    case quietHoursStart
    case quietHoursEnd
    case watchNotificationSent
}

private struct WatchIncomingPayload: Sendable {
    let level: Int
    let measuredAt: TimeInterval
    let category: String?
    let hrv: Double?
    let heartRate: Double?
    let watchNotificationSent: Bool

    nonisolated init?(_ data: [String: Any]) {
        guard let level = data[WatchConnectivityPayloadKey.stressLevel.rawValue] as? Int,
              let measuredAt = data[WatchConnectivityPayloadKey.measuredAt.rawValue] as? Double
        else { return nil }
        self.level = level
        self.measuredAt = measuredAt
        category = data[WatchConnectivityPayloadKey.category.rawValue] as? String
        hrv = data[WatchConnectivityPayloadKey.hrv.rawValue] as? Double
        heartRate = data[WatchConnectivityPayloadKey.heartRate.rawValue] as? Double
        watchNotificationSent = data[WatchConnectivityPayloadKey.watchNotificationSent.rawValue] as? Bool ?? false
    }

    var dictionary: [String: Any] {
        var payload = dictionaryBase
        if watchNotificationSent {
            payload[WatchConnectivityPayloadKey.watchNotificationSent.rawValue] = true
        }
        return payload
    }

    private var dictionaryBase: [String: Any] {
        let optionalEntries = Dictionary(
            uniqueKeysWithValues: [
                category.map { (WatchConnectivityPayloadKey.category.rawValue, $0 as Any) },
                hrv.map { (WatchConnectivityPayloadKey.hrv.rawValue, $0 as Any) },
                heartRate.map { (WatchConnectivityPayloadKey.heartRate.rawValue, $0 as Any) }
            ].compactMap { $0 }
        )
        return [
            WatchConnectivityPayloadKey.stressLevel.rawValue: level,
            WatchConnectivityPayloadKey.measuredAt.rawValue: measuredAt
        ].merging(optionalEntries) { _, new in new }
    }
}

private struct WatchMoodIncomingPayload: Sendable {
    let score: Int
    let word: String?
    let timestamp: TimeInterval

    nonisolated init?(_ data: [String: Any]) {
        guard (data["type"] as? String) == "moodEntry" else { return nil }
        let score = (data["score"] as? Int) ?? (data["score"] as? NSNumber)?.intValue
        let timestamp = (data["date"] as? TimeInterval) ?? (data["date"] as? NSNumber)?.doubleValue
        guard let score, let timestamp else { return nil }
        self.score = score
        self.timestamp = timestamp
        let word = data["word"] as? String
        self.word = word?.isEmpty == true ? nil : word
    }
}

@MainActor
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    #if os(watchOS)
    var displayContextHandler: (([String: Any]) -> Void)?
    #endif

    private var didRequestActivation = false

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        guard !didRequestActivation else { return }
        didRequestActivation = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
        StretheoLog.watchConnectivity.info("Session activate requested")
    }

    #if os(watchOS)
    func sendStressResult(
        _ result: StressResult,
        measuredAt: Date,
        input: HealthInput,
        watchNotificationSent: Bool = false
    ) {
        let optionalMetrics = Dictionary(
            uniqueKeysWithValues: [
                input.hrv.map { (WatchConnectivityPayloadKey.hrv.rawValue, $0 as Any) },
                input.currentHeartRate.map { (WatchConnectivityPayloadKey.heartRate.rawValue, $0 as Any) }
            ].compactMap { $0 }
        )
        var payload: [String: Any] = [
            WatchConnectivityPayloadKey.stressLevel.rawValue: result.level,
            WatchConnectivityPayloadKey.category.rawValue: result.category.rawValue,
            WatchConnectivityPayloadKey.measuredAt.rawValue: measuredAt.timeIntervalSince1970
        ].merging(optionalMetrics) { _, new in new }
        if watchNotificationSent {
            payload[WatchConnectivityPayloadKey.watchNotificationSent.rawValue] = true
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            session.transferUserInfo(payload)
            StretheoLog.watchConnectivity.debug("Queued result — session not activated")
            return
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                StretheoLog.watchConnectivity.error("sendMessage failed: \(error.localizedDescription)")
                session.transferUserInfo(payload)
            }
            StretheoLog.watchConnectivity.info("Sent stress result via sendMessage")
        } else {
            session.transferUserInfo(payload)
            StretheoLog.watchConnectivity.info("Queued stress result via transferUserInfo")
        }
    }

    func sendMoodEntry(score: Int, word: String, date: Date) {
        let payload: [String: Any] = [
            "type": "moodEntry",
            "score": score,
            "word": word,
            "date": date.timeIntervalSince1970
        ]

        let session = WCSession.default
        guard session.activationState == .activated else {
            session.transferUserInfo(payload)
            StretheoLog.watchConnectivity.debug("Queued mood entry — session not activated")
            return
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                StretheoLog.watchConnectivity.error("Mood sendMessage failed: \(error.localizedDescription)")
                session.transferUserInfo(payload)
            }
            StretheoLog.watchConnectivity.info("Sent mood entry via sendMessage")
        } else {
            session.transferUserInfo(payload)
            StretheoLog.watchConnectivity.info("Queued mood entry via transferUserInfo")
        }
    }
    #endif

    #if os(iOS)
    func pushLatestStress(level: Int, category: StressCategory, measuredAt: Date, profile: HealthInput) {
        guard WCSession.default.activationState == .activated else { return }
        let payload: [String: Any] = [
            WatchConnectivityPayloadKey.stressLevel.rawValue: level,
            WatchConnectivityPayloadKey.category.rawValue: category.rawValue,
            WatchConnectivityPayloadKey.measuredAt.rawValue: measuredAt.timeIntervalSince1970,
            "birthMonth": profile.birthMonth,
            "birthYear": profile.birthYear,
            "sex": profile.sex.rawValue,
            WatchConnectivityPayloadKey.notificationsEnabled.rawValue: AppSettings.notificationsEnabled,
            WatchConnectivityPayloadKey.stressAlertThreshold.rawValue: AppSettings.stressAlertThreshold,
            WatchConnectivityPayloadKey.quietHoursStart.rawValue: AppSettings.quietHoursStart.timeIntervalSince1970,
            WatchConnectivityPayloadKey.quietHoursEnd.rawValue: AppSettings.quietHoursEnd.timeIntervalSince1970
        ]
        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            StretheoLog.watchConnectivity.error("updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    /// Signals the paired Watch to purge locally cached profile demographics and stress display data.
    func pushDataWipeToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        do {
            try WCSession.default.updateApplicationContext(["dataWipe": Date().timeIntervalSince1970])
        } catch {
            StretheoLog.watchConnectivity.error("dataWipe updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    /// Merges notification settings into the current application context for the paired Watch.
    func pushNotificationSettingsToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        var context = WCSession.default.applicationContext
        context[WatchConnectivityPayloadKey.notificationsEnabled.rawValue] = AppSettings.notificationsEnabled
        context[WatchConnectivityPayloadKey.stressAlertThreshold.rawValue] = AppSettings.stressAlertThreshold
        context[WatchConnectivityPayloadKey.quietHoursStart.rawValue] = AppSettings.quietHoursStart.timeIntervalSince1970
        context[WatchConnectivityPayloadKey.quietHoursEnd.rawValue] = AppSettings.quietHoursEnd.timeIntervalSince1970
        do {
            try WCSession.default.updateApplicationContext(context)
            StretheoLog.watchConnectivity.info("Pushed notification settings to Watch")
        } catch {
            StretheoLog.watchConnectivity.error("pushNotificationSettingsToWatch failed: \(error.localizedDescription)")
        }
    }
    #endif
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            StretheoLog.watchConnectivity.error("Activation error: \(error.localizedDescription)")
            return
        }
        StretheoLog.watchConnectivity.info("Activated — state \(activationState.rawValue)")

        #if os(iOS)
        guard activationState == .activated else { return }
        Task { @MainActor in
            WatchConnectivityManager.shared.pushNotificationSettingsToWatch()
        }
        #endif

        #if os(watchOS)
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        if context["dataWipe"] != nil {
            Task { @MainActor in
                Self.applyWatchDataWipe()
            }
            return
        }
        let month = context["birthMonth"] as? Int
        let year = context["birthYear"] as? Int
        let sex = context["sex"] as? String
        Task { @MainActor in
            WatchProfileStore.applyProfile(month: month, year: year, sexRaw: sex)
            WatchProfileStore.applyNotificationSettings(from: context)
            if let display = Self.displayContext(from: context) {
                displayContextHandler?(display)
            }
        }
        #endif
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    #if os(iOS)
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let moodPayload = WatchMoodIncomingPayload(message) {
            Task { @MainActor in
                await handleIncomingMoodEntry(moodPayload)
            }
            return
        }
        guard let payload = WatchIncomingPayload(message) else { return }
        Task { @MainActor in
            await handleIncomingStressData(payload)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let moodPayload = WatchMoodIncomingPayload(message) {
            replyHandler(["received": true])
            Task { @MainActor in
                await handleIncomingMoodEntry(moodPayload)
            }
            return
        }
        guard let payload = WatchIncomingPayload(message) else {
            replyHandler(["received": false])
            return
        }
        replyHandler(["received": true])
        Task { @MainActor in
            await handleIncomingStressData(payload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let moodPayload = WatchMoodIncomingPayload(userInfo) {
            Task { @MainActor in
                await handleIncomingMoodEntry(moodPayload)
                StretheoLog.watchConnectivity.info("Received queued Watch mood entry")
            }
            return
        }
        guard userInfo[WatchConnectivityPayloadKey.stressLevel.rawValue] != nil else {
            return
        }
        guard let payload = WatchIncomingPayload(userInfo) else { return }
        Task { @MainActor in
            await handleIncomingStressData(payload)
            StretheoLog.watchConnectivity.info("Received queued Watch result")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let month = applicationContext["birthMonth"] as? Int
        let year = applicationContext["birthYear"] as? Int
        let sex = applicationContext["sex"] as? String
        Task { @MainActor in
            WatchProfileStore.applyProfile(month: month, year: year, sexRaw: sex)
        }
    }

    @MainActor
    private func handleIncomingMoodEntry(_ payload: WatchMoodIncomingPayload) async {
        let entry = MoodEntry(
            moodScore: payload.score,
            moodWord: payload.word,
            entryDate: Date(timeIntervalSince1970: payload.timestamp),
            createdAt: Date()
        )

        let context = AppDependencies.shared.userContainer.mainContext
        context.insert(entry)
        do {
            try context.save()
            StretheoLog.watchConnectivity.info("Saved mood entry from Watch")
        } catch {
            StretheoLog.watchConnectivity.error("Mood entry save failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func handleIncomingStressData(_ payload: WatchIncomingPayload) async {
        let measuredAt = Date(timeIntervalSince1970: payload.measuredAt)
        StretheoLog.watchConnectivity.debug("Received Watch measurement at \(measuredAt)")

        do {
            let measurement = try await AppDependencies.shared.stressRepository.saveFromWatch(
                level: payload.level,
                measuredAt: measuredAt,
                data: payload.dictionary
            )
            NotificationCenter.default.post(
                name: .newMeasurementSaved,
                object: nil,
                userInfo: [StressNotificationUserInfoKey.level: payload.level]
            )

            let category = payload.category.flatMap(StressCategory.init(rawValue:))
                ?? StressCategory.from(level: payload.level)
            let message = String(localized: "notification.stress.body")

            if payload.watchNotificationSent {
                StretheoLog.watchConnectivity.debug("Watch already sent local notification — logging on iPhone")
                do {
                    try AppDependencies.shared.notificationLogRepository.log(
                        stressLevel: payload.level,
                        message: message,
                        triggeredByMeasurement: measurement,
                        source: .watch
                    )
                } catch {
                    StretheoLog.watchConnectivity.error("Watch-origin notification log failed: \(error.localizedDescription)")
                }
            } else {
                await AppDependencies.shared.notificationManager.scheduleStressAlertIfNeeded(
                    level: payload.level,
                    category: category,
                    stressRepository: AppDependencies.shared.stressRepository,
                    triggeredMeasurement: measurement
                )
            }
        } catch {
            StretheoLog.watchConnectivity.error("saveFromWatch failed: \(error.localizedDescription)")
        }
    }
    #endif

    #if os(watchOS)
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        if applicationContext["dataWipe"] != nil {
            Task { @MainActor in
                Self.applyWatchDataWipe()
            }
            return
        }
        let month = applicationContext["birthMonth"] as? Int
        let year = applicationContext["birthYear"] as? Int
        let sex = applicationContext["sex"] as? String
        Task { @MainActor in
            WatchProfileStore.applyProfile(month: month, year: year, sexRaw: sex)
            WatchProfileStore.applyNotificationSettings(from: applicationContext)
            if let display = Self.displayContext(from: applicationContext) {
                displayContextHandler?(display)
            }
        }
    }

    private static func displayContext(from context: [String: Any]) -> [String: Any]? {
        guard context[WatchConnectivityPayloadKey.stressLevel.rawValue] as? Int != nil else { return nil }
        return [
            WatchConnectivityPayloadKey.stressLevel.rawValue: context[WatchConnectivityPayloadKey.stressLevel.rawValue] as Any,
            WatchConnectivityPayloadKey.category.rawValue: context[WatchConnectivityPayloadKey.category.rawValue] as Any,
            WatchConnectivityPayloadKey.measuredAt.rawValue: context[WatchConnectivityPayloadKey.measuredAt.rawValue] as Any
        ]
    }

    private static func applyWatchDataWipe() {
        WatchProfileStore.clearAll()
        WatchStressStore.clearAll()
        WatchNotificationState.clearAll()
        WatchStressReadingHistory.clearAll()
    }
    #endif
}

#if os(iOS)
enum WatchProfileStore {
    @MainActor
    static func applyProfile(month: Int?, year: Int?, sexRaw: String?) {}
}
#endif

#if os(watchOS)
enum WatchProfileStore {
    private static let fileName = "watch_profile_demographics.json"
    private static let birthMonthKey = "watch.profile.birthMonth"
    private static let birthYearKey = "watch.profile.birthYear"
    private static let sexKey = "watch.profile.sex"

    private struct Payload: Codable {
        var birthMonth: Int?
        var birthYear: Int?
        var sex: String?
        var notificationsEnabled: Bool?
        var stressAlertThreshold: Int?
        var quietHoursStart: TimeInterval?
        var quietHoursEnd: TimeInterval?
    }

    struct SyncedNotificationSettings: Sendable {
        let notificationsEnabled: Bool
        let stressAlertThreshold: Int
        let quietHoursStart: Date
        let quietHoursEnd: Date
    }

    static func notificationSettings() -> SyncedNotificationSettings {
        let payload = loadPayload()
        let quietStart = payload.quietHoursStart.map { Date(timeIntervalSince1970: $0) }
            ?? NotificationPolicy.defaultQuietHoursStart()
        let quietEnd = payload.quietHoursEnd.map { Date(timeIntervalSince1970: $0) }
            ?? NotificationPolicy.defaultQuietHoursEnd()
        return SyncedNotificationSettings(
            notificationsEnabled: payload.notificationsEnabled ?? false,
            stressAlertThreshold: payload.stressAlertThreshold ?? NotificationPolicy.defaultStressAlertThreshold,
            quietHoursStart: quietStart,
            quietHoursEnd: quietEnd
        )
    }

    @MainActor
    static func applyNotificationSettings(from context: [String: Any]) {
        var payload = loadPayload()
        if let enabled = context[WatchConnectivityPayloadKey.notificationsEnabled.rawValue] as? Bool {
            payload.notificationsEnabled = enabled
        }
        if let threshold = context[WatchConnectivityPayloadKey.stressAlertThreshold.rawValue] as? Int {
            payload.stressAlertThreshold = threshold
        } else if let threshold = context[WatchConnectivityPayloadKey.stressAlertThreshold.rawValue] as? NSNumber {
            payload.stressAlertThreshold = threshold.intValue
        }
        if let start = context[WatchConnectivityPayloadKey.quietHoursStart.rawValue] as? TimeInterval {
            payload.quietHoursStart = start
        } else if let start = context[WatchConnectivityPayloadKey.quietHoursStart.rawValue] as? NSNumber {
            payload.quietHoursStart = start.doubleValue
        }
        if let end = context[WatchConnectivityPayloadKey.quietHoursEnd.rawValue] as? TimeInterval {
            payload.quietHoursEnd = end
        } else if let end = context[WatchConnectivityPayloadKey.quietHoursEnd.rawValue] as? NSNumber {
            payload.quietHoursEnd = end.doubleValue
        }
        savePayload(payload)
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(fileName, isDirectory: false)
    }

    @MainActor
    static func applyProfile(month: Int?, year: Int?, sexRaw: String?) {
        var payload = loadPayload()
        if let month { payload.birthMonth = month }
        if let year { payload.birthYear = year }
        if let sexRaw { payload.sex = sexRaw }
        savePayload(payload)
        clearLegacyUserDefaults()
    }

    static func profileFields(for base: HealthInput) -> HealthInput {
        let payload = loadPayload()
        var input = base
        if let month = payload.birthMonth {
            input.birthMonth = month
        }
        if let year = payload.birthYear {
            input.birthYear = year
        }
        if let sexRaw = payload.sex,
           let sex = ProfileSex(rawValue: sexRaw) {
            input.sex = sex
        }
        return input
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
        clearLegacyUserDefaults()
    }

    private static func loadPayload() -> Payload {
        migrateLegacyUserDefaultsIfNeeded()
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return Payload()
        }
        return payload
    }

    private static func savePayload(_ payload: Payload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let url = fileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
        PrivacyFileAttributes.applySensitiveFileProtection(at: url)
    }

    private static func migrateLegacyUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let hasLegacy = defaults.object(forKey: birthMonthKey) != nil
            || defaults.object(forKey: birthYearKey) != nil
            || defaults.string(forKey: sexKey) != nil
        guard hasLegacy, !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        var payload = Payload()
        if defaults.object(forKey: birthMonthKey) != nil {
            payload.birthMonth = defaults.integer(forKey: birthMonthKey)
        }
        if defaults.object(forKey: birthYearKey) != nil {
            payload.birthYear = defaults.integer(forKey: birthYearKey)
        }
        payload.sex = defaults.string(forKey: sexKey)
        savePayload(payload)
        clearLegacyUserDefaults()
    }

    private static func clearLegacyUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: birthMonthKey)
        defaults.removeObject(forKey: birthYearKey)
        defaults.removeObject(forKey: sexKey)
    }
}
#endif
