import SwiftUI

struct PeriodSegmentedControl: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Period.allCases) { period in
                let isActive = store.selectedPeriod == period

                Text(period.rawValue)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(
                        isActive
                        ? AnyShapeStyle(Color.white)
                        : AnyShapeStyle(.secondary)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .qmGlassPill(cornerRadius: 6, tinted: isActive)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await store.switchTo(period: period) }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(period.rawValue)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Theme.glassBorder, lineWidth: 0.5)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.black.opacity(0.18))
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}
