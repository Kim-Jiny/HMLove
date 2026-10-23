//
//  MoodFaceView.swift
//  HMLoveWidget
//
//  Flutter 앱의 lib/widgets/cute/mood_face.dart 를 SwiftUI Canvas 로 옮긴 귀여운 기분 얼굴.
//  위젯 공용 팔레트(WidgetPalette)도 여기에 둔다.
//

import SwiftUI

// MARK: - Palette

enum WidgetPalette {
    static let ink = Color(hex: "4A3B52")
    static let background = Color(hex: "FFF8FA")
    static let rose = Color(hex: "EC5F8E")
    static let roseSoft = Color(hex: "FFEAF1")
    static let lavender = Color(hex: "9B8CE8")
    static let lavenderSoft = Color(hex: "F0EDFF")
    static let mint = Color(hex: "4DBFA0")
    static let mintSoft = Color(hex: "E6F7F1")
    static let peach = Color(hex: "F59E6C")
    static let peachSoft = Color(hex: "FFEFE4")
    static let sky = Color(hex: "5BA8F0")
    static let skySoft = Color(hex: "E7F2FD")
    static let butter = Color(hex: "E9B93C")
    static let butterSoft = Color(hex: "FFF5D9")
    static let textPrimary = Color(hex: "2E2A33")
    static let textSecondary = Color(hex: "7A7480")
    static let textHint = Color(hex: "B9B3BE")
    static let border = Color(hex: "F6E7ED")
    /// 하드 오프셋 그림자(블러 없음)에 쓰는 장밋빛.
    static let hardShadow = Color(hex: "F3CCD9")

    static let heroGradient = LinearGradient(
        colors: [Color(hex: "FFE3EC"), Color(hex: "F0EDFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Mood key helpers

private let widgetMoodKeys: Set<String> = [
    "happy", "love", "excited", "grateful", "peaceful", "proud",
    "missing", "bored", "sad", "angry", "tired", "stressed"
]

private let widgetEmojiToMoodKey: [String: String] = [
    "😊": "happy", "🥰": "love", "🤩": "excited", "🙏": "grateful",
    "😌": "peaceful", "😎": "proud", "🥺": "missing", "😐": "bored",
    "😢": "sad", "😤": "angry", "😴": "tired", "😩": "stressed"
]

/// 기분 키가 있으면 그대로, 없으면 레거시 이모지에서 역변환. 둘 다 없으면 nil(무표정).
func resolveWidgetMoodKey(key: String?, emoji: String?) -> String? {
    if let key = key, widgetMoodKeys.contains(key) { return key }
    if let emoji = emoji {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        if let mapped = widgetEmojiToMoodKey[trimmed] { return mapped }
    }
    return nil
}

// MARK: - View

struct MoodFaceView: View {
    let moodKey: String?
    var size: CGFloat = 48

    var body: some View {
        Canvas { context, canvasSize in
            var ctx = context
            drawMoodFace(&ctx, s: min(canvasSize.width, canvasSize.height), key: moodKey)
        }
        .frame(width: size, height: size)
    }
}

private func moodBodyColor(_ key: String?) -> Color {
    switch key {
    case "happy": return Color(hex: "FFE08A")
    case "love": return Color(hex: "FFB8CF")
    case "excited": return Color(hex: "FFC9A0")
    case "grateful": return Color(hex: "BFEBD9")
    case "peaceful": return Color(hex: "BFDDF8")
    case "proud": return Color(hex: "D5CCF7")
    case "missing": return Color(hex: "CDE6FA")
    case "bored": return Color(hex: "E4DFEA")
    case "sad": return Color(hex: "B9D6F2")
    case "angry": return Color(hex: "FFA9A0")
    case "tired": return Color(hex: "D9D2F0")
    case "stressed": return Color(hex: "C9E3DA")
    default: return Color(hex: "EDE8F0")
    }
}

/// Dart 의 drawArc(타원 호) 와 같은 각도 규칙(시계방향, y 아래로)으로 점을 샘플링한 경로.
private func arcPath(center: CGPoint, rx: CGFloat, ry: CGFloat, start: CGFloat, sweep: CGFloat) -> Path {
    var p = Path()
    let n = 32
    for i in 0...n {
        let a = start + sweep * CGFloat(i) / CGFloat(n)
        let pt = CGPoint(x: center.x + rx * cos(a), y: center.y + ry * sin(a))
        if i == 0 {
            p.move(to: pt)
        } else {
            p.addLine(to: pt)
        }
    }
    return p
}

private func drawMoodFace(_ ctx: inout GraphicsContext, s: CGFloat, key: String?) {
    let ink = WidgetPalette.ink
    let pi = CGFloat.pi
    let lineW = s * 0.045
    let lineStyle = StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)

    // 몸통 + 하이라이트 + 윤곽선
    let head = CGRect(x: s * 0.06, y: s * 0.08, width: s * 0.88, height: s * 0.84)
    ctx.fill(Path(ellipseIn: head), with: .color(moodBodyColor(key)))
    ctx.stroke(
        arcPath(center: CGPoint(x: s * 0.33, y: s * 0.31), rx: s * 0.17, ry: s * 0.15,
                start: pi * 1.05, sweep: pi * 0.5),
        with: .color(Color.white.opacity(0.75)),
        style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round)
    )
    ctx.stroke(Path(ellipseIn: head), with: .color(ink), style: lineStyle)

    // 볼터치
    if key != "angry" && key != "bored" {
        let blush = Color(hex: "FF8FA8").opacity(0.45)
        for cx in [s * 0.24, s * 0.76] {
            let r = CGRect(x: cx - s * 0.08, y: s * 0.62 - s * 0.05, width: s * 0.16, height: s * 0.1)
            ctx.fill(Path(ellipseIn: r), with: .color(blush))
        }
    }

    let lx = s * 0.35
    let rx = s * 0.65
    let ey = s * 0.48

    func line(_ a: CGPoint, _ b: CGPoint, width: CGFloat? = nil, color: Color? = nil) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        ctx.stroke(
            p,
            with: .color(color ?? ink),
            style: StrokeStyle(lineWidth: width ?? lineW, lineCap: .round, lineJoin: .round)
        )
    }

    func arcEye(_ cx: CGFloat, up: Bool = true) {
        let p = arcPath(center: CGPoint(x: cx, y: ey), rx: s * 0.075, ry: s * 0.075,
                        start: up ? pi : 0, sweep: pi)
        ctx.stroke(p, with: .color(ink), style: lineStyle)
    }

    func dotEye(_ cx: CGFloat, r: CGFloat = 0.035) {
        ctx.fill(Path(ellipseIn: CGRect(x: cx - s * r, y: ey - s * r, width: s * r * 2, height: s * r * 2)),
                 with: .color(ink))
    }

    func bigEye(_ cx: CGFloat) {
        let r = s * 0.075
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: ey - r, width: r * 2, height: r * 2)), with: .color(ink))
        let h1 = s * 0.025
        ctx.fill(Path(ellipseIn: CGRect(x: cx - s * 0.02 - h1, y: ey - s * 0.025 - h1, width: h1 * 2, height: h1 * 2)),
                 with: .color(.white))
        let h2 = s * 0.012
        ctx.fill(Path(ellipseIn: CGRect(x: cx + s * 0.02 - h2, y: ey + s * 0.02 - h2, width: h2 * 2, height: h2 * 2)),
                 with: .color(.white))
    }

    func smile(w: CGFloat = 0.2, h: CGFloat = 0.12, y: CGFloat = 0.64, open: Bool = false) {
        let center = CGPoint(x: s * 0.5, y: s * y)
        if open {
            var p = arcPath(center: center, rx: s * w / 2, ry: s * h, start: 0, sweep: pi)
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(hex: "E5677F")))
            ctx.stroke(p, with: .color(ink), style: lineStyle)
        } else {
            let p = arcPath(center: center, rx: s * w / 2, ry: s * h, start: 0.15, sweep: pi - 0.3)
            ctx.stroke(p, with: .color(ink), style: lineStyle)
        }
    }

    func frown(w: CGFloat = 0.18, y: CGFloat = 0.72) {
        let p = arcPath(center: CGPoint(x: s * 0.5, y: s * y), rx: s * w / 2, ry: s * 0.06,
                        start: pi + 0.2, sweep: pi - 0.4)
        ctx.stroke(p, with: .color(ink), style: lineStyle)
    }

    func heart(_ c: CGPoint, _ r: CGFloat, _ color: Color) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + r * 0.9))
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y - r * 0.4),
            control1: CGPoint(x: c.x - r * 1.6, y: c.y - r * 0.2),
            control2: CGPoint(x: c.x - r * 0.7, y: c.y - r * 1.3)
        )
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y + r * 0.9),
            control1: CGPoint(x: c.x + r * 0.7, y: c.y - r * 1.3),
            control2: CGPoint(x: c.x + r * 1.6, y: c.y - r * 0.2)
        )
        ctx.fill(p, with: .color(color))
    }

    func sparkle(_ c: CGPoint, _ r: CGFloat, _ color: Color) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: c)
        ctx.fill(p, with: .color(color))
    }

    func drop(_ c: CGPoint, _ r: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r * 1.3))
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y + r),
            control1: CGPoint(x: c.x + r * 1.1, y: c.y - r * 0.1),
            control2: CGPoint(x: c.x + r, y: c.y + r)
        )
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y - r * 1.3),
            control1: CGPoint(x: c.x - r, y: c.y + r),
            control2: CGPoint(x: c.x - r * 1.1, y: c.y - r * 0.1)
        )
        ctx.fill(p, with: .color(Color(hex: "8CC8F5")))
        ctx.stroke(p, with: .color(ink),
                   style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round, lineJoin: .round))
    }

    switch key {
    case "happy":
        arcEye(lx)
        arcEye(rx)
        smile(w: 0.24, h: 0.1, open: true)
    case "love":
        heart(CGPoint(x: lx, y: ey), s * 0.065, Color(hex: "E5486F"))
        heart(CGPoint(x: rx, y: ey), s * 0.065, Color(hex: "E5486F"))
        smile(w: 0.2)
    case "excited":
        sparkle(CGPoint(x: lx, y: ey), s * 0.09, .white)
        sparkle(CGPoint(x: rx, y: ey), s * 0.09, .white)
        for cx in [lx, rx] {
            let r = s * 0.085
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: ey - r, width: r * 2, height: r * 2)),
                       with: .color(ink), style: StrokeStyle(lineWidth: s * 0.03))
        }
        smile(w: 0.28, h: 0.13, y: 0.62, open: true)
    case "grateful":
        arcEye(lx, up: false)
        arcEye(rx, up: false)
        smile(w: 0.18)
        sparkle(CGPoint(x: s * 0.84, y: s * 0.2), s * 0.07, .white)
    case "peaceful":
        arcEye(lx, up: false)
        arcEye(rx, up: false)
        smile(w: 0.12, y: 0.66)
    case "proud":
        for cx in [lx, rx] {
            let r = CGRect(x: cx - s * 0.11, y: ey - s * 0.075, width: s * 0.22, height: s * 0.15)
            ctx.fill(Path(roundedRect: r, cornerRadius: s * 0.05), with: .color(ink))
        }
        line(CGPoint(x: lx + s * 0.11, y: ey), CGPoint(x: rx - s * 0.11, y: ey))
        line(CGPoint(x: lx - s * 0.06, y: ey - s * 0.03), CGPoint(x: lx - s * 0.02, y: ey - s * 0.05),
             width: s * 0.025, color: .white)
        var m = Path()
        m.move(to: CGPoint(x: s * 0.41, y: s * 0.68))
        m.addQuadCurve(to: CGPoint(x: s * 0.62, y: s * 0.64), control: CGPoint(x: s * 0.52, y: s * 0.74))
        ctx.stroke(m, with: .color(ink), style: lineStyle)
    case "missing":
        bigEye(lx)
        bigEye(rx)
        var m = Path()
        m.move(to: CGPoint(x: s * 0.43, y: s * 0.72))
        m.addQuadCurve(to: CGPoint(x: s * 0.5, y: s * 0.72), control: CGPoint(x: s * 0.47, y: s * 0.67))
        m.addQuadCurve(to: CGPoint(x: s * 0.57, y: s * 0.72), control: CGPoint(x: s * 0.53, y: s * 0.77))
        ctx.stroke(m, with: .color(ink), style: lineStyle)
    case "bored":
        line(CGPoint(x: lx - s * 0.07, y: ey), CGPoint(x: lx + s * 0.07, y: ey))
        line(CGPoint(x: rx - s * 0.07, y: ey), CGPoint(x: rx + s * 0.07, y: ey))
        dotEye(lx, r: 0.02)
        dotEye(rx, r: 0.02)
        line(CGPoint(x: s * 0.43, y: s * 0.7), CGPoint(x: s * 0.57, y: s * 0.7))
    case "sad":
        dotEye(lx)
        dotEye(rx)
        frown()
        drop(CGPoint(x: lx - s * 0.02, y: ey + s * 0.16), s * 0.04)
    case "angry":
        line(CGPoint(x: lx - s * 0.08, y: ey - s * 0.1), CGPoint(x: lx + s * 0.07, y: ey - s * 0.04))
        line(CGPoint(x: rx + s * 0.08, y: ey - s * 0.1), CGPoint(x: rx - s * 0.07, y: ey - s * 0.04))
        dotEye(lx)
        dotEye(rx)
        frown(w: 0.16, y: 0.74)
        let red = Color(hex: "E5484D")
        let c = CGPoint(x: s * 0.82, y: s * 0.2)
        line(CGPoint(x: c.x - s * 0.04, y: c.y), CGPoint(x: c.x + s * 0.04, y: c.y), width: s * 0.035, color: red)
        line(CGPoint(x: c.x, y: c.y - s * 0.04), CGPoint(x: c.x, y: c.y + s * 0.04), width: s * 0.035, color: red)
    case "tired":
        line(CGPoint(x: lx - s * 0.06, y: ey), CGPoint(x: lx + s * 0.06, y: ey + s * 0.01))
        line(CGPoint(x: rx - s * 0.06, y: ey + s * 0.01), CGPoint(x: rx + s * 0.06, y: ey))
        let mouth = Path(ellipseIn: CGRect(x: s * 0.5 - s * 0.045, y: s * 0.7 - s * 0.05,
                                           width: s * 0.09, height: s * 0.1))
        ctx.fill(mouth, with: .color(Color(hex: "E5677F")))
        ctx.stroke(mouth, with: .color(ink),
                   style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round, lineJoin: .round))
        ctx.draw(
            Text("z").font(.system(size: s * 0.2, weight: .bold)).foregroundColor(ink.opacity(0.7)),
            at: CGPoint(x: s * 0.76, y: s * 0.02),
            anchor: .topLeading
        )
    case "stressed":
        var l = Path()
        l.move(to: CGPoint(x: lx - s * 0.06, y: ey - s * 0.05))
        l.addLine(to: CGPoint(x: lx + s * 0.05, y: ey))
        l.addLine(to: CGPoint(x: lx - s * 0.06, y: ey + s * 0.05))
        var r = Path()
        r.move(to: CGPoint(x: rx + s * 0.06, y: ey - s * 0.05))
        r.addLine(to: CGPoint(x: rx - s * 0.05, y: ey))
        r.addLine(to: CGPoint(x: rx + s * 0.06, y: ey + s * 0.05))
        ctx.stroke(l, with: .color(ink), style: lineStyle)
        ctx.stroke(r, with: .color(ink), style: lineStyle)
        var w = Path()
        w.move(to: CGPoint(x: s * 0.4, y: s * 0.7))
        w.addQuadCurve(to: CGPoint(x: s * 0.5, y: s * 0.7), control: CGPoint(x: s * 0.45, y: s * 0.64))
        w.addQuadCurve(to: CGPoint(x: s * 0.6, y: s * 0.7), control: CGPoint(x: s * 0.55, y: s * 0.76))
        ctx.stroke(w, with: .color(ink), style: lineStyle)
        drop(CGPoint(x: s * 0.82, y: s * 0.24), s * 0.045)
    default:
        dotEye(lx)
        dotEye(rx)
        smile(w: 0.14)
    }
}
