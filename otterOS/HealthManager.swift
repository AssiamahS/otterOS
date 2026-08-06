import Foundation
import HealthKit
import SwiftUI

@MainActor
final class HealthManager: ObservableObject {
    @Published var steps: Int = 0
    @Published var authorized = false
    private let store = HKHealthStore()

    func requestAndRefresh() {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        store.requestAuthorization(toShare: [], read: [stepType]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.authorized = granted
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, stats, _ in
            let count = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            Task { @MainActor in self?.steps = count }
        }
        store.execute(query)
    }
}

struct StepsRing: View {
    @EnvironmentObject var health: HealthManager
    let goal = 10_000

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1, Double(health.steps) / Double(goal)))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk")
                    .foregroundStyle(.orange)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(health.steps.formatted()) steps")
                    .font(.headline)
                Text(health.steps >= goal ? "10k crushed — Otto's proud" : "\((goal - health.steps).formatted()) to go for 10k")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .onAppear { health.requestAndRefresh() }
    }
}
