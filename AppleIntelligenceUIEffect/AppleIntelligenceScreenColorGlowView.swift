//
//  AppleIntelligenceScreenColorGlowView.swift
//  SwiftUITest
//
//  Created by phoenix on 2025/12/3.
//

import SwiftUI

// MARK: - 配置结构体
struct GlowBorderConfiguration {
    var colors: [Color]
    var lineWidth: CGFloat
    var rotationSpeed: Double
    var layerRotationSpeeds: [Double]
    var primaryBlurRange: ClosedRange<CGFloat>
    var secondaryBlurRange: ClosedRange<CGFloat>
    var blurOscillationSpeed: (primary: Double, secondary: Double)
    var cornerRadius: CGFloat?
    
    static let `default` = GlowBorderConfiguration(
        colors: [
            Color("#6831D8"),
            Color("#52B1F4"),
            Color("#9548D7"),
            Color("#F5B542"),
            Color("#E93E56"),
            Color("#F07F49"),
            Color("#6831D8")
        ],
        lineWidth: 8,
        rotationSpeed: 60,
        layerRotationSpeeds: [133, -133],
        primaryBlurRange: 6...18,
        secondaryBlurRange: 2...8,
        blurOscillationSpeed: (2, 4),
        cornerRadius: nil
    )
}

// MARK: - 波动状态
struct WaveState {
    var lineWidthMultiplier: CGFloat = 1.0
    var blurMultiplier: CGFloat = 1.0
    var brightnessBoost: CGFloat = 0.3      // 亮度增强（0~1）
    var animationSpeed: CGFloat = 1.0        // 动画速度倍数
    var triggerCount: Int = 0                // 使用计数器，每次触发都能立即响应
    
    mutating func trigger() {
        triggerCount += 1
    }
}

// MARK: - 获取设备屏幕圆角
extension UIScreen {
    /// 获取设备屏幕的真实圆角半径
    /// 使用私有 API _displayCornerRadius，如果获取失败则返回默认值
    var displayCornerRadius: CGFloat {
        guard let cornerRadius = self.value(forKey: "_displayCornerRadius") as? CGFloat else {
            return 44 // 默认回退值
        }
        return cornerRadius
    }
}

// MARK: - 发光边框效果 ViewModifier
struct GlowBorderModifier: ViewModifier {
    var configuration: GlowBorderConfiguration
    @Binding var waveState: WaveState
    
    @State private var animatedLineWidth: CGFloat = 1.0
    @State private var animatedBlurMultiplier: CGFloat = 1.0
    @State private var animatedBrightness: CGFloat = 0.0  // 亮度增强
    
    private var effectiveCornerRadius: CGFloat {
        configuration.cornerRadius ?? UIScreen.main.displayCornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSince1970
                        
                        let circle = Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: configuration.colors),
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                )
                            )
                        
                        let currentLineWidth = configuration.lineWidth * animatedLineWidth
                        
                        let maskRectangle = RoundedRectangle(cornerRadius: effectiveCornerRadius)
                            .stroke(lineWidth: max(1, currentLineWidth))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        
                        ZStack(alignment: .center) {
                            ForEach(Array(configuration.layerRotationSpeeds.enumerated()), id: \.offset) { index, layerSpeed in
                                let isPrimary = index == 0
                                let blurRange = isPrimary ? configuration.primaryBlurRange : configuration.secondaryBlurRange
                                let oscillationSpeed = isPrimary ? configuration.blurOscillationSpeed.primary : configuration.blurOscillationSpeed.secondary
                                
                                let baseBlur = blurRange.lowerBound + (blurRange.upperBound - blurRange.lowerBound) / 2
                                let blurAmplitude = (blurRange.upperBound - blurRange.lowerBound) / 2
                                let dynamicBlur = baseBlur + blurAmplitude * sin(time * oscillationSpeed)
                                let finalBlur = dynamicBlur * animatedBlurMultiplier
                                
                                circle
                                    .rotationEffect(.degrees(time * configuration.rotationSpeed))
                                    .scaleEffect(2.4)
                                    .rotationEffect(.degrees(time * layerSpeed))
                                    .mask(alignment: .center) {
                                        maskRectangle.blur(radius: max(1, finalBlur))
                                    }
                            }
                        }
                        .brightness(animatedBrightness)  // 应用亮度增强
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .onChange(of: waveState.triggerCount) { _, _ in
                triggerWaveAnimation()
            }
            .onAppear {
                animatedLineWidth = 1.0
                animatedBlurMultiplier = 1.0
                animatedBrightness = 0.0
            }
    }
    
    private func triggerWaveAnimation() {
        let speed = waveState.animationSpeed
        let expandDuration = 0.1 / speed
        let contractDuration = 0.2 / speed
        
        // 立即扩张并增亮（打断之前的动画）
        withAnimation(.easeOut(duration: expandDuration)) {
            animatedLineWidth = waveState.lineWidthMultiplier
            animatedBlurMultiplier = waveState.blurMultiplier
            animatedBrightness = waveState.brightnessBoost
        }
        
        // 延迟后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + expandDuration) {
            withAnimation(.easeOut(duration: contractDuration)) {
                animatedLineWidth = 1.0
                animatedBlurMultiplier = 1.0
                animatedBrightness = 0.0
            }
        }
    }
}

// MARK: - View 扩展
extension View {
    func glowBorder(
        configuration: GlowBorderConfiguration = .default,
        waveState: Binding<WaveState> = .constant(WaveState())
    ) -> some View {
        modifier(GlowBorderModifier(configuration: configuration, waveState: waveState))
    }
}

// MARK: - 演示视图（带参数控制）
struct AppleIntelligenceScreenColorGlowView: View {
    // 可调参数
    @State private var lineWidth: CGFloat = 8
    @State private var rotationSpeed: Double = 60
    @State private var primaryBlurMin: CGFloat = 6
    @State private var primaryBlurMax: CGFloat = 18
    @State private var secondaryBlurMin: CGFloat = 2
    @State private var secondaryBlurMax: CGFloat = 8
    @State private var layerSpeed1: Double = 133
    @State private var layerSpeed2: Double = -133
    @State private var blurSpeed1: Double = 2
    @State private var blurSpeed2: Double = 4
    
    // 波动状态
    @State private var waveState = WaveState()
    @State private var waveIntensity: CGFloat = 3.0
    @State private var waveBrightness: CGFloat = 0.3
    @State private var waveAnimationSpeed: CGFloat = 1.0
    
    // 控制面板显示
    @State private var showControls: Bool = true
    
    private var currentConfiguration: GlowBorderConfiguration {
        // 安全创建 Range，确保 lowerBound <= upperBound
        let safePrimaryBlurRange = min(primaryBlurMin, primaryBlurMax)...max(primaryBlurMin, primaryBlurMax)
        let safeSecondaryBlurRange = min(secondaryBlurMin, secondaryBlurMax)...max(secondaryBlurMin, secondaryBlurMax)
        
        return GlowBorderConfiguration(
            colors: [
                Color("#6831D8"),
                Color("#52B1F4"),
                Color("#9548D7"),
                Color("#F5B542"),
                Color("#E93E56"),
                Color("#F07F49"),
                Color("#6831D8")
            ],
            lineWidth: lineWidth,
            rotationSpeed: rotationSpeed,
            layerRotationSpeeds: [layerSpeed1, layerSpeed2],
            primaryBlurRange: safePrimaryBlurRange,
            secondaryBlurRange: safeSecondaryBlurRange,
            blurOscillationSpeed: (blurSpeed1, blurSpeed2),
            cornerRadius: nil
        )
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color.black
                .ignoresSafeArea()
            
            // 内容区域
            VStack(spacing: 16) {
                // 标题
                Text("Glow Border Effect")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("#52B1F4"), Color("#9548D7")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 60)
                
                // 屏幕圆角信息
                Text("屏幕圆角: \(String(format: "%.1f", UIScreen.main.displayCornerRadius))pt")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // 波动触发按钮
                Button {
                    triggerWave()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title2)
                        Text("触发波动效果")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color("#6831D8"), Color("#E93E56")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color("#6831D8").opacity(0.5), radius: 20, y: 10)
                }
                .padding(.bottom, 20)
                
                // 控制面板
                if showControls {
                    controlPanel
                }
                
                // 显示/隐藏控制面板按钮
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showControls.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: showControls ? "chevron.down" : "chevron.up")
                        Text(showControls ? "隐藏控制面板" : "显示控制面板")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding(.bottom, 20)
            }
        }
        .glowBorder(configuration: currentConfiguration, waveState: $waveState)
    }
    
    private var controlPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 基础参数
                GroupBox {
                    VStack(spacing: 12) {
                        parameterSlider(title: "线宽", value: $lineWidth, range: 1...30, format: "%.1f pt")
                        parameterSlider(title: "旋转速度", value: $rotationSpeed, range: 10...200, format: "%.0f °/s")
                    }
                } label: {
                    Label("基础参数", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                // 图层旋转速度
                GroupBox {
                    VStack(spacing: 12) {
                        parameterSlider(title: "图层1速度", value: $layerSpeed1, range: -200...200, format: "%.0f °/s")
                        parameterSlider(title: "图层2速度", value: $layerSpeed2, range: -200...200, format: "%.0f °/s")
                    }
                } label: {
                    Label("图层旋转", systemImage: "rotate.3d")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                // 主模糊参数
                GroupBox {
                    VStack(spacing: 12) {
                        parameterSlider(title: "最小模糊", value: $primaryBlurMin, range: 0...30, format: "%.1f")
                        parameterSlider(title: "最大模糊", value: $primaryBlurMax, range: 0...40, format: "%.1f")
                        parameterSlider(title: "振荡速度", value: $blurSpeed1, range: 0.5...10, format: "%.1f")
                    }
                } label: {
                    Label("主图层模糊", systemImage: "circle.hexagongrid")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                // 副模糊参数
                GroupBox {
                    VStack(spacing: 12) {
                        parameterSlider(title: "最小模糊", value: $secondaryBlurMin, range: 0...20, format: "%.1f")
                        parameterSlider(title: "最大模糊", value: $secondaryBlurMax, range: 0...30, format: "%.1f")
                        parameterSlider(title: "振荡速度", value: $blurSpeed2, range: 0.5...10, format: "%.1f")
                    }
                } label: {
                    Label("副图层模糊", systemImage: "circle.hexagongrid.fill")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                // 交互设置
                GroupBox {
                    VStack(spacing: 12) {
                        parameterSlider(title: "波动强度", value: $waveIntensity, range: 1...8, format: "%.1fx")
                        parameterSlider(title: "亮度增强", value: $waveBrightness, range: 0...0.8, format: "%.2f")
                        parameterSlider(title: "动画速度", value: $waveAnimationSpeed, range: 0.3...3.0, format: "%.1fx")
                    }
                } label: {
                    Label("交互设置", systemImage: "waveform")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                // 重置按钮
                Button {
                    resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置为默认值")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                    )
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(maxHeight: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
    
    private func parameterSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.black)
            }
            Slider(value: value, in: range)
                .tint(Color("#52B1F4"))
        }
    }
    
    private func parameterSlider(title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.black)
            }
            Slider(value: value, in: range)
                .tint(Color("#52B1F4"))
        }
    }
    
    private func triggerWave() {
        waveState.lineWidthMultiplier = waveIntensity
        waveState.blurMultiplier = waveIntensity
        waveState.brightnessBoost = waveBrightness
        waveState.animationSpeed = waveAnimationSpeed
        waveState.trigger()  // 使用计数器触发，支持连续点击
    }
    
    private func resetToDefaults() {
        withAnimation(.spring(response: 0.3)) {
            lineWidth = 8
            rotationSpeed = 60
            primaryBlurMin = 6
            primaryBlurMax = 18
            secondaryBlurMin = 2
            secondaryBlurMax = 8
            layerSpeed1 = 133
            layerSpeed2 = -133
            blurSpeed1 = 2
            blurSpeed2 = 4
            waveIntensity = 3.0
            waveBrightness = 0.3
            waveAnimationSpeed = 1.0
        }
    }
}

// MARK: - Color Hex 扩展
extension Color {
    init(_ hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Preview
#Preview {
    AppleIntelligenceScreenColorGlowView()
}
