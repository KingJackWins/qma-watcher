import Foundation
import Testing
@testable import ExeWatcherMenubar

private func makePayload(
    label: String,
    cost: Double,
    providers: [String: Double]
) -> MenubarPayload {
    MenubarPayload(
        generated: "2026-05-04T00:00:00Z",
        current: CurrentBlock(
            label: label,
            cost: cost,
            calls: Int(cost),
            sessions: 1,
            oneShotRate: nil,
            inputTokens: 0,
            outputTokens: 0,
            cacheHitPercent: 0,
            topActivities: [],
            topModels: [],
            providers: providers
        ),
        optimize: OptimizeBlock(findingCount: 0, savingsUSD: 0, topFindings: []),
        history: HistoryBlock(daily: []),
        diagnostics: nil,
        agentStats: nil,
        exeOsDetected: nil,
        statsFileAge: nil,
        projectSpend: nil
    )
}

private actor FetchRecorder {
    private let payloads: [PayloadCacheKey: MenubarPayload]
    private var calls: [PayloadCacheKey] = []

    init(payloads: [PayloadCacheKey: MenubarPayload]) {
        self.payloads = payloads
    }

    func fetch(period: Period, provider: ProviderFilter, includeOptimize: Bool) async throws -> MenubarPayload {
        let key = PayloadCacheKey(period: period, provider: provider, includeOptimize: includeOptimize)
        calls.append(key)
        guard let payload = payloads[key] else {
            throw NSError(domain: "FetchRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing payload for \(key)"])
        }
        return payload
    }

    func recordedKeys() -> [PayloadCacheKey] {
        calls
    }
}

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}

private actor CallCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }

    func value() -> Int {
        count
    }
}

@Suite("AppStore provider prefetch")
struct AppStoreProviderPrefetchTests {
    @Test("refreshQuietly front-loads visible provider payloads for today")
    @MainActor
    func prefetchesVisibleProvidersOnInitialLoad() async throws {
        let allKey = PayloadCacheKey(period: .today, provider: .all)
        let claudeKey = PayloadCacheKey(period: .today, provider: .claude)
        let codexKey = PayloadCacheKey(period: .today, provider: .codex)

        let recorder = FetchRecorder(payloads: [
            allKey: makePayload(label: "Today", cost: 18, providers: ["claude": 12, "codex": 6]),
            claudeKey: makePayload(label: "Today", cost: 12, providers: ["claude": 12]),
            codexKey: makePayload(label: "Today", cost: 6, providers: ["codex": 6]),
        ])

        let store = AppStore(fetchPayload: { period, provider, includeOptimize in
            try await recorder.fetch(period: period, provider: provider, includeOptimize: includeOptimize)
        })

        await store.refreshQuietly(period: .today)

        let keys = await recorder.recordedKeys()
        #expect(keys == [allKey, claudeKey, codexKey])
        #expect(store.allProviderPayloadForPeriod?.current.cost == 18)
    }

    @Test("period switch prefetches that period's providers so tab switch is instant from cache")
    @MainActor
    func periodSwitchWarmsProviderTabs() async throws {
        let todayAll = PayloadCacheKey(period: .today, provider: .all)
        let todayClaude = PayloadCacheKey(period: .today, provider: .claude)
        let weekAll = PayloadCacheKey(period: .sevenDays, provider: .all)
        let weekClaude = PayloadCacheKey(period: .sevenDays, provider: .claude)
        let weekCodex = PayloadCacheKey(period: .sevenDays, provider: .codex)

        let recorder = FetchRecorder(payloads: [
            todayAll: makePayload(label: "Today", cost: 18, providers: ["claude": 12]),
            todayClaude: makePayload(label: "Today", cost: 12, providers: ["claude": 12]),
            weekAll: makePayload(label: "Last 7 Days", cost: 100, providers: ["claude": 70, "codex": 30]),
            weekClaude: makePayload(label: "Last 7 Days", cost: 70, providers: ["claude": 70]),
            weekCodex: makePayload(label: "Last 7 Days", cost: 30, providers: ["codex": 30]),
        ])

        let store = AppStore(fetchPayload: { period, provider, includeOptimize in
            try await recorder.fetch(period: period, provider: provider, includeOptimize: includeOptimize)
        })

        await store.refreshQuietly(period: .today)
        await store.switchTo(period: .sevenDays)
        try await Task.sleep(nanoseconds: 50_000_000)

        let keysAfterPeriodSwitch = await recorder.recordedKeys()
        #expect(keysAfterPeriodSwitch.contains(weekAll))
        #expect(keysAfterPeriodSwitch.contains(weekClaude))
        #expect(keysAfterPeriodSwitch.contains(weekCodex))

        let callCountBeforeTabSwitch = keysAfterPeriodSwitch.count
        await store.switchTo(provider: .claude)
        #expect(store.payload.current.cost == 70)

        try await Task.sleep(nanoseconds: 50_000_000)
        let callCountAfterTabSwitch = await recorder.recordedKeys().count
        #expect(callCountAfterTabSwitch == callCountBeforeTabSwitch)
    }

    @Test("optimize payload stays attached after a later base refresh for the same visible selection")
    @MainActor
    func optimizePayloadSurvivesBaseRefresh() async throws {
        let startOfDay = ISO8601DateFormatter().date(from: "2026-05-04T00:00:00Z")!
        let clock = TestClock(startOfDay)

        let baseKey = PayloadCacheKey(period: .today, provider: .all, includeOptimize: false, now: clock.now)
        let optimizeKey = PayloadCacheKey(period: .today, provider: .all, includeOptimize: true, now: clock.now)

        let recorder = FetchRecorder(payloads: [
            baseKey: makePayload(label: "Today", cost: 18, providers: ["claude": 12]),
            optimizeKey: MenubarPayload(
                generated: "2026-05-04T00:00:00Z",
                current: CurrentBlock(
                    label: "Today",
                    cost: 18,
                    calls: 18,
                    sessions: 1,
                    oneShotRate: nil,
                    inputTokens: 0,
                    outputTokens: 0,
                    cacheHitPercent: 0,
                    topActivities: [],
                    topModels: [],
                    providers: ["claude": 12]
                ),
                optimize: OptimizeBlock(findingCount: 3, savingsUSD: 12, topFindings: []),
                history: HistoryBlock(daily: []),
                diagnostics: nil,
                agentStats: nil,
                exeOsDetected: nil,
                statsFileAge: nil,
                projectSpend: nil
            ),
        ])

        let store = AppStore(
            fetchPayload: { period, provider, includeOptimize in
                try await recorder.fetch(period: period, provider: provider, includeOptimize: includeOptimize)
            },
            now: { clock.now }
        )

        await store.refreshQuietly(period: .today)
        #expect(store.payload.optimize.findingCount == 0)

        await store.refresh(includeOptimize: true)
        #expect(store.payload.optimize.findingCount == 3)

        clock.now = startOfDay.addingTimeInterval(31)
        await store.refreshQuietly(period: .today)
        #expect(store.payload.optimize.findingCount == 3)
    }

    @Test("today cache key rolls at the day boundary so stale yesterday payloads are not reused")
    @MainActor
    func todayCacheKeyRollsAtDayBoundary() async throws {
        let dayOne = ISO8601DateFormatter().date(from: "2026-05-04T12:00:00Z")!
        let clock = TestClock(dayOne)
        let counter = CallCounter()

        let store = AppStore(
            fetchPayload: { _, _, _ in
                let value = await counter.next()
                return makePayload(label: "Today", cost: Double(value), providers: [:])
            },
            now: { clock.now }
        )

        await store.refreshQuietly(period: .today)
        #expect(await counter.value() == 1)
        #expect(store.payload.current.cost == 1)

        await store.refreshQuietly(period: .today)
        #expect(await counter.value() == 1)

        clock.now = dayOne.addingTimeInterval(24 * 60 * 60)
        await store.refreshQuietly(period: .today)
        #expect(await counter.value() == 2)
        #expect(store.payload.current.cost == 2)
    }
}
