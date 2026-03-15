import AppKit
import Combine
import EdgeControlShared
import Foundation
import SwiftUI

@MainActor
public final class AppModel: ObservableObject {
    @Published public var settings: AppSettings
    @Published public var availableDisplays: [DisplayDescriptor] = []
    @Published public var selectedDisplay: DisplayDescriptor?
    @Published public var plugins: [PluginSnapshot] = []
    @Published public var allPluginSnapshots: [PluginSnapshot] = []
    @Published public var runtimeConnected = false
    @Published public var showingSettings = false
    @Published public var isDevKitMode = false
    @Published public var touchState = TouchRuntimeState()
    @Published public var dashboardControlsVisible = false
    @Published public var currentPageID: String?
    @Published public var isLayoutEditMode = false
    @Published public var layoutDropTargetIndex: Int?

    public let debugOverlay = DebugOverlayModel()

    private let settingsStore: SettingsStore
    private let displayManager: DisplayManager
    private let pluginHost: PluginHostController
    private let hardwareTouchService: HardwareTouchService
    private let settingsWindowController: SettingsWindowController
    private let systemMetricsService: SystemMetricsService
    private var hasStarted = false
    private var cancellables: Set<AnyCancellable> = []
    private var dashboardControlsHideWorkItem: DispatchWorkItem?

    public init(
        settingsStore: SettingsStore = SettingsStore(),
        displayManager: DisplayManager = DisplayManager(),
        pluginHost: PluginHostController = PluginHostController(),
        hardwareTouchService: HardwareTouchService = HardwareTouchService(),
        settingsWindowController: SettingsWindowController = SettingsWindowController(),
        systemMetricsService: SystemMetricsService = SystemMetricsService()
    ) {
        self.settingsStore = settingsStore
        self.displayManager = displayManager
        self.pluginHost = pluginHost
        self.hardwareTouchService = hardwareTouchService
        self.settingsWindowController = settingsWindowController
        self.systemMetricsService = systemMetricsService
        self.settings = settingsStore.load()

        hardwareTouchService.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.touchState = state
                self.debugOverlay.touchStatus = state.calibrationStatus
                self.debugOverlay.hidStatus = state.hidStatus
                if let point = state.mappedPoint {
                    self.debugOverlay.touchPointDescription = "raw \(state.rawSample.x),\(state.rawSample.y) -> \(Int(point.x)),\(Int(point.y))"
                } else {
                    self.debugOverlay.touchPointDescription = "raw \(state.rawSample.x),\(state.rawSample.y) -> unmapped"
                }
                self.debugOverlay.calibrationValidation = state.calibrationValidation
            }
            .store(in: &cancellables)

        systemMetricsService.$latestMetrics
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                guard let self, let metrics else { return }
                self.pluginHost.updateHostMetrics(metrics)
            }
            .store(in: &cancellables)
    }

    public func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshDisplays()
        systemMetricsService.start()
        startPluginRuntime()
    }

    public func stop() {
        pluginHost.stop()
        hardwareTouchService.stop()
        systemMetricsService.stop()
    }

    public func refreshDisplays() {
        availableDisplays = displayManager.availableDisplays()
        let hardwareScreen = displayManager.hardwareTargetScreen()
        isDevKitMode = hardwareScreen == nil

        let selectedScreen = isDevKitMode
            ? displayManager.preferredWindowedScreen()
            : displayManager.selectedScreen(for: settings)

        let selectedID = selectedScreen?.displayIdentifier
        selectedDisplay = availableDisplays.first(where: { $0.id == selectedID })
        debugOverlay.selectedDisplayName = selectedDisplay?.summary ?? "Unknown"
        if isDevKitMode {
            settings.kioskMode = false
        }

        if settings.selectedDisplayID == nil, !isDevKitMode {
            settings.selectedDisplayID = selectedDisplay?.id
            saveSettings()
        }

        startHardwareIfNeeded()
    }

    public func updateTouchBounds(_ bounds: CGRect) {
        guard !isDevKitMode else { return }
        hardwareTouchService.updateRenderBounds(bounds)
    }

    public func syncTouchState() {
        guard !isDevKitMode else {
            touchState = TouchRuntimeState(
                hidStatus: "devkit",
                calibrationStatus: "DevKit mode",
                calibrationValidation: "No hardware required",
                isCalibrated: true
            )
            debugOverlay.touchStatus = touchState.calibrationStatus
            debugOverlay.hidStatus = touchState.hidStatus
            return
        }
    }

    public func perform(action: SurfaceAction, pluginID: String) {
        if action.id.hasPrefix("layout.") {
            switch action.id {
            case "layout.moveLeft":
                movePlugin(pluginID, direction: .up)
                return
            case "layout.moveRight":
                movePlugin(pluginID, direction: .down)
                return
            case "layout.cycleSpan":
                cycleCardSpan(pluginID)
                return
            default:
                break
            }
        }

        if pluginID == "__host__" {
            switch action.id {
            case "openSettings":
                hideDashboardControls()
                openSettingsWindow()
                return
            case "revealSettings":
                revealDashboardControlsTemporarily()
                return
            case "toggleLayoutEditMode":
                setLayoutEditMode(!isLayoutEditMode)
                return
            case "addDashboardPage":
                addDashboardPage()
                return
            case "removeCurrentPage":
                if let currentPageID {
                    removeDashboardPage(id: currentPageID)
                }
                return
            case let id where id.hasPrefix("selectPage:"):
                selectPage(id: String(id.dropFirst("selectPage:".count)))
                return
            default:
                break
            }
        }
        pluginHost.perform(.init(pluginID: pluginID, actionID: action.id))
    }

    public func revealDashboardControlsTemporarily() {
        dashboardControlsVisible = true
        guard !isLayoutEditMode else { return }

        dashboardControlsHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isLayoutEditMode else { return }
            self.dashboardControlsVisible = false
        }
        dashboardControlsHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    public func hideDashboardControls() {
        dashboardControlsHideWorkItem?.cancel()
        dashboardControlsVisible = false
    }

    public func setLayoutEditMode(_ isEditing: Bool) {
        layoutDropTargetIndex = nil
        isLayoutEditMode = isEditing
        if isEditing {
            dashboardControlsHideWorkItem?.cancel()
            dashboardControlsVisible = true
        } else {
            hideDashboardControls()
        }
    }

    public func selectDisplay(id: String) {
        settings.selectedDisplayID = id
        saveSettings()
        refreshDisplays()
    }

    public func togglePlugin(_ pluginID: String, enabled: Bool) {
        if enabled {
            settings.disabledPluginIDs.remove(pluginID)
        } else {
            settings.disabledPluginIDs.insert(pluginID)
        }
        saveSettings()
        plugins = visiblePlugins(from: allPluginSnapshots)
        debugOverlay.pluginCount = plugins.count
        debugOverlay.pluginStatuses = plugins.map { "\($0.manifest.name): \($0.status.rawValue)" }
    }

    public func isPluginEnabled(_ snapshot: PluginSnapshot) -> Bool {
        !settings.disabledPluginIDs.contains(snapshot.id)
    }

    public var dashboardPages: [DashboardPageConfiguration] {
        settings.dashboardPages
    }

    public func selectPage(id: String) {
        guard settings.dashboardPages.contains(where: { $0.id == id }) else { return }
        currentPageID = id
        settings.selectedPageID = id
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func movePlugin(_ pluginID: String, direction: MoveDirection) {
        guard var page = page(containing: pluginID),
              let pageIndex = settings.dashboardPages.firstIndex(where: { $0.id == page.id }),
              let index = page.items.firstIndex(where: { $0.pluginID == pluginID }) else { return }

        let targetIndex: Int
        switch direction {
        case .up:
            guard index > 0 else { return }
            targetIndex = index - 1
        case .down:
            guard index < page.items.count - 1 else { return }
            targetIndex = index + 1
        }

        page.items.swapAt(index, targetIndex)
        settings.dashboardPages[pageIndex] = page
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func movePlugin(_ pluginID: String, toVisibleIndex targetVisibleIndex: Int) {
        guard var page = page(containing: pluginID),
              let pageIndex = settings.dashboardPages.firstIndex(where: { $0.id == page.id }),
              let draggedItemIndex = page.items.firstIndex(where: { $0.pluginID == pluginID }) else { return }

        let draggedItem = page.items.remove(at: draggedItemIndex)
        let remainingVisibleIDs = page.items.map(\.pluginID).filter { !settings.disabledPluginIDs.contains($0) }
        let clampedIndex = max(0, min(targetVisibleIndex, remainingVisibleIDs.count))

        let insertionIndex: Int
        if clampedIndex >= remainingVisibleIDs.count {
            insertionIndex = page.items.endIndex
        } else if let anchorIndex = page.items.firstIndex(where: { $0.pluginID == remainingVisibleIDs[clampedIndex] }) {
            insertionIndex = anchorIndex
        } else {
            insertionIndex = page.items.endIndex
        }

        page.items.insert(draggedItem, at: insertionIndex)
        settings.dashboardPages[pageIndex] = page
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func addDashboardPage() {
        let title = nextDashboardPageTitle()
        var page = DashboardPageConfiguration(title: title, items: [])

        if let seed = seededItemForNewPage() {
            page.items = [seed.item]
            settings.dashboardPages[seed.pageIndex].items.remove(at: seed.itemIndex)
        }

        settings.dashboardPages.append(page)
        currentPageID = page.id
        settings.selectedPageID = page.id
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func renameDashboardPage(id: String, title: String) {
        guard let index = settings.dashboardPages.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.dashboardPages[index].title = trimmed.isEmpty ? settings.dashboardPages[index].title : trimmed
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func removeDashboardPage(id: String) {
        guard settings.dashboardPages.count > 1,
              let index = settings.dashboardPages.firstIndex(where: { $0.id == id }) else { return }

        let removedPlugins = settings.dashboardPages[index].pluginIDs
        settings.dashboardPages.remove(at: index)
        let fallbackIndex = min(index, settings.dashboardPages.count - 1)
        guard settings.dashboardPages.indices.contains(fallbackIndex) else { return }

        settings.dashboardPages[fallbackIndex].pluginIDs.append(contentsOf: removedPlugins)
        settings.dashboardPages = normalizedPages(settings.dashboardPages, runtimeIDs: allPluginSnapshots.map(\.id))
        currentPageID = settings.dashboardPages[fallbackIndex].id
        settings.selectedPageID = currentPageID
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func movePage(_ pageID: String, direction: MoveDirection) {
        guard let index = settings.dashboardPages.firstIndex(where: { $0.id == pageID }) else { return }

        let targetIndex: Int
        switch direction {
        case .up:
            guard index > 0 else { return }
            targetIndex = index - 1
        case .down:
            guard index < settings.dashboardPages.count - 1 else { return }
            targetIndex = index + 1
        }

        settings.dashboardPages.swapAt(index, targetIndex)
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func resetPluginOrder() {
        settings.dashboardPages = defaultPages(for: allPluginSnapshots.map(\.id))
        currentPageID = settings.dashboardPages.first?.id
        settings.selectedPageID = currentPageID
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func updateWeatherSettings(_ update: (inout WeatherPluginSettings) -> Void) {
        update(&settings.weather)
        saveSettings()
    }

    public func updateWebWidgetSettings(_ update: (inout WebWidgetSettings) -> Void) {
        update(&settings.webWidget)
        saveSettings()
    }

    public func updateMediaGallerySettings(_ update: (inout MediaGallerySettings) -> Void) {
        update(&settings.mediaGallery)
        saveSettings()
    }

    public func pickMediaGalleryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        if panel.runModal() == .OK, let url = panel.url {
            updateMediaGallerySettings { $0.folderPath = url.path }
        }
    }

    public func saveSettings() {
        settingsStore.save(settings)
        pluginHost.updateSettings(settings)
    }

    public func resetCalibration() {
        hardwareTouchService.resetCalibration()
        syncTouchState()
    }

    public func retryHardwareDetection() {
        refreshDisplays()
    }

    public func restartTouchService() {
        guard !isDevKitMode else {
            syncTouchState()
            return
        }
        hardwareTouchService.start()
        syncTouchState()
    }

    public func restartPluginRuntime() {
        pluginHost.stop()
        runtimeConnected = false
        debugOverlay.runtimeConnected = false
        startPluginRuntime()
    }

    public func openSettingsWindow() {
        settingsWindowController.show(model: self)
    }

    public func pageTitle(for pluginID: String) -> String {
        page(containing: pluginID)?.title ?? "Unassigned"
    }

    public func cardSpan(for pluginID: String) -> DashboardCardSpan {
        page(containing: pluginID)?.items.first(where: { $0.pluginID == pluginID })?.span ?? .standard
    }

    public func canRemovePage(_ pageID: String) -> Bool {
        settings.dashboardPages.count > 1 && settings.dashboardPages.contains(where: { $0.id == pageID })
    }

    public func movePlugin(_ pluginID: String, toPageID pageID: String) {
        guard let targetIndex = settings.dashboardPages.firstIndex(where: { $0.id == pageID }) else { return }
        let span = cardSpan(for: pluginID)

        for index in settings.dashboardPages.indices {
            settings.dashboardPages[index].items.removeAll { $0.pluginID == pluginID }
        }
        settings.dashboardPages[targetIndex].items.append(.init(pluginID: pluginID, span: span))
        settings.dashboardPages = normalizedPages(settings.dashboardPages, runtimeIDs: allPluginSnapshots.map(\.id))
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func updateCardSpan(_ pluginID: String, span: DashboardCardSpan) {
        guard let pageIndex = settings.dashboardPages.firstIndex(where: { page in
            page.items.contains(where: { $0.pluginID == pluginID })
        }),
        let itemIndex = settings.dashboardPages[pageIndex].items.firstIndex(where: { $0.pluginID == pluginID }) else { return }

        settings.dashboardPages[pageIndex].items[itemIndex].span = span
        saveSettings()
        apply(snapshots: allPluginSnapshots)
    }

    public func cycleCardSpan(_ pluginID: String) {
        let nextSpan: DashboardCardSpan
        switch cardSpan(for: pluginID) {
        case .compact:
            nextSpan = .standard
        case .standard:
            nextSpan = .feature
        case .feature:
            nextSpan = .compact
        }
        updateCardSpan(pluginID, span: nextSpan)
    }

    public func selectAdjacentPage(offset: Int) {
        guard settings.dashboardPages.count > 1,
              let currentPageID = resolvedCurrentPageID(),
              let index = settings.dashboardPages.firstIndex(where: { $0.id == currentPageID }) else { return }

        let targetIndex = index + offset
        guard settings.dashboardPages.indices.contains(targetIndex) else { return }
        selectPage(id: settings.dashboardPages[targetIndex].id)
    }

    private func startHardwareIfNeeded() {
        if isDevKitMode {
            hardwareTouchService.stop()
            syncTouchState()
            return
        }

        hardwareTouchService.start()
        syncTouchState()
    }

    private func startPluginRuntime() {
        pluginHost.start(
            settings: settings,
            initialHostMetrics: systemMetricsService.currentMetrics(),
            callbacks: runtimeCallbacks()
        )
    }

    private func runtimeCallbacks() -> PluginHostController.Callbacks {
        .init(
            onConnected: { [weak self] connected in
                guard let self else { return }
                self.runtimeConnected = connected
                self.debugOverlay.runtimeConnected = connected
            },
            onSnapshots: { [weak self] snapshots in
                self?.apply(snapshots: snapshots)
            },
            onLog: { [weak self] log in
                self?.debugOverlay.push(log: log)
            }
        )
    }

    private func apply(snapshots: [PluginSnapshot]) {
        let runtimeIDs = snapshots.map(\.id)
        settings.dashboardPages = normalizedPages(settings.dashboardPages.isEmpty ? defaultPages(for: runtimeIDs) : settings.dashboardPages, runtimeIDs: runtimeIDs)
        currentPageID = resolvedCurrentPageID()
        let visibleSnapshotIDs = Set(visiblePlugins(from: snapshots).map(\.id))
        if !isLayoutEditMode,
           let selectedPageID = currentPageID,
           let selectedPage = settings.dashboardPages.first(where: { $0.id == selectedPageID }),
           selectedPage.pluginIDs.allSatisfy({ !visibleSnapshotIDs.contains($0) }),
           let fallbackPage = settings.dashboardPages.first(where: { page in
               page.pluginIDs.contains(where: { visibleSnapshotIDs.contains($0) })
           }) {
            currentPageID = fallbackPage.id
        }
        settings.selectedPageID = currentPageID

        let currentPluginIDs = settings.dashboardPages.first(where: { $0.id == currentPageID })?.pluginIDs ?? runtimeIDs
        let ordered = snapshots.sorted { lhs, rhs in
            let left = currentPluginIDs.firstIndex(of: lhs.id) ?? Int.max
            let right = currentPluginIDs.firstIndex(of: rhs.id) ?? Int.max
            if left == right {
                return lhs.manifest.name < rhs.manifest.name
            }
            return left < right
        }

        allPluginSnapshots = snapshots.sorted { lhs, rhs in
            let left = allPluginSortIndex(for: lhs.id)
            let right = allPluginSortIndex(for: rhs.id)
            if left == right {
                return lhs.manifest.name < rhs.manifest.name
            }
            return left < right
        }

        plugins = visiblePlugins(from: ordered).filter { currentPluginIDs.contains($0.id) }
        debugOverlay.pluginCount = plugins.count
        debugOverlay.pluginStatuses = plugins.map { "\($0.manifest.name): \($0.status.rawValue)" }
    }

    private func visiblePlugins(from snapshots: [PluginSnapshot]) -> [PluginSnapshot] {
        snapshots.filter(isPluginEnabled)
    }

    private func resolvedCurrentPageID() -> String? {
        if let currentPageID, settings.dashboardPages.contains(where: { $0.id == currentPageID }) {
            return currentPageID
        }
        if let selectedPageID = settings.selectedPageID, settings.dashboardPages.contains(where: { $0.id == selectedPageID }) {
            return selectedPageID
        }
        return settings.dashboardPages.first?.id
    }

    private func normalizedPages(_ pages: [DashboardPageConfiguration], runtimeIDs: [String]) -> [DashboardPageConfiguration] {
        guard !runtimeIDs.isEmpty else { return pages }

        var cleaned = pages.map { page in
            var page = page
            page.items = page.items.filter { runtimeIDs.contains($0.pluginID) }
            return page
        }.filter { !$0.items.isEmpty || $0.title == "Dashboard" || $0.title == "Launch" }

        if cleaned.isEmpty {
            cleaned = defaultPages(for: runtimeIDs)
        }

        var assigned = Set(cleaned.flatMap(\.pluginIDs))
        for pluginID in runtimeIDs where !assigned.contains(pluginID) {
            let targetIndex = cleaned.firstIndex(where: { $0.title != "Launch" }) ?? 0
            cleaned[targetIndex].items.append(.init(pluginID: pluginID))
            assigned.insert(pluginID)
        }

        return cleaned
    }

    private func defaultPages(for runtimeIDs: [String]) -> [DashboardPageConfiguration] {
        let orderedIDs = runtimeIDs.sorted { lhs, rhs in
            let left = settings.pluginOrder.firstIndex(of: lhs) ?? Int.max
            let right = settings.pluginOrder.firstIndex(of: rhs) ?? Int.max
            if left == right { return lhs < rhs }
            return left < right
        }
        let launcherIDs = orderedIDs.filter { $0 == "launcher" }
        let primaryIDs = orderedIDs.filter { $0 != "launcher" }

        var pages = [DashboardPageConfiguration(title: "Dashboard", pluginIDs: primaryIDs)]
        if !launcherIDs.isEmpty {
            pages.append(DashboardPageConfiguration(title: "Launch", pluginIDs: launcherIDs))
        }
        return pages
    }

    private func nextDashboardPageTitle() -> String {
        let existingTitles = Set(settings.dashboardPages.map(\.title))
        if !existingTitles.contains("Page 2") {
            return "Page 2"
        }

        for index in 3...12 {
            let title = "Page \(index)"
            if !existingTitles.contains(title) {
                return title
            }
        }

        return "Page \(settings.dashboardPages.count + 1)"
    }

    private func seededItemForNewPage() -> (pageIndex: Int, itemIndex: Int, item: DashboardPageItem)? {
        if let currentPageID,
           let pageIndex = settings.dashboardPages.firstIndex(where: { $0.id == currentPageID }),
           settings.dashboardPages[pageIndex].items.count > 1 {
            let itemIndex = settings.dashboardPages[pageIndex].items.count - 1
            return (pageIndex, itemIndex, settings.dashboardPages[pageIndex].items[itemIndex])
        }

        if let pageIndex = settings.dashboardPages.firstIndex(where: { $0.items.count > 1 }) {
            let itemIndex = settings.dashboardPages[pageIndex].items.count - 1
            return (pageIndex, itemIndex, settings.dashboardPages[pageIndex].items[itemIndex])
        }

        return nil
    }

    private func page(containing pluginID: String) -> DashboardPageConfiguration? {
        settings.dashboardPages.first(where: { $0.items.contains(where: { $0.pluginID == pluginID }) })
    }

    private func allPluginSortIndex(for pluginID: String) -> Int {
        settings.dashboardPages.enumerated().reduce(Int.max) { partial, element in
            let (pageOffset, page) = element
            guard let pluginOffset = page.pluginIDs.firstIndex(of: pluginID) else { return partial }
            return min(partial, (pageOffset * 1000) + pluginOffset)
        }
    }
}

public extension AppModel {
    enum MoveDirection {
        case up
        case down
    }
}
