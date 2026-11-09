import Foundation

enum ReorderPlanner {

    /// 把区间内的素材按「图1 视1 图2 视2 …」交错，并给每个分配时间戳。
    /// newestFirst = true 时，编号 1 的时间最新（相册默认最新在前，从上往下读就是 1→N）。
    static func makePlan(
        items: [MediaItem],
        range: ClosedRange<Int>,
        newestFirst: Bool,
        now: Date
    ) -> ReorderPlan {
        let lower = max(1, range.lowerBound)
        let upper = min(items.count, range.upperBound)
        guard lower <= upper else {
            return ReorderPlan(separatorDate: now, entries: [])
        }

        let slice = Array(items[(lower - 1)...(upper - 1)])
        let images = slice.filter { $0.kind == .image }
        let videos = slice.filter { $0.kind == .video }

        var ordered: [MediaItem] = []
        ordered.reserveCapacity(slice.count)
        var i = 0
        var j = 0
        while i < images.count || j < videos.count {
            if i < images.count {
                ordered.append(images[i])
                i += 1
            }
            if j < videos.count {
                ordered.append(videos[j])
                j += 1
            }
        }

        var entries: [PlanEntry] = []
        entries.reserveCapacity(ordered.count)
        for (index, item) in ordered.enumerated() {
            let number = index + 1
            let offset = Double(number) * 2.0
            let date = newestFirst
                ? now.addingTimeInterval(-offset)
                : now.addingTimeInterval(offset)
            entries.append(PlanEntry(id: "\(number)-\(item.id)", item: item, number: number, date: date))
        }

        let separatorDate = newestFirst
            ? now
            : now.addingTimeInterval(-2.0)

        return ReorderPlan(separatorDate: separatorDate, entries: entries)
    }
}
