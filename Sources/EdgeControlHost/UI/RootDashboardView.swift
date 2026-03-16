import EdgeControlShared
import SwiftUI

public struct RootDashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var actionTargets: [ActionHitTarget] = []
    @State private var tileFrames: [String: CGRect] = [:]
    @State private var draggedPluginID: String?
    @State private var draggedTranslation: CGSize = .zero

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let layout = DashboardCardLayout(
                viewportSize: geometry.size,
                plugins: model.plugins,
                cardSpanProvider: { model.cardSpan(for: $0) },
                devKitMode: model.isDevKitMode,
                reservesHeaderSpace: model.isDevKitMode && model.settings.debugMode
            )

            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.03, blue: 0.04),
                        Color(red: 0.05, green: 0.05, blue: 0.06),
                        Color(red: 0.04, green: 0.04, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Group {
                    if model.isDevKitMode && model.settings.debugMode {
                        VStack(spacing: layout.headerSpacing) {
                            DashboardHeaderView()
                            cardScroller(layout: layout)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, layout.topPadding)
                    } else {
                        cardScroller(layout: layout)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.top, layout.topPadding)
                            .padding(.bottom, layout.bottomPadding)

                        DashboardHeaderView()
                            .padding(.top, 10)
                    }
                }
                .coordinateSpace(name: "dashboard-root")

                TouchInteractionOverlay(targets: actionTargets, tileFrames: tileFrames)
                    .allowsHitTesting(false)

                if model.isLayoutEditMode || (model.dashboardPages.count > 1 && model.dashboardControlsVisible) {
                    DashboardPageStripView()
                        .padding(.bottom, model.isDevKitMode ? 18 : 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }

                if model.settings.debugMode {
                    DebugOverlayView()
                        .padding(20)
                }
            }
            .contentShape(Rectangle())
            .gesture(pageSwipeGesture)
        }
        .background(WindowAccessor { window in
            WindowPlacement.configure(
                window,
                display: model.selectedDisplay,
                kioskMode: model.settings.kioskMode,
                devKitMode: model.isDevKitMode
            )
        })
        .onAppear {
            model.startIfNeeded()
        }
        .onPreferenceChange(ActionHitTargetPreferenceKey.self) { targets in
            actionTargets = targets
        }
        .onPreferenceChange(TileFramePreferenceKey.self) { entries in
            tileFrames = Dictionary(uniqueKeysWithValues: entries.map { ($0.pluginID, $0.frame) })
        }
    }

    @ViewBuilder
    private func cardScroller(layout: DashboardCardLayout) -> some View {
        Group {
            if layout.rowWidth > 0, layout.rowWidth <= layout.contentWidth {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    cardsRow(layout: layout)
                    Spacer(minLength: 0)
                }
            }
            else {
                ScrollView(.horizontal, showsIndicators: false) {
                    cardsContent(layout: layout)
                        .padding(.horizontal, layout.horizontalPadding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: model.isDevKitMode ? .topLeading : .center)
    }

    @ViewBuilder
    private func cardsContent(layout: DashboardCardLayout) -> some View {
        if model.plugins.isEmpty {
            EmptyDashboardStateView(
                runtimeConnected: model.runtimeConnected,
                isLayoutEditMode: model.isLayoutEditMode,
                currentPageTitle: model.dashboardPages.first(where: { $0.id == model.currentPageID })?.title,
                hasKnownPlugins: !model.allPluginSnapshots.isEmpty
            )
                .frame(
                    width: layout.emptyStateWidth,
                    height: layout.tileHeight,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, minHeight: layout.tileHeight, maxHeight: layout.tileHeight, alignment: .center)
        } else {
            cardsRow(layout: layout)
                .frame(minHeight: layout.tileHeight, maxHeight: layout.tileHeight, alignment: .center)
        }
    }

    private func cardsRow(layout: DashboardCardLayout) -> some View {
        HStack(spacing: layout.tileSpacing) {
            ForEach(Array(model.plugins.enumerated()), id: \.element.id) { index, plugin in
                PluginTileView(plugin: plugin)
                    .frame(width: layout.tileWidth(for: plugin.id), height: layout.tileHeight)
                    .offset(x: draggedPluginID == plugin.id ? draggedTranslation.width : 0)
                    .zIndex(draggedPluginID == plugin.id ? 20 : 0)
                    .overlay {
                        dropTargetOverlay(for: plugin.id)
                    }
                    .overlay(alignment: .trailing) {
                        if index < model.plugins.count - 1 {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.10),
                                            .white.opacity(0.03),
                                            .black.opacity(0.35)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 1)
                                .padding(.vertical, 10)
                                .offset(x: layout.tileSpacing / 2)
                        }
                    }
                    .reportTileFrame(pluginID: plugin.id)
                    .gesture(layoutDragGesture(for: plugin.id))
            }
        }
        .padding(6)
        .background(consolePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .inset(by: 1)
                .strokeBorder(.black.opacity(0.45), lineWidth: 1)
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: model.plugins.map(\.id))
        .animation(.spring(response: 0.18, dampingFraction: 0.90), value: model.layoutDropTargetIndex)
    }

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 36)
            .onEnded { value in
                guard !model.isLayoutEditMode else { return }
                guard model.dashboardPages.count > 1 else { return }
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 70 else { return }

                if value.translation.width < 0 {
                    model.selectAdjacentPage(offset: 1)
                } else {
                    model.selectAdjacentPage(offset: -1)
                }
            }
    }

    private func layoutDragGesture(for pluginID: String) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("dashboard-root"))
            .onChanged { value in
                guard model.isLayoutEditMode else { return }
                if draggedPluginID != pluginID {
                    draggedPluginID = pluginID
                }
                draggedTranslation = value.translation

                guard let frame = tileFrames[pluginID] else { return }
                let draggedMidX = frame.midX + value.translation.width
                let orderedFrames = model.plugins.compactMap { plugin -> (String, CGRect)? in
                    guard plugin.id != pluginID else { return nil }
                    guard let frame = tileFrames[plugin.id] else { return nil }
                    return (plugin.id, frame)
                }.sorted { $0.1.midX < $1.1.midX }

                let targetIndex = orderedFrames.reduce(0) { partial, element in
                    draggedMidX > element.1.midX ? partial + 1 : partial
                }

                let clampedIndex = max(0, min(targetIndex, max(model.plugins.count - 1, 0)))
                model.layoutDropTargetIndex = clampedIndex
                model.movePlugin(pluginID, toVisibleIndex: clampedIndex)
            }
            .onEnded { _ in
                draggedPluginID = nil
                draggedTranslation = .zero
                model.layoutDropTargetIndex = nil
            }
    }

    @ViewBuilder
    private func dropTargetOverlay(for pluginID: String) -> some View {
        if model.isLayoutEditMode,
           let index = model.layoutDropTargetIndex,
           model.plugins.indices.contains(index),
           model.plugins[index].id == pluginID {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.white.opacity(0.68), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(8)
        }
    }

    private var consolePanelBackground: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.04)
            LinearGradient(
                colors: [
                    .white.opacity(0.015),
                    .clear,
                    .black.opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .inset(by: 2)
                .strokeBorder(.white.opacity(0.03), lineWidth: 1)
        }
    }
}

private struct TileFrameEntry: Equatable {
    let pluginID: String
    let frame: CGRect
}

private struct TileFramePreferenceKey: PreferenceKey {
    static let defaultValue: [TileFrameEntry] = []

    static func reduce(value: inout [TileFrameEntry], nextValue: () -> [TileFrameEntry]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TileFrameReporter: ViewModifier {
    let pluginID: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: TileFramePreferenceKey.self,
                    value: [
                        TileFrameEntry(
                            pluginID: pluginID,
                            frame: geometry.frame(in: .named("dashboard-root"))
                        )
                    ]
                )
            }
        )
    }
}

private extension View {
    func reportTileFrame(pluginID: String) -> some View {
        modifier(TileFrameReporter(pluginID: pluginID))
    }
}

private struct DashboardPageStripView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if model.isLayoutEditMode {
                stripButton(title: "Add", systemImage: "plus", actionID: "addDashboardPage")
            }

            ForEach(model.dashboardPages) { page in
                Button {
                    model.selectPage(id: page.id)
                } label: {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(model.currentPageID == page.id ? .white.opacity(0.92) : .white.opacity(0.32))
                            .frame(width: model.currentPageID == page.id ? 14 : 10, height: 2)
                        Text(page.title)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(model.currentPageID == page.id ? 0.92 : 0.62))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(model.currentPageID == page.id ? .black.opacity(0.28) : .black.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(.white.opacity(model.currentPageID == page.id ? 0.18 : 0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .reportActionFrame(pluginID: "__host__", actionID: "selectPage:\(page.id)")
            }

            if model.isLayoutEditMode {
                stripButton(title: "Remove", systemImage: "trash", actionID: "removeCurrentPage")
                    .disabled(model.dashboardPages.count <= 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func stripButton(title: String, systemImage: String, actionID: String) -> some View {
        Button {
            model.perform(action: SurfaceAction(id: actionID, title: title, icon: systemImage), pluginID: "__host__")
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .reportActionFrame(pluginID: "__host__", actionID: actionID)
    }
}

private struct DashboardCardLayout {
    let viewportSize: CGSize
    let plugins: [PluginSnapshot]
    let cardSpanProvider: (String) -> DashboardCardSpan
    let devKitMode: Bool
    let reservesHeaderSpace: Bool

    var topPadding: CGFloat { devKitMode ? 18 : 8 }
    var horizontalPadding: CGFloat { devKitMode ? 20 : 20 }
    var bottomPadding: CGFloat { devKitMode ? 20 : 10 }
    var headerSpacing: CGFloat { reservesHeaderSpace ? 18 : 0 }
    var tileSpacing: CGFloat { 20 }
    var headerHeightEstimate: CGFloat { reservesHeaderSpace ? 98 : 0 }

    var contentWidth: CGFloat {
        max(viewportSize.width - (horizontalPadding * 2), 320)
    }

    var availableHeight: CGFloat {
        max(viewportSize.height - topPadding - bottomPadding - headerSpacing - headerHeightEstimate, 280)
    }

    var pluginCount: Int {
        plugins.count
    }

    var targetVisibleColumns: Int {
        let maxColumns = min(max(pluginCount, 1), 3)
        let minTileWidth = devKitMode ? CGFloat(240) : CGFloat(420)

        if maxColumns >= 3 {
            let required = (minTileWidth * 3) + (tileSpacing * 2)
            if contentWidth >= required {
                return 3
            }
        }

        if maxColumns >= 2 {
            let required = (minTileWidth * 2) + tileSpacing
            if contentWidth >= required {
                return 2
            }
        }

        return 1
    }

    var preferredTileAspectRatio: CGFloat {
        devKitMode ? 1.02 : 1.18
    }

    var widthPerVisibleColumn: CGFloat {
        let visibleColumns = max(targetVisibleColumns, 1)
        return (contentWidth - (CGFloat(visibleColumns - 1) * tileSpacing)) / CGFloat(visibleColumns)
    }

    var baseTileWidth: CGFloat {
        let minWidth = devKitMode ? CGFloat(220) : CGFloat(420)
        let widthFromHeight = tileHeight * preferredTileAspectRatio
        return max(min(widthPerVisibleColumn, widthFromHeight), minWidth)
    }

    var tileHeight: CGFloat {
        let minHeight = devKitMode ? CGFloat(220) : CGFloat(320)
        let heightFromWidth = widthPerVisibleColumn / preferredTileAspectRatio
        let maxHeight = devKitMode ? min(availableHeight, 760) : (viewportSize.height - topPadding - bottomPadding)
        return max(min(maxHeight, heightFromWidth), minHeight)
    }

    var rowWidth: CGFloat {
        guard pluginCount > 0 else { return 0 }
        return plugins.reduce(0) { partial, plugin in
            partial + tileWidth(for: plugin.id)
        } + (CGFloat(max(pluginCount - 1, 0)) * tileSpacing)
    }

    var emptyStateWidth: CGFloat {
        min(contentWidth, 860)
    }

    func tileWidth(for pluginID: String) -> CGFloat {
        let spanWeight = cardSpanProvider(pluginID).weight
        let rawWidth = baseTileWidth * spanWeight
        let maxWidth = devKitMode ? contentWidth * 0.72 : contentWidth * 0.58
        let minWidth = devKitMode ? CGFloat(200) : CGFloat(360)
        return min(max(rawWidth, minWidth), maxWidth)
    }
}

private struct EmptyDashboardStateView: View {
    let runtimeConnected: Bool
    let isLayoutEditMode: Bool
    let currentPageTitle: String?
    let hasKnownPlugins: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .frame(maxWidth: 720, alignment: .leading)
            Text(footnote)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(28)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var headline: String {
        if hasKnownPlugins {
            return "\(currentPageTitle ?? "This page") is empty"
        }
        return "No plugin surfaces available"
    }

    private var message: String {
        if hasKnownPlugins {
            if isLayoutEditMode {
                return "This page does not have any plugin cards assigned yet. Switch pages, move a plugin here from Settings, or add cards on another page first."
            }
            return "The selected page does not have any visible plugin cards. MyCue will normally fall back to a populated page outside layout editing."
        }

        if runtimeConnected {
            return "The plugin runtime is connected, but the dashboard has no visible plugin snapshots. This points to filtering or rendering state."
        }
        return "The plugin runtime is not connected yet. If this persists, the host-to-Node bridge needs inspection."
    }

    private var footnote: String {
        if hasKnownPlugins {
            return isLayoutEditMode ? "Use the page strip or Settings to place cards on this page." : "Open Settings or switch pages to continue."
        }
        return "Open Settings or enable debug mode for more detail."
    }
}
