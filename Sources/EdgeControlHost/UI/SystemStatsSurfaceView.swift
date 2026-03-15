import EdgeControlShared
import SwiftUI

struct SystemStatsSurfaceView: View {
    let surface: DashboardSurface

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(surface.metrics) { metric in
                GaugeTile(metric: metric)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct GaugeTile: View {
    let metric: SurfaceMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Gauge(value: metric.value, in: 0...(metric.target ?? 100)) {
                EmptyView()
            } currentValueLabel: {
                Text(metric.displayValue)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(Gradient(colors: [
                Color(red: 0.38, green: 0.94, blue: 0.75),
                Color(red: 0.12, green: 0.60, blue: 0.91)
            ]))

            Text(metric.label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.64))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }
}
