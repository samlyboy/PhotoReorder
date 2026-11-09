import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var items: [MediaItem] = []
    @State private var startText = "1"
    @State private var endText = ""
    @State private var newestFirst = true
    @State private var isLoadingThumbs = false
    @StateObject private var runner = ReorderRunner()

    // MARK: - 计算属性

    private var startValue: Int? {
        guard let value = Int(startText.trimmingCharacters(in: .whitespaces)) else { return nil }
        return (value >= 1 && value <= items.count) ? value : nil
    }

    private var endValue: Int? {
        guard let value = Int(endText.trimmingCharacters(in: .whitespaces)) else { return nil }
        return (value >= 1 && value <= items.count) ? value : nil
    }

    private var selectedRange: ClosedRange<Int>? {
        guard let start = startValue, let end = endValue, start <= end else { return nil }
        return start...end
    }

    private var plan: ReorderPlan? {
        guard let range = selectedRange else { return nil }
        return ReorderPlanner.makePlan(
            items: items,
            range: range,
            newestFirst: newestFirst,
            now: Date()
        )
    }

    private var imageCount: Int { items.filter { $0.kind == .image }.count }
    private var videoCount: Int { items.filter { $0.kind == .video }.count }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pickerCard
                    if items.isEmpty {
                        emptyCard
                    } else {
                        gridSection
                        rangeSection
                        orderSection
                        directionSection
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("相册重排")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .overlay { if runner.isRunning { progressOverlay } }
            .alert(runner.alertTitle, isPresented: $runner.showAlert) {
                Button("好", role: .cancel) { }
            } message: {
                Text(runner.alertMessage)
            }
            .onChange(of: pickerItems) { _, newValue in
                Task { await reload(newValue) }
            }
        }
    }

    // MARK: - 选片

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 0,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            ) {
                Label(items.isEmpty ? "选择图片和视频" : "重新选择素材",
                      systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if !items.isEmpty {
                HStack(spacing: 14) {
                    Text("共 \(items.count) 个")
                    Text("图片 \(imageCount)")
                    Text("视频 \(videoCount)")
                    Spacer()
                    Button("清空") {
                        pickerItems = []
                        items = []
                        startText = "1"
                        endText = ""
                    }
                    .font(.footnote)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("怎么用").font(.headline)
            Text("1. 点上面的按钮，一次勾选要处理的图片和视频（不乱也行，程序会按相册时间排序）")
            Text("2. 用「起 / 止」两个数字圈出这一段要参与重排的素材")
            Text("3. 点底部「重新排列」：先写一张红色分隔图进相册，再按 图1 视1 图2 视2… 的顺序批量写入新文件，每张右上角带序号")
            Text("4. 原片不动，新文件进系统相册「最近项目」")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 网格

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("素材 · 左上角是原始序号（按相册时间排序）")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                spacing: 6
            ) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    thumbCell(index: index, item: item)
                }
            }

            if isLoadingThumbs {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("缩略图加载中…").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func isInRange(_ index: Int) -> Bool {
        guard let range = selectedRange else { return false }
        return range.contains(index + 1)
    }

    private func thumbCell(index: Int, item: MediaItem) -> some View {
        ZStack {
            if let thumb = item.thumb {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.secondarySystemFill)
                ProgressView().scaleEffect(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topLeading) {
            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.62), in: Capsule())
                .padding(5)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(4)
                .background(Color.black.opacity(0.55), in: Circle())
                .padding(5)
        }
        .overlay {
            if !isInRange(index) {
                RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55))
            }
        }
        .overlay {
            if isInRange(index) {
                RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2.5)
            }
        }
    }

    // MARK: - 区间

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("处理区间").font(.headline)

            HStack(spacing: 12) {
                numberField(title: "起", text: $startText)
                numberField(title: "止", text: $endText)
                Button("全部") {
                    startText = "1"
                    endText = "\(items.count)"
                }
                .buttonStyle(.bordered)
            }

            if let range = selectedRange {
                Text("将处理第 \(range.lowerBound) ~ \(range.upperBound) 个，共 \(range.count) 个素材")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("起止数字要在 1 ~ \(items.count) 之间，且「起」不能大于「止」")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func numberField(title: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("1", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 58)
                .padding(.vertical, 9)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))
        }
    }

    // MARK: - 顺序预览

    private var orderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("重排后的顺序").font(.headline)

            if let plan = plan, !plan.entries.isEmpty {
                Text((["分隔图"] + plan.entries.map { "\($0.number)·\($0.item.kind.short)" })
                    .joined(separator: " → "))
                    .font(.subheadline.monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)

                Text(newestFirst
                     ? "编号 1 的时间最新，相册从上往下读就是 1 → N"
                     : "编号 1 的时间最旧，相册最下方读起才是 1 → N")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("先填写有效的起止数字")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("编号 1 排在相册最上方（最新）", isOn: $newestFirst)
            Text("相册默认最新在前。开启时按 新 → 旧 写时间戳；如果发现顺序整体反了，关掉这个开关再跑一遍。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 底部按钮

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                guard let plan = plan else { return }
                Task { await runner.run(plan: plan) }
            } label: {
                Text("重新排列")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(plan == nil ? Color.gray.opacity(0.35) : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(plan == nil || runner.isRunning)
            .padding(16)
        }
        .background(.bar)
    }

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: runner.fraction)
                    .frame(width: 210)
                Text(runner.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("视频需要重编码，会比较慢，别锁屏")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - 载入

    @MainActor
    private func reload(_ picked: [PhotosPickerItem]) async {
        let ids = picked.compactMap { $0.itemIdentifier }
        guard !ids.isEmpty else {
            items = []
            startText = "1"
            endText = ""
            return
        }

        isLoadingThumbs = true
        var loaded = LibraryService.fetchItems(ids: ids)
        items = loaded
        startText = "1"
        endText = "\(loaded.count)"

        for index in loaded.indices {
            guard index < loaded.count else { break }
            if let thumb = await LibraryService.thumbnail(
                for: loaded[index].id,
                size: CGSize(width: 320, height: 320)
            ) {
                loaded[index].thumb = thumb
                items = loaded
            }
        }
        isLoadingThumbs = false
    }
}
