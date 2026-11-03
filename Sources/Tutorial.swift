import SwiftUI

/// First-launch walkthrough. ContentView shows it until it is finished or skipped once.
struct Tutorial: View {
    let onDone: () -> Void
    @State private var page = 0

    private let steps: [(title: String, text: String)] = [
        ("Bienvenido a TensorCar",
         "Tu auto te cuenta cómo está a través del puerto OBD. TensorCar lo traduce para ti."),
        ("Conecta el adaptador",
         "Enchufa el adaptador OBD WiFi, pon el contacto y únete a su red en Ajustes del iPhone. Luego toca Conectar. ¿Sin adaptador? Prueba el modo demo."),
        ("Míralo en vivo",
         "RPM, temperatura, batería y los sensores clave del motor, con lo que es normal para cada uno."),
        ("Entiende las fallas",
         "Ve qué significa cada código de falla sin salir de la app, incluso sin internet, y bórralo cuando esté resuelto."),
        ("Guarda su historia",
         "Cada conexión queda registrada. Anota servicios, choques y la presión de las llantas, y respalda todo en la nube."),
    ]

    private var isLast: Bool { page == steps.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.brand, .brandLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            FloatingBubbles()
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button("Saltar", action: onDone)
                        .font(.subheadline.bold())
                        .opacity(isLast ? 0 : 0.9)
                        .disabled(isLast)
                }
                .padding(.horizontal, 24)

                TabView(selection: $page) {
                    ForEach(steps.indices, id: \.self) { i in
                        StepPage(index: i, title: steps[i].title, text: steps[i].text, active: page == i).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(i == page ? 1 : 0.4))
                            .frame(width: i == page ? 24 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.4), value: page)

                Button {
                    if isLast { onDone() } else { withAnimation { page += 1 } }
                } label: {
                    Text(isLast ? "Empezar" : "Siguiente")
                        .font(.headline).foregroundStyle(Color.brand)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24).padding(.bottom, 12)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct StepPage: View {
    let index: Int
    let title: String
    let text: String
    let active: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                PulseRings()
                Circle().fill(.white.opacity(0.18)).frame(width: 170, height: 170)
                illustration
            }
            .frame(height: 260)
            .scaleEffect(active ? 1 : 0.85)
            .animation(.spring(duration: 0.6, bounce: 0.4), value: active)

            VStack(spacing: 12) {
                Text(title).font(.title.bold())
                Text(text).font(.body).opacity(0.92)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .offset(y: active ? 0 : 30)
            .opacity(active ? 1 : 0)
            .animation(.spring(duration: 0.6).delay(0.15), value: active)
            Spacer()
        }
    }

    @ViewBuilder private var illustration: some View {
        switch index {
        case 0: DrivingCar()
        case 1: Image(systemName: "wifi").font(.system(size: 72, weight: .semibold)).symbolEffect(.variableColor.iterative.reversing)
        case 2: SweepingGauge().frame(width: 130, height: 130)
        case 3: FaultResolved()
        default: Rewinding()
        }
    }
}

/// Rings expanding out of the illustration, like a radar ping.
private struct PulseRings: View {
    @State private var on = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 2)
                    .frame(width: 170, height: 170)
                    .scaleEffect(on ? 1.5 : 1)
                    .opacity(on ? 0 : 0.8)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8), value: on)
            }
        }
        .onAppear { on = true }
    }
}

/// A car bobbing over road marks that scroll past.
private struct DrivingCar: View {
    @State private var on = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "car.fill")
                .font(.system(size: 64))
                .offset(y: on ? -4 : 2)
                .animation(.easeInOut(duration: 0.35).repeatForever(), value: on)
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in Capsule().frame(width: 18, height: 4) }
            }
            .offset(x: on ? -30 : 0)  // one mark + gap, so the loop is seamless
            .animation(.linear(duration: 0.4).repeatForever(autoreverses: false), value: on)
            .frame(width: 100)
            .clipped()
            .opacity(0.7)
        }
        .onAppear { on = true }
    }
}

/// A speedometer whose arc and needle sweep up and down.
private struct SweepingGauge: View {
    @State private var on = false

    var body: some View {
        ZStack {
            Circle().trim(from: 0.15, to: 0.85)
                .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle().trim(from: 0.15, to: on ? 0.75 : 0.25)
                .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(90))
            Capsule().fill(.white).frame(width: 6, height: 50).offset(y: -25)
                .rotationEffect(.degrees(on ? 90 : -90))  // matches the arc end: trim t is 360·t − 180 degrees from 12 o'clock
            Circle().fill(.white).frame(width: 16, height: 16)
        }
        .animation(.easeInOut(duration: 1.6).repeatForever(), value: on)
        .onAppear { on = true }
    }
}

/// A warning that turns into a check, over and over.
private struct FaultResolved: View {
    @State private var fixed = false

    var body: some View {
        Image(systemName: fixed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 72))
            .contentTransition(.symbolEffect(.replace))
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation { fixed.toggle() }
                }
            }
    }
}

/// The history clock turning backwards.
private struct Rewinding: View {
    @State private var on = false

    var body: some View {
        Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 72))
            .rotationEffect(.degrees(on ? -360 : 0))
            .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: on)
            .onAppear { on = true }
    }
}

/// Soft circles drifting behind everything.
private struct FloatingBubbles: View {
    @State private var on = false
    private let spots: [(x: CGFloat, y: CGFloat)] = [(0.1, 0.2), (0.85, 0.12), (0.3, 0.6), (0.9, 0.7), (0.5, 0.92), (0.15, 0.85)]

    var body: some View {
        GeometryReader { g in
            ForEach(spots.indices, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: CGFloat(60 + i * 30))
                    .position(x: g.size.width * spots[i].x, y: g.size.height * spots[i].y)
                    .offset(y: on ? -24 : 24)
                    .animation(.easeInOut(duration: Double(3 + i)).repeatForever(), value: on)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { on = true }
    }
}
