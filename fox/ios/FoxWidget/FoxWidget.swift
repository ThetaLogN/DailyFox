//
//  FoxWidget.swift
//  FoxWidget - Versione Ottimizzata per Widget iOS
//
//  Created by Giorgio Martucci on 18/06/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), rating: 7, animationPhase: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.foxApp")
        let ratingString = userDefaults?.string(forKey: "rating") ?? "7"
        let rating = Int(ratingString) ?? 7
        
        let entry = SimpleEntry(date: Date(), rating: rating, animationPhase: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.foxApp")
        let ratingString = userDefaults?.string(forKey: "rating") ?? "7"
        let rating = Int(ratingString) ?? 7
        
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        
        // Crea più entry per simulare "animazione" tramite aggiornamenti
        for i in 0..<6 {
            let entryDate = Calendar.current.date(byAdding: .second, value: i * 5, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, rating: rating, animationPhase: i % 8)
            entries.append(entry)
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let rating: Int
    let animationPhase: Int // 0-3 per diversi stati di "animazione"
}

struct AnimeFoxView: View {
    let rating: Int
    let animationPhase: Int
    
    private var foxMainColor: Color {
        switch rating {
        case 1...2: return Color(red: 0.8, green: 0.5, blue: 0.3) // Marrone spento per tristezza
        case 3...4: return Color(red: 0.9, green: 0.6, blue: 0.35) // Marrone chiaro
        case 5...6: return Color(red: 0.95, green: 0.65, blue: 0.35) // Arancione naturale
        case 7...8: return Color(red: 0.98, green: 0.7, blue: 0.4) // Arancione caldo
        case 9...10: return Color(red: 1.0, green: 0.75, blue: 0.45) // Arancione dorato
        default: return Color(red: 0.95, green: 0.65, blue: 0.35)
        }
    }
    
    private var foxSecondaryColor: Color {
        foxMainColor.opacity(0.8)
    }
    
    private var foxBellyColor: Color {
        Color(red: 0.96, green: 0.94, blue: 0.88) // Bianco crema naturale
    }
    
    private var eyeType: String {
        // Blink occasionale basato sulla fase
        if animationPhase == 2 { return "closed" }
        
        switch rating {
        case 1...2: return "sad"
        case 3...4: return "neutral"
        case 5...6: return "normal"
        case 7...8: return "happy"
        case 9...10: return "sparkle"
        default: return "normal"
        }
    }
    
    private var tailPosition: Double {
        // Movimento coda basato sulla fase
        switch animationPhase {
        case 0: return -25
        case 1: return -15
        case 2: return 15
        case 3: return 25
        default: return 0
        }
    }
    
    private var earRotation: Double {
        // Movimento orecchie basato sulla fase
        animationPhase % 2 == 0 ? 5 : -5
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Particelle naturali per rating alto (meno kawaii)
                if rating >= 8 {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 3, height: 3)
                            .offset(
                                x: CGFloat.random(in: -40...40),
                                y: CGFloat.random(in: -40...40)
                            )
                            .opacity(animationPhase % 2 == index % 2 ? 0.6 : 0.2)
                    }
                }
                
                // Corpo principale della volpe
                ZStack {
                    // Ombra
                    Ellipse()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 105, height: 80)
                        .offset(y: 5)
                    
                    // Corpo principale
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [foxMainColor, foxSecondaryColor, foxMainColor.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 95, height: 70)
                        .overlay(
                            Ellipse()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 35, height: 25)
                                .offset(x: -15, y: -15)
                        )
                    
                    // Pancia
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [foxBellyColor, foxBellyColor.opacity(0.8)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 30
                            )
                        )
                        .frame(width: 55, height: 40)
                        .offset(y: 10)
                    
                    // Orecchie con movimento subtile
                    HStack(spacing: 45) {
                        // Orecchio sinistro
                        ZStack {
                            Triangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 24, height: 30)
                                .offset(x: 1, y: 1)
                                .rotationEffect(.degrees(earRotation))
                            
                            Triangle()
                                .fill(
                                    LinearGradient(
                                        colors: [foxMainColor, foxSecondaryColor],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 24, height: 30)
                                .rotationEffect(.degrees(earRotation))
                            
                            Triangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.4, green: 0.2, blue: 0.15), Color(red: 0.3, green: 0.15, blue: 0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 14, height: 18)
                                .offset(y: 3)
                                .rotationEffect(.degrees(earRotation))
                        }
                        
                        // Orecchio destro
                        ZStack {
                            Triangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 24, height: 30)
                                .offset(x: -1, y: 1)
                                .rotationEffect(.degrees(-earRotation))
                            
                            Triangle()
                                .fill(
                                    LinearGradient(
                                        colors: [foxMainColor, foxSecondaryColor],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 24, height: 30)
                                .rotationEffect(.degrees(-earRotation))
                            
                            Triangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.4, green: 0.2, blue: 0.15), Color(red: 0.3, green: 0.15, blue: 0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 14, height: 18)
                                .offset(y: 3)
                                .rotationEffect(.degrees(-earRotation))
                        }
                    }
                    .offset(y: -42)
                    
                    // Faccia
                    VStack(spacing: 6) {
                        // Occhi
                        HStack(spacing: 20) {
                            AnimeEye(type: eyeType, isLeft: true)
                            AnimeEye(type: eyeType, isLeft: false)
                        }
                        .offset(y: -5)
                        
                        // Naso
                        Triangle()
                            .fill(Color.black)
                            .frame(width: 6, height: 5)
                            .rotationEffect(.degrees(180))
                        
                        // Bocca
                        AnimeMouth(rating: rating, animationPhase: animationPhase)
                        
                        // Guance naturali per rating alto
                        if rating >= 8 {
                            HStack(spacing: 25) {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color(red: 0.9, green: 0.7, blue: 0.5).opacity(0.4), Color.clear],
                                            center: .center,
                                            startRadius: 2,
                                            endRadius: 8
                                        )
                                    )
                                    .frame(width: 10, height: 10)
                                    .opacity(animationPhase % 2 == 0 ? 0.6 : 0.3)
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color(red: 0.9, green: 0.7, blue: 0.5).opacity(0.4), Color.clear],
                                            center: .center,
                                            startRadius: 2,
                                            endRadius: 8
                                        )
                                    )
                                    .frame(width: 10, height: 10)
                                    .opacity(animationPhase % 2 == 0 ? 0.6 : 0.3)
                            }
                            .offset(y: -12)
                        }
                    }
                    .offset(y: -5)
                }
                
                // Coda con movimento
                ZStack {
                    // Ombra coda
                    Ellipse()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 50, height: 22)
                        .rotationEffect(.degrees(tailPosition))
                        .offset(x: -45, y: 32)
                    
                    // Coda principale
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [foxMainColor, foxSecondaryColor, foxMainColor.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 48, height: 20)
                        .rotationEffect(.degrees(tailPosition))
                        .offset(x: -45, y: 28)
                    
                    // Punta coda bianca
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [foxBellyColor, foxBellyColor.opacity(0.9)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 15
                            )
                        )
                        .frame(width: 20, height: 14)
                        .rotationEffect(.degrees(tailPosition))
                        .offset(x: -58, y: 20)
                }
            }
            .frame(height: 140) // Aumentato per dare più spazio senza i cuori
            

        }
        // Animazione di entrata subtile (questa funziona nei widget)
        .onAppear {
            // Solo animazioni molto brevi e semplici
        }
    }
}

struct AnimeEye: View {
    let type: String
    let isLeft: Bool
    
    var body: some View {
        ZStack {
            if type == "closed" {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 18, height: 3)
            } else {
                // Base occhio
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 18, height: 16)
                    .overlay(
                        Ellipse()
                            .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                    )
                
                // Pupilla
                Group {
                    switch type {
                    case "sad":
                        ZStack {
                            Ellipse() // Occhi più naturali invece di cerchi perfetti
                                .fill(Color.black)
                                .frame(width: 7, height: 8)
                            
                            // Lacrime multiple di diverse dimensioni
                            VStack(spacing: 2) {
                                // Lacrima grande principale
                                Ellipse()
                                    .fill(Color.blue.opacity(0.7))
                                    .frame(width: 8, height: 10)
                                    .offset(y: 12)
                                
                                // Lacrima media
                                Circle()
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: 6, height: 6)
                                    .offset(x: -3, y: 18)
                                
                                // Lacrima piccola
                                Circle()
                                    .fill(Color.blue.opacity(0.5))
                                    .frame(width: 4, height: 4)
                                    .offset(x: 2, y: 22)
                            }
                        }
                    case "neutral":
                        Ellipse()
                            .fill(Color.black)
                            .frame(width: 6, height: 7)
                    case "normal":
                        ZStack {
                            Ellipse()
                                .fill(Color.black)
                                .frame(width: 8, height: 9)
                            Ellipse()
                                .fill(Color.white)
                                .frame(width: 2, height: 2)
                                .offset(x: -1.5, y: -1.5)
                        }
                    case "happy":
                        ZStack {
                            Ellipse()
                                .fill(Color.black)
                                .frame(width: 9, height: 10)
                            Ellipse()
                                .fill(Color.white)
                                .frame(width: 2.5, height: 2.5)
                                .offset(x: -2, y: -2)
                        }
                    case "sparkle":
                        ZStack {
                            Ellipse()
                                .fill(Color.black)
                                .frame(width: 9, height: 10)
                            Circle() // Riflesso naturale invece di stella
                                .fill(Color.white)
                                .frame(width: 3, height: 3)
                                .offset(x: -1.5, y: -1.5)
                        }
                    default:
                        Ellipse()
                            .fill(Color.black)
                            .frame(width: 8, height: 9)
                    }
                }
            }
        }
    }
}

struct AnimeMouth: View {
    let rating: Int
    let animationPhase: Int
    
    var body: some View {
        Group {
            switch rating {
            case 1...2:
                // BOCCA FELICE PER TRISTE (curva verso l'alto)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 4))
                    path.addCurve(to: CGPoint(x: 16, y: 4),
                                 control1: CGPoint(x: 4, y: 0),
                                 control2: CGPoint(x: 12, y: 0))
                }
                .stroke(Color.black, lineWidth: 2)
                .frame(width: 16, height: 8)
            case 3...4:
                Capsule()
                    .fill(Color.black)
                    .frame(width: 8, height: 2)
            case 5...6:
                Capsule()
                    .fill(Color.black)
                    .frame(width: 10, height: 2)
            case 7...8:
                // BOCCA TRISTE PER FELICE (curva verso il basso)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addCurve(to: CGPoint(x: 14, y: 0),
                                 control1: CGPoint(x: 3, y: 4),
                                 control2: CGPoint(x: 11, y: 4))
                }
                .stroke(Color.black, lineWidth: 2)
                .frame(width: 14, height: 4)
                .scaleEffect(animationPhase % 2 == 0 ? 1.1 : 1.0)
            case 9...10:
                // BOCCA TRISTE GRANDE PER MOLTO FELICE (curva verso il basso)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addCurve(to: CGPoint(x: 18, y: 0),
                                 control1: CGPoint(x: 4, y: 6),
                                 control2: CGPoint(x: 14, y: 6))
                }
                .stroke(Color.black, lineWidth: 2.5)
                .frame(width: 18, height: 6)
                .scaleEffect(animationPhase % 2 == 0 ? 1.15 : 1.0)
            default:
                Capsule()
                    .fill(Color.black)
                    .frame(width: 10, height: 2)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle - .pi / 2)) * radius
            let y = center.y + CGFloat(sin(angle - .pi / 2)) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct FoxWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            // Sfondo gradiente
            RadialGradient(
                colors: backgroundColors(for: entry.rating),
                center: .center,
                startRadius: 20,
                endRadius: 150
            )
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.clear, Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            AnimeFoxView(rating: entry.rating, animationPhase: entry.animationPhase)
        }
        .widgetURL(URL(string: "dailyfox://open"))
    }
    
    private func backgroundColors(for rating: Int) -> [Color] {
        switch rating {
        case 1...2: return [
            Color(red: 0.9, green: 0.85, blue: 0.8),
            Color(red: 0.85, green: 0.8, blue: 0.75),
            Color(red: 0.8, green: 0.75, blue: 0.7)
        ]
        case 3...4: return [
            Color(red: 0.92, green: 0.88, blue: 0.82),
            Color(red: 0.88, green: 0.84, blue: 0.78),
            Color(red: 0.84, green: 0.8, blue: 0.74)
        ]
        case 5...6: return [
            Color(red: 0.95, green: 0.92, blue: 0.85),
            Color(red: 0.9, green: 0.87, blue: 0.8),
            Color(red: 0.85, green: 0.82, blue: 0.75)
        ]
        case 7...8: return [
            Color(red: 0.92, green: 0.95, blue: 0.88),
            Color(red: 0.88, green: 0.9, blue: 0.84),
            Color(red: 0.84, green: 0.85, blue: 0.8)
        ]
        case 9...10: return [
            Color(red: 0.88, green: 0.95, blue: 0.92),
            Color(red: 0.84, green: 0.9, blue: 0.88),
            Color(red: 0.8, green: 0.85, blue: 0.84)
        ]
        default: return [
            Color(red: 0.9, green: 0.9, blue: 0.9),
            Color(red: 0.85, green: 0.85, blue: 0.85),
            Color(red: 0.8, green: 0.8, blue: 0.8)
        ]
        }
    }
}

struct FoxWidget: Widget {
    let kind: String = "FoxWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                FoxWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                FoxWidgetEntryView(entry: entry)
                    .background()
            }
        }
        .configurationDisplayName("DailyFox🦊")

        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    FoxWidget()
} timeline: {
    SimpleEntry(date: .now, rating: 8, animationPhase: 0)
    SimpleEntry(date: .now, rating: 8, animationPhase: 1)
    SimpleEntry(date: .now, rating: 8, animationPhase: 2)
    SimpleEntry(date: .now, rating: 8, animationPhase: 3)
}