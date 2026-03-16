import EdgeControlShared
import SwiftUI

struct ActionHitTarget: Equatable, Identifiable {
    let pluginID: String
    let actionID: String
    let frame: CGRect

    var id: String { "\(pluginID):\(actionID)" }
}

struct ActionHitTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [ActionHitTarget] = []

    static func reduce(value: inout [ActionHitTarget], nextValue: () -> [ActionHitTarget]) {
        value.append(contentsOf: nextValue())
    }
}

struct ActionHitTargetReporter: ViewModifier {
    let pluginID: String
    let actionID: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ActionHitTargetPreferenceKey.self,
                    value: [
                        ActionHitTarget(
                            pluginID: pluginID,
                            actionID: actionID,
                            frame: geometry.frame(in: .named("dashboard-root"))
                        )
                    ]
                )
            }
        )
    }
}

extension View {
    func reportActionFrame(pluginID: String, actionID: String) -> some View {
        modifier(ActionHitTargetReporter(pluginID: pluginID, actionID: actionID))
    }
}

struct TouchInteractionOverlay: View {
    @EnvironmentObject private var model: AppModel
    let targets: [ActionHitTarget]
    let tileFrames: [String: CGRect]

    @State private var lastTriggeredPressSequence = -1
    @State private var activeDragPluginID: String?
    @State private var lastDragTargetIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onAppear {
                        model.updateTouchBounds(CGRect(origin: .zero, size: geometry.size))
                    }
                    .onChange(of: geometry.size) { _, size in
                        model.updateTouchBounds(CGRect(origin: .zero, size: size))
                    }
                    .onChange(of: model.touchState.pressSequence) { _, sequence in
                        guard !model.isDevKitMode else { return }
                        guard model.touchState.isPressed,
                              model.touchState.isCalibrated,
                              sequence != lastTriggeredPressSequence,
                              let point = model.touchState.mappedPoint else {
                            return
                        }

                        if let target = preferredTarget(at: point) {
                            lastTriggeredPressSequence = sequence
                            model.perform(
                                action: SurfaceAction(id: target.actionID, title: target.actionID, icon: ""),
                                pluginID: target.pluginID
                            )
                        }
                    }
                    .onChange(of: model.touchState.sequence) { _, _ in
                        guard !model.isDevKitMode else { return }
                        guard model.isLayoutEditMode else {
                            activeDragPluginID = nil
                            lastDragTargetIndex = nil
                            model.layoutDropTargetIndex = nil
                            return
                        }
                        handleLayoutDragSample()
                    }

                if model.settings.debugMode, let point = model.touchState.mappedPoint {
                    Circle()
                        .fill(model.touchState.isPressed ? Color(red: 0.40, green: 0.95, blue: 0.71) : Color(red: 0.97, green: 0.53, blue: 0.45))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                        .position(point)
                        .opacity(0.92)
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func handleLayoutDragSample() {
        guard model.touchState.isCalibrated,
              let point = model.touchState.mappedPoint else {
            activeDragPluginID = nil
            lastDragTargetIndex = nil
            model.layoutDropTargetIndex = nil
            return
        }

        if !model.touchState.isPressed {
            activeDragPluginID = nil
            lastDragTargetIndex = nil
            model.layoutDropTargetIndex = nil
            return
        }

        if activeDragPluginID == nil {
            activeDragPluginID = orderedTileFrames.first(where: { $0.1.contains(point) })?.0
            lastDragTargetIndex = nil
        }

        guard let activeDragPluginID else { return }

        let orderedFrames = orderedTileFrames(excluding: activeDragPluginID)
        let targetIndex = orderedFrames.reduce(0) { partial, element in
            point.x > element.1.midX ? partial + 1 : partial
        }
        let clampedIndex = max(0, min(targetIndex, max(model.plugins.count - 1, 0)))

        guard lastDragTargetIndex != clampedIndex else { return }
        lastDragTargetIndex = clampedIndex
        model.layoutDropTargetIndex = clampedIndex
        model.movePlugin(activeDragPluginID, toVisibleIndex: clampedIndex)
    }

    private var orderedTileFrames: [(String, CGRect)] {
        orderedTileFrames(excluding: nil)
    }

    private func orderedTileFrames(excluding pluginID: String?) -> [(String, CGRect)] {
        model.plugins.compactMap { plugin in
            guard plugin.id != pluginID else { return nil }
            guard let frame = tileFrames[plugin.id] else { return nil }
            return (plugin.id, frame)
        }
        .sorted { $0.1.midX < $1.1.midX }
    }

    private func preferredTarget(at point: CGPoint) -> ActionHitTarget? {
        let matches = targets.filter { $0.frame.insetBy(dx: -18, dy: -18).contains(point) }
        guard !matches.isEmpty else { return nil }

        let filtered: [ActionHitTarget]
        if model.dashboardControlsVisible || model.isLayoutEditMode {
            let nonReveal = matches.filter { $0.actionID != "revealSettings" }
            let visibleMatches = nonReveal.isEmpty ? matches : nonReveal
            let hostMatches = visibleMatches.filter { $0.pluginID == "__host__" }
            filtered = hostMatches.isEmpty ? visibleMatches : hostMatches
        } else {
            filtered = matches
        }

        return filtered.min { lhs, rhs in
            let lhsArea = lhs.frame.width * lhs.frame.height
            let rhsArea = rhs.frame.width * rhs.frame.height
            if abs(lhsArea - rhsArea) > 0.5 {
                return lhsArea < rhsArea
            }
            return lhs.id < rhs.id
        }
    }
}
