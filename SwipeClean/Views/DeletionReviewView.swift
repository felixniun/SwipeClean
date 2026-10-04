import SwiftUI

/// 待删除复核界面（计划书 8.2 / 11.4）。
/// 队列为空时不允许删除、不发空请求；最终删除按钮视觉上明显区别于导航操作。
struct DeletionReviewView: View {
    @ObservedObject var viewModel: DeletionReviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.count == 0 {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("待删除复核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回整理") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.count > 0 {
                        Button {
                            Task { await viewModel.confirmDeletion() }
                        } label: {
                            Text("确认删除 \(viewModel.count) 张")
                                .fontWeight(.semibold)
                        }
                        .tint(.red)
                        .disabled(viewModel.isCommitting)
                    }
                }
            }
            .overlay {
                if viewModel.isCommitting { committingOverlay }
                if case .needsReconciliation = viewModel.commitResult {
                    reconciliationBanner
                }
            }
            .onAppear { viewModel.refreshQueue(); viewModel.loadThumbnails() }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(viewModel.queuedAssetIDs, id: \.self) { assetID in
                    VStack(spacing: 4) {
                        if let image = viewModel.thumbnails[assetID] {
                            Image(uiImage: image)
                                .resizable().scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.2))
                                .frame(width: 110, height: 110)
                        }
                        Button("取消标记") { viewModel.removeOne(assetID) }
                            .font(.caption2)
                    }
                }
            }
            .padding(12)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "队列为空", systemImage: "checkmark.circle",
            description: Text("没有待删除的照片。返回继续整理。"))
    }

    private var committingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在提交删除…").font(.headline)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var reconciliationBanner: some View {
        VStack(spacing: 8) {
            Text("部分照片已不在照片库中，已从队列移除。请再次确认。")
                .font(.footnote).multilineTextAlignment(.center)
            Button("知道了") { viewModel.commitResult = .pending }
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 32)
    }
}
