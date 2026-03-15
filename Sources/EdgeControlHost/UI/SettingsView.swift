import EdgeControlShared
import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [
        GridItem(.flexible(minimum: 280), spacing: 18),
        GridItem(.flexible(minimum: 280), spacing: 18)
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    displayCard
                    behaviorCard
                    hardwareCard
                    diagnosticsCard
                    pagesCard
                    f1Card
                    weatherCard
                    webWidgetCard
                    mediaGalleryCard
                }

                pluginCard
            }
            .padding(24)
        }
        .background(windowBackground.ignoresSafeArea())
        .frame(width: 860, height: 760)
        .onAppear {
            model.refreshDisplays()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dashboard Settings")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Configure display behavior, hardware state, plugins, and debugging without leaving the control-surface workflow.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 520, alignment: .leading)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                statusPill(title: model.runtimeConnected ? "Runtime Connected" : "Runtime Offline", tint: model.runtimeConnected ? .mint : .orange)
                statusPill(title: model.isDevKitMode ? "DevKit Mode" : "Hardware Mode", tint: model.isDevKitMode ? .blue : .teal)
            }
        }
    }

    private var displayCard: some View {
        settingsCard("Display", subtitle: "Choose where the dashboard lives and how aggressively it occupies the screen.") {
            VStack(alignment: .leading, spacing: 14) {
                if model.isDevKitMode {
                    settingsFact(title: "Active mode", value: "Windowed DevKit")
                    Text("The XENEON display is not currently detected, so MyCue stays as a normal macOS window with standard controls.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target display")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        Picker("Target display", selection: Binding(
                            get: { model.settings.selectedDisplayID ?? "" },
                            set: { model.selectDisplay(id: $0) }
                        )) {
                            ForEach(model.availableDisplays) { display in
                                Text(display.summary).tag(display.id)
                            }
                        }
                        .labelsHidden()
                    }

                    settingsToggle(
                        title: "Kiosk presentation",
                        subtitle: "Hide desktop distractions and lock the dashboard to the hardware display.",
                        isOn: Binding(
                            get: { model.settings.kioskMode },
                            set: {
                                model.settings.kioskMode = $0
                                model.saveSettings()
                            }
                        )
                    )
                }

                settingsFact(title: "Detected displays", value: "\(model.availableDisplays.count)")
                Button("Refresh displays") {
                    model.refreshDisplays()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.16))
            }
        }
    }

    private var behaviorCard: some View {
        settingsCard("Behavior", subtitle: "Operational defaults for startup, appearance, and developer workflow.") {
            VStack(alignment: .leading, spacing: 12) {
                settingsToggle(
                    title: "Start in dashboard",
                    subtitle: "Open directly into the control surface on launch.",
                    isOn: Binding(
                        get: { model.settings.startInDashboard },
                        set: {
                            model.settings.startInDashboard = $0
                            model.saveSettings()
                        }
                    )
                )

                settingsToggle(
                    title: "Debug overlay",
                    subtitle: "Show runtime, touch, calibration, and render diagnostics on the dashboard.",
                    isOn: Binding(
                        get: { model.settings.debugMode },
                        set: {
                            model.settings.debugMode = $0
                            model.saveSettings()
                        }
                    )
                )

                settingsToggle(
                    title: "Enable DevKit services",
                    subtitle: "Keep developer-oriented plugin/runtime features available while iterating locally.",
                    isOn: Binding(
                        get: { model.settings.devKitEnabled },
                        set: {
                            model.settings.devKitEnabled = $0
                            model.saveSettings()
                        }
                    )
                )

                settingsToggle(
                    title: "Dark chrome preference",
                    subtitle: "Persist the dark window treatment used by the host shell.",
                    isOn: Binding(
                        get: { model.settings.darkChrome },
                        set: {
                            model.settings.darkChrome = $0
                            model.saveSettings()
                        }
                    )
                )

                settingsToggle(
                    title: "Launch at login",
                    subtitle: "Persist the preference now; login item registration can be wired to ServiceManagement next.",
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: {
                            model.settings.launchAtLogin = $0
                            model.saveSettings()
                        }
                    )
                )
            }
        }
    }

    private var hardwareCard: some View {
        settingsCard("Hardware", subtitle: "Live touch and calibration state from the active device path.") {
            VStack(alignment: .leading, spacing: 12) {
                settingsFact(title: "HID", value: model.touchState.hidStatus)
                settingsFact(title: "Calibration", value: model.touchState.calibrationStatus)
                settingsFact(title: "Validation", value: model.touchState.calibrationValidation)
                settingsFact(title: "Touch map", value: touchMapSummary)

                HStack(spacing: 10) {
                    Button("Retry hardware") {
                        model.retryHardwareDetection()
                    }
                    .buttonStyle(.bordered)

                    Button("Restart touch") {
                        model.restartTouchService()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isDevKitMode)

                    Button("Reset calibration") {
                        model.resetCalibration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isDevKitMode)
                }

                Text("Retry hardware rescans displays and hardware mode. Restart touch reopens the HID path. Reset calibration clears the saved corner map and restarts the hold-to-capture flow on the XENEON.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    private var diagnosticsCard: some View {
        settingsCard("Diagnostics", subtitle: "Runtime connection and plugin health at a glance.") {
            VStack(alignment: .leading, spacing: 12) {
                settingsFact(title: "Runtime", value: model.runtimeConnected ? "Connected" : "Offline")
                settingsFact(title: "Visible plugins", value: "\(model.plugins.count)")
                settingsFact(title: "Known plugins", value: "\(model.allPluginSnapshots.count)")

                HStack(spacing: 10) {
                    Button("Restart runtime") {
                        model.restartPluginRuntime()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Retry hardware") {
                        model.retryHardwareDetection()
                    }
                    .buttonStyle(.bordered)
                }

                if model.debugOverlay.pluginStatuses.isEmpty {
                    Text("No plugin snapshots have been received yet.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.debugOverlay.pluginStatuses, id: \.self) { status in
                            Text(status)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }
            }
        }
    }

    private var weatherCard: some View {
        settingsCard("Weather Plugin", subtitle: "Saved forecast location and unit preferences pushed directly into the plugin runtime.") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location name")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("Detroit", text: Binding(
                        get: { model.settings.weather.locationName },
                        set: { value in
                            model.updateWeatherSettings { $0.locationName = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latitude")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        TextField("42.3314", value: Binding(
                            get: { model.settings.weather.latitude },
                            set: { value in
                                model.updateWeatherSettings { $0.latitude = value }
                            }
                        ), format: .number.precision(.fractionLength(2...4)))
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Longitude")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        TextField("-83.0458", value: Binding(
                            get: { model.settings.weather.longitude },
                            set: { value in
                                model.updateWeatherSettings { $0.longitude = value }
                            }
                        ), format: .number.precision(.fractionLength(2...4)))
                        .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    Picker("Units", selection: Binding(
                        get: { model.settings.weather.unitPreference },
                        set: { value in
                            model.updateWeatherSettings { $0.unitPreference = value }
                        }
                    )) {
                        Text("Automatic").tag(WeatherUnitPreference.automatic)
                        Text("Imperial").tag(WeatherUnitPreference.imperial)
                        Text("Metric").tag(WeatherUnitPreference.metric)
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    Button("Use Detroit") {
                        model.updateWeatherSettings {
                            $0.locationName = "Detroit"
                            $0.latitude = 42.3314
                            $0.longitude = -83.0458
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("The weather tile updates against these coordinates immediately.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
    }

    private var f1Card: some View {
        settingsCard("F1 Plugin", subtitle: "Use completed OpenF1 race data for race control, order, and tyre state.") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("Race Control", text: Binding(
                        get: { model.settings.f1.title },
                        set: { value in
                            model.updateF1Settings { $0.title = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Subtitle")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("OpenF1 timing and incidents", text: Binding(
                        get: { model.settings.f1.subtitle },
                        set: { value in
                            model.updateF1Settings { $0.subtitle = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Season year")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        TextField("2026", value: Binding(
                            get: { model.settings.f1.seasonYear },
                            set: { value in
                                model.updateF1Settings { $0.seasonYear = value }
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Session")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        TextField("Race", text: Binding(
                            get: { model.settings.f1.sessionName },
                            set: { value in
                                model.updateF1Settings { $0.sessionName = value }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Event filter")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("Latest completed race or Monaco / Melbourne / Japan", text: Binding(
                        get: { model.settings.f1.eventFilter },
                        set: { value in
                            model.updateF1Settings { $0.eventFilter = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Race presets")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))

                    HStack {
                        f1PresetButton("Latest", filter: "")
                        f1PresetButton("Australia", filter: "Australia")
                        f1PresetButton("Japan", filter: "Japan")
                    }

                    HStack {
                        f1PresetButton("Monaco", filter: "Monaco")
                        f1PresetButton("Silverstone", filter: "Silverstone")
                        f1PresetButton("Monza", filter: "Monza")
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Session key override")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("11234", value: Binding(
                        get: { model.settings.f1.sessionKeyOverride },
                        set: { value in
                            model.updateF1Settings { $0.sessionKeyOverride = value }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("Use latest completed race") {
                        model.updateF1Settings {
                            $0.sessionName = "Race"
                            $0.eventFilter = ""
                            $0.sessionKeyOverride = nil
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Text("The F1 plugin uses completed OpenF1 race sessions for stability. Leave the event filter empty for the latest completed race, set it to Monaco or Japan for a different Grand Prix, or use a session key override to pin an exact event.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private var webWidgetCard: some View {
        settingsCard("Web Widget", subtitle: "Configure the native web surface for dashboards, docs, timers, and internal tools.") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("Web Widget", text: Binding(
                        get: { model.settings.webWidget.title },
                        set: { value in
                            model.updateWebWidgetSettings { $0.title = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Subtitle")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("Embedded dashboard", text: Binding(
                        get: { model.settings.webWidget.subtitle },
                        set: { value in
                            model.updateWebWidgetSettings { $0.subtitle = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("URL")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("https://calendar.google.com", text: Binding(
                        get: { model.settings.webWidget.urlString },
                        set: { value in
                            model.updateWebWidgetSettings { $0.urlString = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("Use Google Calendar") {
                        model.updateWebWidgetSettings {
                            $0.title = "Calendar"
                            $0.subtitle = "Upcoming schedule"
                            $0.urlString = "https://calendar.google.com"
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Use Notion") {
                        model.updateWebWidgetSettings {
                            $0.title = "Workspace"
                            $0.subtitle = "Notes and docs"
                            $0.urlString = "https://www.notion.so"
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Text("Some sites block embedding or interactive login flows. For those, use a site designed for embedded dashboards or internal tools.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private func f1PresetButton(_ title: String, filter: String) -> some View {
        Button(title) {
            model.updateF1Settings {
                $0.sessionName = "Race"
                $0.eventFilter = filter
                $0.sessionKeyOverride = nil
            }
        }
        .buttonStyle(.bordered)
    }

    private var mediaGalleryCard: some View {
        settingsCard("Media Gallery", subtitle: "Rotate local images in a native slideshow card for photos, moodboards, references, or brand assets.") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("Gallery", text: Binding(
                        get: { model.settings.mediaGallery.title },
                        set: { value in
                            model.updateMediaGallerySettings { $0.title = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Subtitle")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("Local media rotation", text: Binding(
                        get: { model.settings.mediaGallery.subtitle },
                        set: { value in
                            model.updateMediaGallerySettings { $0.subtitle = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Folder")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    TextField("/Users/you/Pictures/Dashboard", text: Binding(
                        get: { model.settings.mediaGallery.folderPath },
                        set: { value in
                            model.updateMediaGallerySettings { $0.folderPath = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("Choose folder") {
                        model.pickMediaGalleryFolder()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Interval")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        TextField("8", value: Binding(
                            get: { model.settings.mediaGallery.intervalSeconds },
                            set: { value in
                                model.updateMediaGallerySettings { $0.intervalSeconds = value }
                            }
                        ), format: .number.precision(.fractionLength(0...1)))
                        .textFieldStyle(.roundedBorder)
                    }

                    settingsToggle(
                        title: "Shuffle",
                        subtitle: "Randomize image order each time the folder list is read.",
                        isOn: Binding(
                            get: { model.settings.mediaGallery.shuffle },
                            set: { value in
                                model.updateMediaGallerySettings { $0.shuffle = value }
                            }
                        )
                    )
                }

                Text("Supported files: PNG, JPG, JPEG, HEIC, GIF, WEBP. For always-on use, a folder of still images is the lowest-friction path.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private var pagesCard: some View {
        settingsCard("Pages", subtitle: "Manage dashboard pages and switch the active page shown on the XENEON or in DevKit.") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Current pages")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))
                    Spacer()
                    Button(model.isLayoutEditMode ? "Exit editor" : "Open editor") {
                        model.isLayoutEditMode.toggle()
                        model.layoutDropTargetIndex = nil
                    }
                    .buttonStyle(.bordered)
                    Button("Add page") {
                        model.addDashboardPage()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.16))
                }

                if model.dashboardPages.isEmpty {
                    Text("No dashboard pages are configured yet.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                } else {
                    VStack(spacing: 10) {
                        ForEach(model.dashboardPages) { page in
                            pageRow(page)
                        }
                    }
                }
            }
        }
    }

    private var pluginCard: some View {
        settingsCard("Plugins", subtitle: "Enable, disable, and reorder surfaces without losing visibility into plugins that are currently turned off.") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Dashboard order")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))
                    Spacer()
                    Button("Reset order") {
                        model.resetPluginOrder()
                    }
                    .buttonStyle(.bordered)
                }

                if model.allPluginSnapshots.isEmpty {
                    Text("No plugin snapshots available yet.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(model.allPluginSnapshots.enumerated()), id: \.element.id) { index, plugin in
                            pluginRow(plugin: plugin, index: index)
                        }
                    }
                }
            }
        }
    }

    private func pluginRow(plugin: PluginSnapshot, index: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(plugin.manifest.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    statusPill(title: plugin.status.rawValue.uppercased(), tint: tint(for: plugin.status))
                }
                Text(plugin.surface.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
                Text("v\(plugin.manifest.version) • \(plugin.manifest.kind.rawValue) • \(model.pageTitle(for: plugin.id))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.46))

                if plugin.status == .failed || plugin.status == .degraded {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plugin.diagnostics.summary)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                        if let detail = plugin.diagnostics.lastError ?? plugin.surface.detail ?? plugin.diagnostics.detail {
                            Text(detail)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(3)
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    pagePicker(for: plugin)
                    spanPicker(for: plugin)

                    Toggle("", isOn: Binding(
                        get: { model.isPluginEnabled(plugin) },
                        set: { model.togglePlugin(plugin.id, enabled: $0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                HStack(spacing: 8) {
                    if plugin.status == .failed || plugin.status == .degraded {
                        Button("Restart runtime") {
                            model.restartPluginRuntime()
                        }
                        .buttonStyle(.bordered)
                    }

                    reorderButton(systemImage: "arrow.up") {
                        model.movePlugin(plugin.id, direction: .up)
                    }
                    .disabled(index == 0)

                    reorderButton(systemImage: "arrow.down") {
                        model.movePlugin(plugin.id, direction: .down)
                    }
                    .disabled(index == model.allPluginSnapshots.count - 1)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func pageRow(_ page: DashboardPageConfiguration) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                TextField(
                    "Page name",
                    text: Binding(
                        get: { page.title },
                        set: { model.renameDashboardPage(id: page.id, title: $0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("\(page.pluginIDs.count) plugin\(page.pluginIDs.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            if model.currentPageID == page.id {
                statusPill(title: "LIVE", tint: .teal)
            }

            HStack(spacing: 8) {
                reorderButton(systemImage: "arrow.left") {
                    model.movePage(page.id, direction: .up)
                }
                .disabled(model.dashboardPages.first?.id == page.id)

                reorderButton(systemImage: "arrow.right") {
                    model.movePage(page.id, direction: .down)
                }
                .disabled(model.dashboardPages.last?.id == page.id)
            }

            Button("Show") {
                model.selectPage(id: page.id)
            }
            .buttonStyle(.bordered)

            Button("Remove") {
                model.removeDashboardPage(id: page.id)
            }
            .buttonStyle(.bordered)
            .disabled(!model.canRemovePage(page.id))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func pagePicker(for plugin: PluginSnapshot) -> some View {
        Menu {
            ForEach(model.dashboardPages) { page in
                Button(page.title) {
                    model.movePlugin(plugin.id, toPageID: page.id)
                }
            }
        } label: {
            Label(model.pageTitle(for: plugin.id), systemImage: "rectangle.3.group")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .menuStyle(.button)
        .fixedSize()
    }

    private func spanPicker(for plugin: PluginSnapshot) -> some View {
        Menu {
            ForEach(DashboardCardSpan.allCases, id: \.self) { span in
                Button(span.title) {
                    model.updateCardSpan(plugin.id, span: span)
                }
            }
        } label: {
            Label(model.cardSpan(for: plugin.id).title, systemImage: "rectangle.split.3x1")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .menuStyle(.button)
        .fixedSize()
    }

    private func settingsCard<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func settingsFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private func reorderButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.28), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(tint.opacity(0.4), lineWidth: 1)
            )
    }

    private func tint(for status: PluginRuntimeStatus) -> Color {
        switch status {
        case .running:
            return .mint
        case .degraded, .starting:
            return .orange
        case .failed:
            return .red
        case .disabled:
            return .gray
        }
    }

    private var touchMapSummary: String {
        if let mapped = model.touchState.mappedPoint {
            return "raw \(model.touchState.rawSample.x),\(model.touchState.rawSample.y) -> \(Int(mapped.x)),\(Int(mapped.y))"
        }
        return "raw \(model.touchState.rawSample.x),\(model.touchState.rawSample.y) -> unmapped"
    }

    private var windowBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.09, blue: 0.12),
                Color(red: 0.08, green: 0.12, blue: 0.16),
                Color(red: 0.05, green: 0.07, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
