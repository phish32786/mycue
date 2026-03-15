import EdgeControlShared
import SwiftUI

struct F1SurfaceView: View {
    let surface: DashboardSurface

    private var f1: F1Surface? { surface.f1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let f1 {
                switch f1.panelMode {
                case .overview:
                    overviewPanel(f1)
                case .control:
                    controlPanel(f1)
                case .tyres:
                    tyrePanel(f1)
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(f1?.sessionLabel.uppercased() ?? surface.title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)

            HStack(spacing: 8) {
                headerPill(f1?.sessionStatus.uppercased() ?? surface.subtitle.uppercased(), emphasis: true)
                headerPill(f1?.circuitLabel.uppercased() ?? "NO CIRCUIT")
                headerPill(f1?.sourceLabel.uppercased() ?? "OFFLINE")
            }
        }
    }

    private func overviewPanel(_ f1: F1Surface) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ORDER")

            VStack(spacing: 6) {
                ForEach(f1.topStandings.prefix(6)) { row in
                    standingRow(row, rightLabel: row.gapText, trailingDetail: row.statusText)
                }
            }

            if let latest = f1.raceControl.first {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("LATEST CONTROL")
                    controlCard(latest)
                }
            }
        }
    }

    private func controlPanel(_ f1: F1Surface) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("RACE CONTROL")

            if f1.raceControl.isEmpty {
                placeholder
            } else {
                VStack(spacing: 6) {
                    ForEach(f1.raceControl) { item in
                        controlCard(item)
                    }
                }
            }
        }
    }

    private func tyrePanel(_ f1: F1Surface) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("TYRE STATE")

            if f1.tyreRows.isEmpty {
                placeholder
            } else {
                VStack(spacing: 6) {
                    ForEach(f1.tyreRows.prefix(6)) { row in
                        standingRow(row, rightLabel: row.gapText, trailingDetail: row.statusText)
                    }
                }
            }
        }
    }

    private func standingRow(_ row: F1StandingRow, rightLabel: String, trailingDetail: String) -> some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", row.position))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.acronym)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(teamColor(row.teamColorHex))
                    Text(row.teamName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                }

                Text(trailingDetail.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(rightLabel.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func controlCard(_ item: F1RaceControlItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.category.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                if let lapText = item.lapText {
                    Text(lapText.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer(minLength: 0)
                Text(item.timeText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Text(item.message.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func headerPill(_ text: String, emphasis: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(emphasis ? 0.92 : 0.64))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.white.opacity(emphasis ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.52))
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NO DATA")
            Text(surface.detail?.uppercased() ?? "WAITING FOR SESSION DATA")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func teamColor(_ hex: String?) -> Color {
        guard let hex else { return .white }
        return Color(hex: hex) ?? .white
    }
}

private extension Color {
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
