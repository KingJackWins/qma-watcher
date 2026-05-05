const MS_PER_DAY = 24 * 60 * 60 * 1000

export const DEFAULT_COLD_START_HISTORY_DAYS = 7
export const DEFAULT_PROGRESSIVE_CHUNK_DAYS = 30

type ProgressiveBackfillStartInput = {
  lastComputedDate: string | null
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
  todayStart,
  yesterdayEnd,
  backfillDays,
  coldStartHistoryDays = DEFAULT_COLD_START_HISTORY_DAYS,
  progressiveChunkDays = DEFAULT_PROGRESSIVE_CHUNK_DAYS,
}: ProgressiveBackfillStartInput): Date {
  const fullBackfillStart = new Date(todayStart.getTime() - backfillDays * MS_PER_DAY)

  if (!lastComputedDate) {
    // Today's sessions are always parsed separately below, so the cache only needs the
    // prior N-1 days to make a complete N-day history window on first load.
    const priorHistoryDays = Math.max(coldStartHistoryDays - 1, 0)
    return new Date(todayStart.getTime() - priorHistoryDays * MS_PER_DAY)
  }

  const gapStart = nextLocalMidnight(lastComputedDate)
  if (gapStart < fullBackfillStart) return fullBackfillStart

  if ((yesterdayEnd.getTime() - gapStart.getTime()) > progressiveChunkDays * MS_PER_DAY) {
    return new Date(yesterdayEnd.getTime() - progressiveChunkDays * MS_PER_DAY)
  }

  return gapStart
}
