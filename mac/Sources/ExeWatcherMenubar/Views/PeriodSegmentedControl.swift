import SwiftUI

struct PeriodSegmentedControl: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Period.allCases) { period in
                let isActive = store.selectedPeriod == period

                Text(period.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? AnyShapeStyle(Theme.brandPurpleDark) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isActive ? Theme.brandAccent : .clear)
                    )
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
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.secondary.opacity(0.08))
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}
