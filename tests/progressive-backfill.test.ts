import { describe, expect, it } from 'vitest'

import {
  computeProgressiveBackfillStart,
  DEFAULT_COLD_START_HISTORY_DAYS,
  DEFAULT_PROGRESSIVE_CHUNK_DAYS,
} from '../src/progressive-backfill.js'

const MS_PER_DAY = 24 * 60 * 60 * 1000

function localDate(year: number, month: number, day: number, hour = 0, minute = 0, second = 0, ms = 0): Date {
  return new Date(year, month - 1, day, hour, minute, second, ms)
}

describe('computeProgressiveBackfillStart', () => {
  it('backfills enough prior days to make a full cold-start history window', () => {
    const todayStart = localDate(2026, 5, 5)
    const yesterdayEnd = new Date(todayStart.getTime() - 1)

    const start = computeProgressiveBackfillStart({
      lastComputedDate: null,
      todayStart,
      yesterdayEnd,
      backfillDays: 365,
    })

    expect(start.getTime()).toBe(todayStart.getTime() - (DEFAULT_COLD_START_HISTORY_DAYS - 1) * MS_PER_DAY)
  })

  it('clamps stale caches to the full backfill window', () => {
    const todayStart = localDate(2026, 5, 5)
    const yesterdayEnd = new Date(todayStart.getTime() - 1)

    const start = computeProgressiveBackfillStart({
      lastComputedDate: '2025-01-01',
      todayStart,
      yesterdayEnd,
      backfillDays: 30,
    })

    expect(start).toEqual(localDate(2026, 4, 5))
  })

  it('limits warm-cache catch-up to the progressive chunk size', () => {
    const todayStart = localDate(2026, 5, 5)
    const yesterdayEnd = new Date(todayStart.getTime() - 1)

    const start = computeProgressiveBackfillStart({
      lastComputedDate: '2026-03-01',
      todayStart,
      yesterdayEnd,
      backfillDays: 365,
    })

    expect(start.getTime()).toBe(yesterdayEnd.getTime() - DEFAULT_PROGRESSIVE_CHUNK_DAYS * MS_PER_DAY)
  })

  it('starts from the next day when the cache is only slightly behind', () => {
    const todayStart = localDate(2026, 5, 5)
    const yesterdayEnd = new Date(todayStart.getTime() - 1)

    const start = computeProgressiveBackfillStart({
      lastComputedDate: '2026-05-03',
      todayStart,
      yesterdayEnd,
      backfillDays: 365,
    })

    expect(start).toEqual(localDate(2026, 5, 4))
  })
})
