import EdgeControlShared
import SwiftUI

struct WeatherSurfaceView: View {
    let surface: DashboardSurface
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headline

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(surface.metrics.dropFirst()) { metric in
                    metricCard(metric)
                }
            }

            forecastStrip(title: "Hourly", points: surface.hourlyForecast)
            forecastStrip(title: "Daily", points: surface.dailyForecast)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var headline: some View {
        HStack(alignment: .top, spacing: 12) {
            if let headline = surface.metrics.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(headline.displayValue)
                            .font(.system(size: 38, weight: .light, design: .monospaced))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(headline.label)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.72))
                                .textCase(.uppercase)
                            Text(surface.subtitle)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.56))
                                .textCase(.uppercase)
                        }
                    }

                    if let detail = surface.detail {
                        Text(detail)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(2)
                            .textCase(.uppercase)
                    }
                }
            }

            Spacer(minLength: 0)

            if let headline = surface.metrics.first {
                VStack(alignment: .center, spacing: 3) {
                    Text(iconPart(from: headline.displayValue))
                        .font(.system(size: 30))
                    Text(textPart(from: headline.displayValue))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .textCase(.uppercase)
                }
                .frame(width: 76, height: 74)
                .background(
                    .white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 2, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 2, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func forecastStrip(title: String, points: [WeatherPoint]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.64))
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.label)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                            .textCase(.uppercase)
                        Text(point.icon)
                            .font(.system(size: 16))
                        Text(point.temperature)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Text(point.detail)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        .white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 2, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func metricCard(_ metric: SurfaceMetric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.56))
                .textCase(.uppercase)
            Text(metric.displayValue)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            .white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 2, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func iconPart(from displayValue: String) -> String {
        let parts = displayValue.split(separator: " ", maxSplits: 1)
        return parts.first.map(String.init) ?? ""
    }

    private func textPart(from displayValue: String) -> String {
        let parts = displayValue.split(separator: " ", maxSplits: 1)
        if parts.count > 1 {
            return String(parts[1])
        }
        return displayValue
    }
}
