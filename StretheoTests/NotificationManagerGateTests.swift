//
//  NotificationManagerGateTests.swift
//  StretheoTests
//
//  Characterization tests for NotificationManager.scheduleStressAlertIfNeeded —
//  captures CURRENT gate behavior (oracle for future consolidation).
//

import Foundation
import ObjectiveC
import Testing
import UserNotifications
@testable import Stretheo

// MARK: - Fakes

@MainActor
private final class FakeStressRepository: StressRepositoryProtocol {
    var recent: [StressMeasurement] = []
    var latest: StressMeasurement?
    private(set) var recentMeasurementsCallCount = 0

    func save(result: StressResult, input: HealthInput, trigger: TriggerType) async throws -> StressMeasurement {
        Issue.record("FakeStressRepository.save should not be called in gate tests")
        throw AppError.healthKitUnavailable
    }

    func saveFromWatch(level: Int, measuredAt: Date, data: [String: Any]) async throws -> StressMeasurement {
        Issue.record("FakeStressRepository.saveFromWatch should not be called in gate tests")
        throw AppError.healthKitUnavailable
    }

    func measurements(from start: Date, to end: Date, limit: Int) throws -> [StressMeasurement] { [] }
    func latestMeasurement() throws -> StressMeasurement? { latest }
    func todayMeasurements() throws -> [StressMeasurement] { [] }
    func todayAverageStressLevel() throws -> Int? { nil }
    func deleteAll() throws {}
    func recentMeasurements(limit: Int) throws -> [StressMeasurement] {
        recentMeasurementsCallCount += 1
        return Array(recent.prefix(limit))
    }
    func pruneHealthSnapshotsOlderThan(days: Int) throws -> Int { 0 }
}

@MainActor
private final class FakeNotificationLogRepository: NotificationLogRepositoryProtocol {
    var recentlyNotifiedFromWatchResult = false
    var recentlyNotifiedFromWatchCalls: [UUID] = []
    var logCalls: [(level: Int, source: NotificationSource)] = []

    func log(
        stressLevel: Int,
        message: String,
        triggeredByMeasurement: StressMeasurement?,
        source: NotificationSource
    ) throws -> NotificationLog {
        logCalls.append((stressLevel, source))
        return NotificationLog(stressLevelAtTrigger: stressLevel, messageText: message, source: source)
    }

    func recentlyNotifiedFromWatch(for measurementID: UUID) throws -> Bool {
        recentlyNotifiedFromWatchCalls.append(measurementID)
        return recentlyNotifiedFromWatchResult
    }

    func recentLogs(limit: Int) throws -> [NotificationLog] { [] }
    func markRead(id: UUID) throws {}
    func deleteAll() throws {}
}

@MainActor
private final class FakeNotificationAuthorizationChecker: NotificationAuthorizationChecking {
    var status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }
}

// MARK: - Test-only UN add stub
//
// Gate 5 is injectable; `deliverStressNotification` still calls
// `UNUserNotificationCenter.current().add`. Without OS permission that call fails and
// never reaches AppSettings.recordStressNotificationSent(). Send-path tests stub only
// the ObjC completion-handler add API (tests only — no production changes).

private enum FakeUNNotificationCenterAdd {
    private static let lock = NSLock()
    private static var _isInstalled = false
    private static var _succeedWithoutSystem = false
    private static var _addCallCount = 0

    static var isInstalled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isInstalled
    }

    static var succeedWithoutSystem: Bool {
        get {
            lock.lock(); defer { lock.unlock() }
            return _succeedWithoutSystem
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _succeedWithoutSystem = newValue
        }
    }

    static var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _addCallCount
    }

    static func resetCallCount() {
        lock.lock(); defer { lock.unlock() }
        _addCallCount = 0
    }

    static func installIfNeeded() {
        lock.lock()
        let already = _isInstalled
        if !already { _isInstalled = true }
        lock.unlock()
        guard !already else { return }

        let selector = NSSelectorFromString("addNotificationRequest:withCompletionHandler:")
        guard let method = class_getInstanceMethod(UNUserNotificationCenter.self, selector) else {
            Issue.record("Unable to locate UNUserNotificationCenter.addNotificationRequest:withCompletionHandler:")
            return
        }

        typealias AddIMP = @convention(c) (
            UNUserNotificationCenter,
            Selector,
            UNNotificationRequest,
            ((Error?) -> Void)?
        ) -> Void

        let originalIMP = method_getImplementation(method)
        let original = unsafeBitCast(originalIMP, to: AddIMP.self)

        let block: @convention(block) (
            UNUserNotificationCenter,
            UNNotificationRequest,
            ((Error?) -> Void)?
        ) -> Void = { center, request, completion in
            FakeUNNotificationCenterAdd.lock.lock()
            FakeUNNotificationCenterAdd._addCallCount += 1
            let succeed = FakeUNNotificationCenterAdd._succeedWithoutSystem
            FakeUNNotificationCenterAdd.lock.unlock()

            if succeed {
                completion?(nil)
                return
            }
            original(center, selector, request, completion)
        }

        let newIMP = imp_implementationWithBlock(block)
        method_setImplementation(method, newIMP)
    }
}

// MARK: - AppSettings fixture

@MainActor
private enum GateTestSettings {
    struct Snapshot {
        var notificationsEnabled: Bool
        var stressAlertThreshold: Int
        var quietHoursStart: Date
        var quietHoursEnd: Date
        var notificationDailyCount: Int
        var notificationCountResetDay: Date?
        var lastNotifiedAt: Date?
    }

    static func capture() -> Snapshot {
        Snapshot(
            notificationsEnabled: AppSettings.notificationsEnabled,
            stressAlertThreshold: AppSettings.stressAlertThreshold,
            quietHoursStart: AppSettings.quietHoursStart,
            quietHoursEnd: AppSettings.quietHoursEnd,
            notificationDailyCount: AppSettings.notificationDailyCount,
            notificationCountResetDay: AppSettings.notificationCountResetDay,
            lastNotifiedAt: AppSettings.lastNotifiedAt
        )
    }

    static func restore(_ snapshot: Snapshot) {
        AppSettings.notificationsEnabled = snapshot.notificationsEnabled
        AppSettings.stressAlertThreshold = snapshot.stressAlertThreshold
        AppSettings.quietHoursStart = snapshot.quietHoursStart
        AppSettings.quietHoursEnd = snapshot.quietHoursEnd
        AppSettings.notificationDailyCount = snapshot.notificationDailyCount
        AppSettings.notificationCountResetDay = snapshot.notificationCountResetDay
        AppSettings.lastNotifiedAt = snapshot.lastNotifiedAt
    }

    /// Quiet hours that do not include the current clock (same-day window in the future).
    static func quietHoursAwayFromNow() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .hour, value: 3, to: now) ?? now.addingTimeInterval(3 * 3600)
        let end = calendar.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(4 * 3600)
        return (start, end)
    }

    /// Same-day quiet window that includes now.
    static func quietHoursCoveringNow() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .minute, value: -30, to: now) ?? now.addingTimeInterval(-1800)
        let end = calendar.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        return (start, end)
    }

    /// Overnight-style window (start minutes > end minutes) that includes now.
    static func overnightQuietHoursCoveringNow() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        // start = 30 minutes ago, end = 90 minutes ago → startMinutes > endMinutes (wrap branch)
        let start = calendar.date(byAdding: .minute, value: -30, to: now) ?? now.addingTimeInterval(-1800)
        let end = calendar.date(byAdding: .minute, value: -90, to: now) ?? now.addingTimeInterval(-5400)
        return (start, end)
    }

    static func dateWith(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}

// MARK: - Helpers

@MainActor
private enum GateTestHarness {
    static func makeMeasurement(level: Int, id: UUID = UUID()) -> StressMeasurement {
        StressMeasurement(
            id: id,
            stressLevel: level,
            stressCategory: StressCategory.from(level: level),
            triggerType: .automatic
        )
    }

    /// Prepares AppSettings so gates 0–4 would pass (notifications on, above threshold,
    /// outside quiet hours, under daily cap, outside min interval). Does not control Gate 5 (UN).
    static func preparePassingAppSettingsGates(threshold: Int = 67, levelAboveThreshold _: Int = 80) {
        AppSettings.notificationsEnabled = true
        AppSettings.stressAlertThreshold = threshold
        let quiet = GateTestSettings.quietHoursAwayFromNow()
        AppSettings.quietHoursStart = quiet.start
        AppSettings.quietHoursEnd = quiet.end
        AppSettings.notificationCountResetDay = Calendar.current.startOfDay(for: Date())
        AppSettings.notificationDailyCount = 0
        AppSettings.lastNotifiedAt = nil
    }

    static func sentSnapshot() -> (count: Int, last: Date?) {
        (AppSettings.notificationDailyCount, AppSettings.lastNotifiedAt)
    }

    static func wasSent(before: (count: Int, last: Date?), log: FakeNotificationLogRepository) -> Bool {
        let after = sentSnapshot()
        let countIncreased = after.count > before.count
        let lastUpdated = after.last != before.last
        let logged = !log.logCalls.isEmpty
        return countIncreased || lastUpdated || logged
    }

    static func configure(
        log: FakeNotificationLogRepository,
        authorization status: UNAuthorizationStatus = .denied
    ) {
        NotificationManager.shared.configure(
            notificationLogRepository: log,
            authorizationChecker: FakeNotificationAuthorizationChecker(status: status)
        )
    }

    /// Restores the production authorization checker so later tests are not polluted.
    static func restoreSystemAuthorization() {
        NotificationManager.shared.configure(
            notificationLogRepository: FakeNotificationLogRepository(),
            authorizationChecker: SystemNotificationAuthorizationChecker.shared
        )
    }
}

// MARK: - Tests

@MainActor
struct NotificationManagerGateTests {

    /// Effective daily limit matching NotificationPolicy.maxNotificationsPerDay (DEBUG = 20).
    private static var expectedDebugDailyLimit: Int { NotificationPolicy.maxNotificationsPerDay }

    @Test func gate0_skipsWhenNotificationsDisabled() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        let manager = NotificationManager.shared
        manager.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        AppSettings.notificationsEnabled = false
        let before = GateTestHarness.sentSnapshot()

        await manager.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(!GateTestHarness.wasSent(before: before, log: log))
        #expect(log.logCalls.isEmpty)
    }

    @Test func gate1_skipsWhenLevelBelowThreshold() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates(threshold: 67)
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 66,
            category: StressCategory.from(level: 66),
            stressRepository: stress
        )

        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate1_allowsLevelAtThreshold_subjectToLaterGates() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 67),
            GateTestHarness.makeMeasurement(level: 67)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates(threshold: 67)
        let before = GateTestHarness.sentSnapshot()
        let auth = await NotificationManager.shared.authorizationStatus()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 67,
            category: StressCategory.from(level: 67),
            stressRepository: stress
        )

        let sent = GateTestHarness.wasSent(before: before, log: log)
        // Characterization: at-threshold clears Gate 1. Delivery still requires Gates 5–6 + UN add.
        if auth == .authorized || auth == .provisional {
            #expect(sent)
        } else {
            #expect(!sent)
        }
    }

    @Test func gate1_allowsLevelAboveThreshold_subjectToLaterGates() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates(threshold: 67)
        let before = GateTestHarness.sentSnapshot()
        let auth = await NotificationManager.shared.authorizationStatus()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        let sent = GateTestHarness.wasSent(before: before, log: log)
        if auth == .authorized || auth == .provisional {
            #expect(sent)
        } else {
            #expect(!sent)
        }
    }

    @Test func gate2_skipsWhenWithinSameDayQuietHours() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        let quiet = GateTestSettings.quietHoursCoveringNow()
        AppSettings.quietHoursStart = quiet.start
        AppSettings.quietHoursEnd = quiet.end
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate2_skipsWhenWithinOvernightQuietHoursWrap() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        let quiet = GateTestSettings.overnightQuietHoursCoveringNow()
        AppSettings.quietHoursStart = quiet.start
        AppSettings.quietHoursEnd = quiet.end

        // Confirm we are exercising the wrap branch (start minutes > end minutes).
        let calendar = Calendar.current
        let startM = calendar.component(.hour, from: quiet.start) * 60 + calendar.component(.minute, from: quiet.start)
        let endM = calendar.component(.hour, from: quiet.end) * 60 + calendar.component(.minute, from: quiet.end)
        #expect(startM > endM)

        let before = GateTestHarness.sentSnapshot()
        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate2_passesWhenOutsideQuietHours_subjectToLaterGates() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        let before = GateTestHarness.sentSnapshot()
        let auth = await NotificationManager.shared.authorizationStatus()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        let sent = GateTestHarness.wasSent(before: before, log: log)
        if auth == .authorized || auth == .provisional {
            #expect(sent)
        } else {
            // Outside quiet hours; still blocked later (typically Gate 5 on simulator).
            #expect(!sent)
        }
    }

    @Test func gate3_skipsWhenDailyCapReached_debugLimit20() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        AppSettings.notificationDailyCount = Self.expectedDebugDailyLimit
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(!GateTestHarness.wasSent(before: before, log: log))
        #expect(AppSettings.notificationDailyCount == Self.expectedDebugDailyLimit)
    }

    @Test func gate3_allowsWhenUnderDailyCap_subjectToLaterGates() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        AppSettings.notificationDailyCount = Self.expectedDebugDailyLimit - 1
        let before = GateTestHarness.sentSnapshot()
        let auth = await NotificationManager.shared.authorizationStatus()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        let sent = GateTestHarness.wasSent(before: before, log: log)
        if auth == .authorized || auth == .provisional {
            #expect(sent)
        } else {
            #expect(!sent)
            #expect(AppSettings.notificationDailyCount == Self.expectedDebugDailyLimit - 1)
        }
    }

    @Test func gate4_skipsWhenWithinMinimumInterval() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        // DEBUG NotificationPolicy.minimumInterval == 60s
        AppSettings.lastNotifiedAt = Date().addingTimeInterval(-(NotificationPolicy.minimumInterval / 2))
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate4_allowsWhenIntervalElapsed_subjectToLaterGates() async {
        let settings = GateTestSettings.capture()
        defer { GateTestSettings.restore(settings) }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        NotificationManager.shared.configure(notificationLogRepository: log)

        GateTestHarness.preparePassingAppSettingsGates()
        AppSettings.lastNotifiedAt = Date().addingTimeInterval(-(NotificationPolicy.minimumInterval + 5))
        let before = GateTestHarness.sentSnapshot()
        let auth = await NotificationManager.shared.authorizationStatus()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        let sent = GateTestHarness.wasSent(before: before, log: log)
        if auth == .authorized || auth == .provisional {
            #expect(sent)
        } else {
            #expect(!sent)
        }
    }

    @Test func gate5_authorized_proceedsToGate6() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let stress = FakeStressRepository()
        // Fail Gate 6 deliberately so we only assert Gate 5 was cleared (Gate 6 consulted).
        stress.recent = [GateTestHarness.makeMeasurement(level: 40)]
        let log = FakeNotificationLogRepository()
        GateTestHarness.configure(log: log, authorization: .authorized)
        GateTestHarness.preparePassingAppSettingsGates()
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(stress.recentMeasurementsCallCount == 1)
        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate5_provisional_proceedsToGate6() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let stress = FakeStressRepository()
        stress.recent = [GateTestHarness.makeMeasurement(level: 40)]
        let log = FakeNotificationLogRepository()
        GateTestHarness.configure(log: log, authorization: .provisional)
        GateTestHarness.preparePassingAppSettingsGates()
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(stress.recentMeasurementsCallCount == 1)
        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate5_denied_skipsAndDoesNotEvaluateGate6() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        GateTestHarness.configure(log: log, authorization: .denied)
        GateTestHarness.preparePassingAppSettingsGates()
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(stress.recentMeasurementsCallCount == 0)
        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate5_notDetermined_skipsAndDoesNotEvaluateGate6() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        GateTestHarness.configure(log: log, authorization: .notDetermined)
        GateTestHarness.preparePassingAppSettingsGates()
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(stress.recentMeasurementsCallCount == 0)
        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate6_withAuthorized_skipsWhenConsecutiveHighReadingsMissing() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let stress = FakeStressRepository()
        stress.recent = [GateTestHarness.makeMeasurement(level: 90)]
        let log = FakeNotificationLogRepository()
        GateTestHarness.configure(log: log, authorization: .authorized)
        GateTestHarness.preparePassingAppSettingsGates(threshold: 67)
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(stress.recentMeasurementsCallCount == 1)
        #expect(!GateTestHarness.wasSent(before: before, log: log))
        #expect(NotificationPolicy.consecutiveHighReadingsRequired == 2)
    }

    @Test func gate6_withAuthorized_skipsWhenRecentReadingsBelowThreshold() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 40),
            GateTestHarness.makeMeasurement(level: 40)
        ]
        let log = FakeNotificationLogRepository()
        GateTestHarness.configure(log: log, authorization: .authorized)
        GateTestHarness.preparePassingAppSettingsGates(threshold: 67)
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(stress.recentMeasurementsCallCount == 1)
        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func gate6_withAuthorized_sendsWhenConsecutiveHighReadingsExist() async {
        let settings = GateTestSettings.capture()
        FakeUNNotificationCenterAdd.installIfNeeded()
        FakeUNNotificationCenterAdd.succeedWithoutSystem = true
        FakeUNNotificationCenterAdd.resetCallCount()
        defer {
            FakeUNNotificationCenterAdd.succeedWithoutSystem = false
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
            NotificationManager.shared.removePendingStressNotifications()
        }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        stress.latest = stress.recent.first
        let log = FakeNotificationLogRepository()
        GateTestHarness.configure(log: log, authorization: .authorized)
        GateTestHarness.preparePassingAppSettingsGates(threshold: 67)
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress
        )

        #expect(stress.recentMeasurementsCallCount == 1)
        #expect(FakeUNNotificationCenterAdd.callCount >= 1)
        #expect(GateTestHarness.wasSent(before: before, log: log))
    }

    @Test func fullSuccessPath_allGatesAndWatchDedupePass_notificationAttempted() async {
        let settings = GateTestSettings.capture()
        FakeUNNotificationCenterAdd.installIfNeeded()
        FakeUNNotificationCenterAdd.succeedWithoutSystem = true
        FakeUNNotificationCenterAdd.resetCallCount()
        defer {
            FakeUNNotificationCenterAdd.succeedWithoutSystem = false
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
            NotificationManager.shared.removePendingStressNotifications()
        }

        let measurement = GateTestHarness.makeMeasurement(level: 90)
        let stress = FakeStressRepository()
        stress.recent = [measurement, GateTestHarness.makeMeasurement(level: 90)]
        stress.latest = measurement
        let log = FakeNotificationLogRepository()
        log.recentlyNotifiedFromWatchResult = false
        GateTestHarness.configure(log: log, authorization: .authorized)
        GateTestHarness.preparePassingAppSettingsGates(threshold: 67)
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress,
            triggeredMeasurement: measurement
        )

        #expect(log.recentlyNotifiedFromWatchCalls == [measurement.id])
        #expect(stress.recentMeasurementsCallCount == 1)
        #expect(FakeUNNotificationCenterAdd.callCount >= 1)
        #expect(GateTestHarness.wasSent(before: before, log: log))
        #expect(AppSettings.notificationDailyCount == before.count + 1)
        #expect(AppSettings.lastNotifiedAt != nil)
        #expect(!log.logCalls.isEmpty)
    }

    /// Algorithm oracle for the consecutive rule NM implements via
    /// `NotificationPolicy.consecutiveReadingsMeetThreshold`.
    @Test func gate6_consecutiveRule_currentAlgorithm() {
        let required = NotificationPolicy.consecutiveHighReadingsRequired
        #expect(required == 2)

        #expect(
            NotificationPolicy.consecutiveReadingsMeetThreshold(
                recentLevels: [90, 90],
                threshold: 67,
                requiredCount: required
            )
        )
        #expect(
            !NotificationPolicy.consecutiveReadingsMeetThreshold(
                recentLevels: [90],
                threshold: 67,
                requiredCount: required
            )
        )
        #expect(
            !NotificationPolicy.consecutiveReadingsMeetThreshold(
                recentLevels: [90, 40],
                threshold: 67,
                requiredCount: required
            )
        )
        #expect(
            NotificationPolicy.consecutiveReadingsMeetThreshold(
                recentLevels: [67, 67],
                threshold: 67,
                requiredCount: required
            )
        )
    }

    @Test func watchDedupe_skipsWhenAlreadyNotifiedFromWatchForMeasurement() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let measurement = GateTestHarness.makeMeasurement(level: 90)
        let stress = FakeStressRepository()
        stress.recent = [measurement, GateTestHarness.makeMeasurement(level: 90)]
        let log = FakeNotificationLogRepository()
        log.recentlyNotifiedFromWatchResult = true
        GateTestHarness.configure(log: log, authorization: .authorized)
        GateTestHarness.preparePassingAppSettingsGates()
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress,
            triggeredMeasurement: measurement
        )

        #expect(!GateTestHarness.wasSent(before: before, log: log))
        #expect(log.recentlyNotifiedFromWatchCalls == [measurement.id])
        #expect(log.logCalls.isEmpty)
        #expect(stress.recentMeasurementsCallCount == 0)
    }

    @Test func watchDedupe_doesNotApplyWhenTriggeredMeasurementNil() async {
        let settings = GateTestSettings.capture()
        defer {
            GateTestSettings.restore(settings)
            GateTestHarness.restoreSystemAuthorization()
        }

        let stress = FakeStressRepository()
        stress.recent = [
            GateTestHarness.makeMeasurement(level: 90),
            GateTestHarness.makeMeasurement(level: 90)
        ]
        let log = FakeNotificationLogRepository()
        log.recentlyNotifiedFromWatchResult = true
        GateTestHarness.configure(log: log, authorization: .denied)
        GateTestHarness.preparePassingAppSettingsGates()
        AppSettings.notificationsEnabled = false
        let before = GateTestHarness.sentSnapshot()

        await NotificationManager.shared.scheduleStressAlertIfNeeded(
            level: 90,
            category: .high,
            stressRepository: stress,
            triggeredMeasurement: nil
        )

        // Gate 0 blocks first; watch dedupe must not have been consulted.
        #expect(log.recentlyNotifiedFromWatchCalls.isEmpty)
        #expect(!GateTestHarness.wasSent(before: before, log: log))
    }
}
