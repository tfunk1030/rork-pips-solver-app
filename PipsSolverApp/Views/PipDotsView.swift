import SwiftUI

struct PipDotsView: View {
    let value: Int
    let size: CGFloat
    var dotColor: Color = .primary

    private var dotSize: CGFloat { size * 0.18 }
    private var inset: CGFloat { size * 0.22 }

    var body: some View {
        Canvas { context, canvasSize in
            let d = min(canvasSize.width, canvasSize.height)
            let dot = d * 0.18
            let pad = d * 0.22

            let tl = CGPoint(x: pad, y: pad)
            let tc = CGPoint(x: d / 2, y: pad)
            let tr = CGPoint(x: d - pad, y: pad)
            let ml = CGPoint(x: pad, y: d / 2)
            let mc = CGPoint(x: d / 2, y: d / 2)
            let mr = CGPoint(x: d - pad, y: d / 2)
            let bl = CGPoint(x: pad, y: d - pad)
            let bc = CGPoint(x: d / 2, y: d - pad)
            let br = CGPoint(x: d - pad, y: d - pad)

            let positions: [CGPoint]
            switch value {
            case 0: positions = []
            case 1: positions = [mc]
            case 2: positions = [tr, bl]
            case 3: positions = [tr, mc, bl]
            case 4: positions = [tl, tr, bl, br]
            case 5: positions = [tl, tr, mc, bl, br]
            case 6: positions = [tl, tr, ml, mr, bl, br]
            default: positions = []
            }

            for pos in positions {
                let rect = CGRect(
                    x: pos.x - dot / 2,
                    y: pos.y - dot / 2,
                    width: dot,
                    height: dot
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(dotColor)
                )
            }
        }
        .frame(width: size, height: size)
    }
}
