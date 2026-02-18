import Foundation

/// Checks if a new time range overlaps with any existing ranges.
/// Two ranges overlap if start1 < end2 && start2 < end1.
///
/// - Parameters:
///   - existing: Array of (id, start, end) for existing time entries
///   - newStart: Start of the new/edited range
///   - newEnd: End of the new/edited range
///   - excludingId: If set, skip the entry with this ID (used when editing an existing entry)
/// - Returns: true if overlap is detected
func hasOverlappingTimeRanges(
    existing: [(id: UUID, start: Date, end: Date)],
    newStart: Date,
    newEnd: Date,
    excludingId: UUID? = nil
) -> Bool {
    for entry in existing {
        if let excluding = excludingId, entry.id == excluding { continue }
        // Overlap: start1 < end2 && start2 < end1
        if newStart < entry.end && entry.start < newEnd {
            return true
        }
    }
    return false
}
