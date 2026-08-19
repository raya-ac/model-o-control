import AppKit
import ModelOCore
import SwiftUI

struct ModelOMouseVisual: View {
    var color: Color
    var effect: LightingEffect
    var size: CGFloat
    var brightness: Int = 4
    var speed: Int = 2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathes = false
    @State private var spectrumMoves = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.34))
                .frame(width: size * 0.56, height: size * 0.13)
                .blur(radius: 18)
                .offset(y: size * 0.37)

            if effect != .off {
                railLayer(lineWidth: size * 0.045, opacity: breathes ? glowOpacity : glowOpacity * 0.5)
                    .blur(radius: size * 0.045)
            }

            Image(nsImage: ModelOMouseAsset.image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.48), radius: 18, y: 12)

            if effect != .off {
                railLayer(lineWidth: max(1.5, size * 0.009), opacity: breathes ? railOpacity : railOpacity * 0.72)

                Capsule()
                    .stroke(activeColor.opacity(breathes ? 0.95 : 0.58), lineWidth: max(1.2, size * 0.007))
                    .frame(width: size * 0.045, height: size * 0.13)
                    .offset(y: -size * 0.265)
                    .shadow(color: activeColor, radius: size * 0.018)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: size, height: size)
        .onAppear { restartMotion() }
        .onChange(of: effect) { _, _ in restartMotion() }
        .onChange(of: speed) { _, _ in restartMotion() }
        .accessibilityLabel("Original wired Glorious Model O V1 lighting preview")
    }

    private var activeColor: Color { effect == .off ? .clear : color }

    private var glowOpacity: Double {
        0.42 + (Double(max(0, min(4, brightness))) * 0.11)
    }

    private var railOpacity: Double {
        0.58 + (Double(max(0, min(4, brightness))) * 0.09)
    }

    private var spectrum: LinearGradient {
        LinearGradient(
            colors: [.pink, .purple, .blue, .cyan, .green, .yellow, .orange, .pink],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func railLayer(lineWidth: CGFloat, opacity: Double) -> some View {
        if effect.previewUsesSpectrum {
            RGBRails()
                .stroke(spectrum, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .hueRotation(.degrees(spectrumMoves ? 360 : 0))
                .opacity(opacity)
                .padding(size * 0.03)
                .blendMode(.plusLighter)
        } else {
            RGBRails()
                .stroke(activeColor.opacity(opacity), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .padding(size * 0.03)
                .blendMode(.plusLighter)
        }
    }

    private var motionDuration: Double {
        let base = switch effect {
        case .breathing, .seamless, .singleBreathing: 1.35
        case .wave, .glorious, .rave, .random, .tail: 0.8
        default: 2.2
        }
        let multiplier = [1.35, 1.0, 0.72, 0.5][max(0, min(3, speed))]
        return base * multiplier
    }

    private func restartMotion() {
        breathes = false
        spectrumMoves = false
        guard !reduceMotion else {
            breathes = true
            return
        }
        withAnimation(.easeInOut(duration: motionDuration).repeatForever(autoreverses: true)) {
            breathes = true
        }
        if effect.previewUsesSpectrum {
            withAnimation(.linear(duration: motionDuration * 2.8).repeatForever(autoreverses: false)) {
                spectrumMoves = true
            }
        }
    }
}

private extension LightingEffect {
    var previewUsesSpectrum: Bool {
        [.glorious, .breathing, .tail, .seamless, .rave, .random, .wave].contains(self)
    }
}

private enum ModelOMouseAsset {
    static let image: NSImage = {
        if let url = Bundle.main.url(forResource: "model-o-v1-render", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "Model O") ?? NSImage()
    }()
}

private struct RGBRails: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.305, y: rect.height * 0.315))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.325, y: rect.height * 0.765),
            control1: CGPoint(x: rect.width * 0.275, y: rect.height * 0.48),
            control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.68)
        )
        path.move(to: CGPoint(x: rect.width * 0.695, y: rect.height * 0.315))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.675, y: rect.height * 0.765),
            control1: CGPoint(x: rect.width * 0.725, y: rect.height * 0.48),
            control2: CGPoint(x: rect.width * 0.72, y: rect.height * 0.68)
        )
        return path
    }
}
