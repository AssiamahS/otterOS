import SwiftUI

/// First-open sunrise: night sky warms to dawn while the sun climbs past the
/// horizon, then the intro copy and name field fade in. Dia-inspired.
struct SunriseOnboardingView: View {
    @EnvironmentObject var missions: MissionStore
    var onDone: () -> Void

    @State private var risen = false
    @State private var showContent = false
    @State private var name = ""

    private let night: [Color] = [
        Color(red: 0.02, green: 0.03, blue: 0.10), Color(red: 0.03, green: 0.04, blue: 0.13), Color(red: 0.02, green: 0.03, blue: 0.10),
        Color(red: 0.05, green: 0.05, blue: 0.16), Color(red: 0.07, green: 0.06, blue: 0.20), Color(red: 0.05, green: 0.05, blue: 0.16),
        Color(red: 0.10, green: 0.08, blue: 0.22), Color(red: 0.13, green: 0.09, blue: 0.24), Color(red: 0.10, green: 0.08, blue: 0.22),
    ]
    private let dawn: [Color] = [
        Color(red: 0.35, green: 0.45, blue: 0.75), Color(red: 0.55, green: 0.55, blue: 0.85), Color(red: 0.35, green: 0.45, blue: 0.75),
        Color(red: 0.95, green: 0.60, blue: 0.40), Color(red: 1.00, green: 0.75, blue: 0.45), Color(red: 0.95, green: 0.60, blue: 0.40),
        Color(red: 1.00, green: 0.55, blue: 0.30), Color(red: 1.00, green: 0.70, blue: 0.30), Color(red: 1.00, green: 0.55, blue: 0.30),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.55], [0.5, risen ? 0.62 : 0.5], [1, 0.55],
                        [0, 1], [0.5, 1], [1, 1],
                    ],
                    colors: risen ? dawn : night
                )
                .ignoresSafeArea()

                // Sun: soft glow halo behind a warm disc, climbing from below the fold.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.55), Color(red: 1.0, green: 0.62, blue: 0.30), .clear],
                            center: .center, startRadius: 8, endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .blur(radius: 18)
                    .offset(y: risen ? geo.size.height * 0.12 : geo.size.height * 0.75)

                Circle()
                    .fill(Color(red: 1.0, green: 0.88, blue: 0.62))
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.9), radius: 40)
                    .offset(y: risen ? geo.size.height * 0.12 : geo.size.height * 0.75)

                VStack(spacing: 16) {
                    Spacer()
                    Text("otterOS")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your day, crossed off.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))

                    TextField("What should I call you?", text: $name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.top, 12)

                    Button {
                        UserDefaults.standard.set(name.isEmpty ? "friend" : name, forKey: "userName")
                        missions.seedIfEmpty()
                        onDone()
                    } label: {
                        Text("Let's get started")
                            .font(.headline)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(Color(red: 0.9, green: 0.45, blue: 0.15))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2)) { risen = true }
            withAnimation(.easeIn(duration: 1.0).delay(2.4)) { showContent = true }
        }
    }
}
