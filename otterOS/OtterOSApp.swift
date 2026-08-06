import SwiftUI

@main
struct OtterOSApp: App {
    @AppStorage("onboarded") private var onboarded = false
    @StateObject private var missions = MissionStore()
    @StateObject private var health = HealthManager()
    @StateObject private var recordings = RecordingStore()

    var body: some Scene {
        WindowGroup {
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
