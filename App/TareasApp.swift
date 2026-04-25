import SwiftUI
import WidgetKit

@main
struct TareasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    if TareasStore.load().isEmpty {
                        seedExample()
                    }
                    await NotificationManager.requestAuthorizationIfNeeded()
                    NotificationManager.rescheduleAll()
                    await CloudSyncManager.shared.start()
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }

    private func seedExample() {
        let now = Date()
        let samples: [TareaItem] = [
            .init(name: "Regar planta", icon: "🌱", frequency: .everyDays(7),
                  lastCompletedAt: now.addingTimeInterval(-2 * 86_400),
                  category: "Casa"),
            .init(name: "Limpiar arenero", icon: "🐱", frequency: .weeklyOn(weekday: 7),
                  lastCompletedAt: now.addingTimeInterval(-2 * 86_400),
                  category: "Casa"),
            .init(name: "Tomar vitamina", icon: "💊", frequency: .everyHours(8),
                  lastCompletedAt: now.addingTimeInterval(-6 * 3_600),
                  category: "Personal"),
            .init(name: "Pagar renta", icon: "📚", frequency: .monthlyOn(day: 1),
                  lastCompletedAt: now.addingTimeInterval(-20 * 86_400),
                  category: "Personal"),
        ]
        TareasStore.save(samples)
    }
}
