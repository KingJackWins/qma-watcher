const MS_PER_DAY = 24 * 60 * 60 * 1000

export const DEFAULT_COLD_START_HISTORY_DAYS = 7
export const DEFAULT_PROGRESSIVE_CHUNK_DAYS = 30
export const ALL_TIME_HISTORY_DAYS = 365
export const THIRTY_DAY_HISTORY_DAYS = 30
export const WEEK_HISTORY_DAYS = 7

export type ProgressiveBackfillPeriod = 'today' | 'week' | '30days' | 'month' | 'all'

export function resolveColdStartHistoryDays(period: ProgressiveBackfillPeriod, now = new Date()): number {
  switch (period) {
    case 'today':
      return 1
    case 'week':
      return WEEK_HISTORY_DAYS
    case '30days':
      return THIRTY_DAY_HISTORY_DAYS
    case 'month':
      return Math.max(now.getDate(), 1)
    case 'all':
      return ALL_TIME_HISTORY_DAYS
  }
}

type ProgressiveBackfillStartInput = {
  lastComputedDate: string | null
  oldestCachedDate: string | null
  todayStart: Date
  yesterdayEnd: Date
  backfillDays: number
  coldStartHistoryDays?: number
  progressiveChunkDays?: number
}

function nextLocalMidnight(dateString: string): Date {
  return new Date(
    parseInt(dateString.slice(0, 4), 10),
    parseInt(dateString.slice(5, 7), 10) - 1,
    parseInt(dateString.slice(8, 10), 10) + 1,
  )
}

export function computeProgressiveBackfillStart({
  lastComputedDate,
  oldestCachedDate,
  todayStart,
  yesterdayEnd,
  backfillDays,
  coldStartHistoryDays = DEFAULT_COLD_START_HISTORY_DAYS,
  progressiveChunkDays = DEFAULT_PROGRESSIVE_CHUNK_DAYS,
}: ProgressiveBackfillStartInput): Date {
  const fullBackfillStart = new Date(todayStart.getTime() - backfillDays * MS_PER_DAY)
  const neededStart = new Date(todayStart.getTime() - (coldStartHistoryDays - 1) * MS_PER_DAY)

  if (!lastComputedDate) {
    // Cold start: fill from the period's required start date.
    const priorHistoryDays = Math.max(coldStartHistoryDays - 1, 0)
    return new Date(todayStart.getTime() - priorHistoryDays * MS_PER_DAY)
  }

  // Forward gap: cache doesn't reach yesterday yet.
  const gapStart = nextLocalMidnight(lastComputedDate)
  if (gapStart.getTime() <= yesterdayEnd.getTime()) {
    if (gapStart < fullBackfillStart) return fullBackfillStart
    if ((yesterdayEnd.getTime() - gapStart.getTime()) > progressiveChunkDays * MS_PER_DAY) {
      return new Date(yesterdayEnd.getTime() - progressiveChunkDays * MS_PER_DAY)
    }
    return gapStart
  }

  // Backward gap: cache covers through yesterday but doesn't go far enough back
  // for the requested period. E.g., cache has 7 days but user wants 30 days.
  if (oldestCachedDate && neededStart.getTime() < new Date(oldestCachedDate).getTime()) {
    const backTarget = new Date(oldestCachedDate)
    // Fill backward in chunks, capped at the needed start
    const chunkStart = new Date(backTarget.getTime() - progressiveChunkDays * MS_PER_DAY)
    return chunkStart < neededStart ? neededStart : chunkStart
  }

  return gapStart
}
