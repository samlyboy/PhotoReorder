import Foundation

enum ReorderPlanner {

    /// 把区间内的素材按「图1 视1 图2 视2 …」交错，并给每个分配最终编号与时间戳。
    ///
    /// 注意：`items` 传的是**已选中的素材**（点格子取消选取的已被剔除），
    /// 所以 `start` / `end` 是「已选序列」里的位置，1 起。
    ///
    /// - `start < end` 正序：从第 start 个走到第 end 个，编号 1 给最先进的。
    /// - `start > end` 倒序：区间仍是 [end, start]，但遍历方向反过来，
    ///   原第 start 个最先处理、编号 1，原第 end 个最后处理、编号 N。
    ///   即「起 9 止 1」＝左上角那格编号 9、右下角那格编号 1。
    /// - 交错在「遍历顺序」上做，所以倒序时图/视各自的相对顺序也一起反过来。
    /// - 时间戳固定「编号 1 最新」：相册默认最新在前，从上往下读就是 1 → N。
    static func makePlan(items: [MediaItem], start: Int, end: Int, now: Date) -> ReorderPlan {
        let count = items.count
        guard count > 0 else {
            return ReorderPlan(separatorDate: now, entries: [])
        }

        let clampedStart = min(max(1, start), count)
        let clampedEnd = min(max(1, end), count)

        let lower = min(clampedStart, clampedEnd)
        let upper = max(clampedStart, clampedEnd)
        let isReverse = clampedStart > clampedEnd

        var slice = Array(items[(lower - 1)...(upper - 1)])
        if isReverse { slice.reverse() }

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
            let date = now.addingTimeInterval(-Double(number) * 2.0)
            entries.append(PlanEntry(id: "\(number)-\(item.id)", item: item, number: number, date: date))
        }

        return ReorderPlan(separatorDate: now, entries: entries)
    }
}
