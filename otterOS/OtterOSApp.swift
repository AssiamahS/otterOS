import SwiftUI

@main
struct OtterOSApp: App {
    @UIApplicationDelegateAdaptor(OttoAppDelegate.self) private var appDelegate
    @AppStorage("onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var missions = MissionStore.shared
    @StateObject private var health = HealthManager()
    @StateObject private var recordings = RecordingStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    MainView()
                        .environmentObject(missions)
                        .environmentObject(health)
                        .environmentObject(recordings)
                } else {
                    SunriseOnboardingView {
                        onboarded = true
                    }
                    .environmentObject(missions)
                }
            }
            .onAppear { appDelegate.missionStore = missions }
        }
        .onChange(of: scenePhase) { _, phase in
            // An app left open overnight still gets its sunrise.
            if phase == .active {
                missions.sunriseResetIfNeeded()
                health.refresh()
            }
        }
    }
}

struct MainView: View {
    var body: some View {
        TabView {
            MissionsView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            RecorderView()
                .tabItem { Label("Record", systemImage: "waveform.circle.fill") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
        }
        .tint(.orange)
    }
}
