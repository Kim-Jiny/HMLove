//
//  WidgetPaperKit.swift
//  HMLoveWidget
//
//  "종이 더미 + 폴라로이드" 스타일의 재사용 SwiftUI 조각들.
//  블러 없이 단순한 도형만 사용한다(위젯 렌더링 예산).
//

import SwiftUI

// MARK: - Constants

enum PaperKit {
    static let cardWhite = Color(hex: "FFFBFD")
    static let backPink = Color(hex: "FFC9DC")
    static let backLavender = Color(hex: "DCD3FF")
    static let washiYellow = Color(hex: "FFE08A")
    static let washiPink = Color(hex: "FFB8D0")
    static let photoPink = Color(hex: "FFF1F6")
    static let sparkleYellow = Color(hex: "FFD95E")
}

struct PaperBack {
    let color: Color
    let angle: Double
}

// MARK: - Theme bridge (기본 blush 테마만 종이 더미)

extension CalendarWidgetTheme {
    var paperInk: Color { outlineColor }
    var paperFill: Color { isDefault ? PaperKit.cardWhite : Color(hex: backgroundHex) }
    var paperBacks: [PaperBack] {
        isDefault
            ? [PaperBack(color: PaperKit.backPink, angle: -2), PaperBack(color: PaperKit.backLavender, angle: 1.7)]
            : []
    }
}

extension CoupleData {
    /// 다음 기념일까지의 진행률. 데이터가 없으면 nil(막대 숨김).
    var anniversaryProgress: Double? {
        guard let left = nextAnniversaryDaysLeft, left >= 0, daysTogether > 0 else { return nil }
        let total = daysTogether + left
        guard total > 0 else { return nil }
        return min(1, max(0, Double(daysTogether) / Double(total)))
    }

    var displayMyName: String { myName.isEmpty ? "나" : myName }
    var displayPartnerName: String { partnerName.isEmpty ? "상대방" : partnerName }
}

// MARK: - Shapes

struct HeartShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + w * x, y: r.minY + h * y) }
        var p = Path()
        p.move(to: pt(0.5, 0.95))
        p.addCurve(to: pt(0.04, 0.34), control1: pt(0.2, 0.78), control2: pt(-0.02, 0.55))
        p.addCurve(to: pt(0.5, 0.22), control1: pt(0.08, 0.02), control2: pt(0.40, 0.0))
        p.addCurve(to: pt(0.96, 0.34), control1: pt(0.60, 0.0), control2: pt(0.92, 0.02))
        p.addCurve(to: pt(0.5, 0.95), control1: pt(1.02, 0.55), control2: pt(0.8, 0.78))
        p.closeSubpath()
        return p
    }
}

struct SparkleShape: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: c)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: c)
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: c)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: c)
        p.closeSubpath()
        return p
    }
}

// MARK: - Stickers

struct HeartSticker: View {
    var size: CGFloat = 20
    var color: Color = WidgetPalette.rose
    var ink: Color = WidgetPalette.ink

    var body: some View {
        ZStack {
            HeartShape().fill(color)
            HeartShape().stroke(ink, style: StrokeStyle(lineWidth: max(1.2, size * 0.08), lineJoin: .round))
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.18, height: size * 0.11)
                .rotationEffect(.degrees(-30))
                .offset(x: -size * 0.2, y: -size * 0.14)
        }
        .frame(width: size, height: size)
    }
}

struct SparkleSticker: View {
    var size: CGFloat = 18
    var color: Color = PaperKit.sparkleYellow
    var ink: Color = WidgetPalette.ink

    var body: some View {
        ZStack {
            SparkleShape().fill(color)
            SparkleShape().stroke(ink, style: StrokeStyle(lineWidth: max(1.1, size * 0.07), lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct WashiTape: View {
    var color: Color = PaperKit.washiYellow
    var width: CGFloat = 74
    var height: CGFloat = 20
    var angle: Double = -3

    var body: some View {
        Rectangle()
            .fill(color.opacity(0.8))
            .overlay(Rectangle().stroke(WidgetPalette.ink.opacity(0.4), lineWidth: 0.8))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Paper card

/// 잉크 윤곽선 + 굵은 하드 아래 모서리 + (선택) 뒤에 비스듬히 깔린 색종이들.
/// 하드 모서리가 `edge` 만큼 아래로 삐져나오므로 호출 쪽 패딩에서 고려한다.
struct PaperCardBackground: View {
    var fill: Color = PaperKit.cardWhite
    var ink: Color = WidgetPalette.ink
    var radius: CGFloat = 20
    var edge: CGFloat = 5
    var lineWidth: CGFloat = 2
    var backs: [PaperBack] = []

    var body: some View {
        ZStack {
            ForEach(Array(backs.enumerated()), id: \.offset) { _, back in
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(back.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(ink, lineWidth: lineWidth * 0.8)
                    )
                    .offset(y: edge)
                    .rotationEffect(.degrees(back.angle))
            }
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(ink)
                .offset(y: edge)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(ink, lineWidth: lineWidth)
        }
    }
}

// MARK: - Polaroid

/// 폴라로이드: 흰 카드 + 분홍 사진 영역(기분 얼굴) + 이름.
struct PolaroidFace: View {
    let moodKey: String?
    let name: String
    var width: CGFloat = 64
    var angle: Double = -6

    var body: some View {
        let photo = width - 14
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(PaperKit.photoPink)
                .frame(width: photo, height: photo * 0.92)
                .overlay(MoodFaceView(moodKey: moodKey, size: photo * 0.74))
            Text(name)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(WidgetPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: photo)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .shadow(color: WidgetPalette.ink.opacity(0.25), radius: 2.5, x: 0, y: 2.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(WidgetPalette.ink, lineWidth: 1.6)
        )
        .rotationEffect(.degrees(angle))
    }
}

// MARK: - Progress

/// 흰 트랙 + 잉크 윤곽선 + 장미색 채움, 채움 끝에 하트 스티커.
struct AnniversaryProgress: View {
    let progress: Double
    var fill: Color = WidgetPalette.rose
    var ink: Color = WidgetPalette.ink
    var trackColor: Color = .white
    var height: CGFloat = 11

    var body: some View {
        let heart = height + 9
        GeometryReader { geo in
            let w = geo.size.width
            let usable = max(0, w - heart * 0.4)
            let p = min(1, max(0.03, progress))
            let fillW = max(height, usable * CGFloat(p))
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor).frame(height: height)
                Capsule().fill(fill)
                    .frame(width: fillW, height: height)
                Capsule().strokeBorder(ink, lineWidth: 1.6).frame(height: height)
                HeartSticker(size: heart, color: fill, ink: ink)
                    .offset(x: min(max(0, fillW - heart * 0.7), max(0, w - heart)))
            }
            .frame(height: geo.size.height)
        }
        .frame(height: heart)
    }
}
