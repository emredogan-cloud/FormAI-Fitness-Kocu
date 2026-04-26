// Phase 55 · FormAI Home-Screen Widget (iOS).
//
// This file is the source for the `FormAIWidget` Widget Extension target.
// It must be compiled by an extension target that you add to the Xcode
// project (see PHASE_55_NATIVE_SETUP.md in the project root for the
// Xcode click-through). The Flutter `home_widget` package writes the
// keys we read here into the shared App Group `UserDefaults` suite —
// this file's job is to render them into a small / medium widget.
//
// Keys read here MUST mirror the constants in
// lib/core/services/widget_sync_service.dart. Bumping a key on one
// side without the other = a silently empty widget.

import WidgetKit
import SwiftUI

// MARK: - App Group bridge

private enum AppGroup {
    /// Must match `WidgetSyncService._appGroupId` in Flutter and the
    /// `App Groups` capability on both the Runner and FormAIWidget
    /// targets in Xcode (Signing & Capabilities).
    static let id = "group.app.formai.shared"
    static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}

private enum WidgetKey {
    static let taskName       = "today_task_name"
    static let subtitle       = "today_task_subtitle"
    static let progressPct    = "progress_percent"
    static let streak         = "streak_count"
    static let completedDays  = "completed_days"
    static let totalDays      = "total_days"
    static let deepLink       = "deep_link"
    static let updatedAtMs    = "updated_at_ms"
}

// MARK: - Entry

struct FormAIEntry: TimelineEntry {
    let date: Date
    let taskName: String
    let subtitle: String
    let progressPercent: Int
    let streakCount: Int
    let completedDays: Int
    let totalDays: Int
    let deepLink: URL

    static let placeholder = FormAIEntry(
        date: .now,
        taskName: "Bugün · Karın Yakıcı",
        subtitle: "5 egzersiz · 18 dk",
        progressPercent: 35,
        streakCount: 4,
        completedDays: 10,
        totalDays: 30,
        deepLink: URL(string: "formai://workout/today")!
    )

    static func read(from defaults: UserDefaults?) -> FormAIEntry {
        guard let d = defaults else { return .placeholder }
        let task = d.string(forKey: WidgetKey.taskName) ?? "Hazır mısın?"
        let sub = d.string(forKey: WidgetKey.subtitle) ?? "Antrenmanı başlat"
        let pct = d.object(forKey: WidgetKey.progressPct) as? Int ?? 0
        let streak = d.object(forKey: WidgetKey.streak) as? Int ?? 0
        let done = d.object(forKey: WidgetKey.completedDays) as? Int ?? 0
        let total = d.object(forKey: WidgetKey.totalDays) as? Int ?? 30
        let link = d.string(forKey: WidgetKey.deepLink)
            ?? "formai://workout/today"
        return FormAIEntry(
            date: .now,
            taskName: task,
            subtitle: sub,
            progressPercent: pct,
            streakCount: streak,
            completedDays: done,
            totalDays: total,
            deepLink: URL(string: link) ?? URL(string: "formai://workout/today")!
        )
    }
}

// MARK: - Provider

struct FormAIProvider: TimelineProvider {
    func placeholder(in context: Context) -> FormAIEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (FormAIEntry) -> Void) {
        completion(FormAIEntry.read(from: AppGroup.defaults))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FormAIEntry>) -> Void) {
        // Phase 55 · timeline policy. We always return a single entry
        // anchored to "now" and let `HomeWidget.updateWidget(...)` from
        // the Flutter side ring the OS for fresh content. The 30-min
        // refresh fallback is a belt-and-braces guard so the tile
        // never goes more than half an hour stale even if the
        // `updateWidget` call fails (offline, killed app).
        let entry = FormAIEntry.read(from: AppGroup.defaults)
        let nextRefresh = Date().addingTimeInterval(60 * 30)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Brand palette

private extension Color {
    static let brandNeon       = Color(red: 0.55, green: 0.36, blue: 1.00) // #8E5BFF
    static let brandNeonAccent = Color(red: 0.30, green: 0.65, blue: 1.00) // #4DA6FF
    static let brandSurface    = Color(red: 0.05, green: 0.04, blue: 0.10) // #0E0A1A
    static let brandSurface2   = Color(red: 0.10, green: 0.05, blue: 0.20) // #1A0D33
    static let brandText       = Color.white
    static let brandSubtext    = Color.white.opacity(0.65)
}

// MARK: - View

struct FormAIWidgetEntryView: View {
    var entry: FormAIEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandSurface2, Color.brandSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: small
            }
        }
        // Tap anywhere → deep link. iOS 17+ uses widgetURL; older OS
        // versions fall through to the default tap behaviour which
        // opens the parent app at its launch URL.
        .widgetURL(entry.deepLink)
    }

    // MARK: small (2x2)
    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.brandNeon)
                    .frame(width: 10, height: 10)
                Text("FormAI")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(Color.brandSubtext)
                    .tracking(2)
                Spacer()
            }
            Spacer(minLength: 0)
            ProgressRing(percent: entry.progressPercent)
                .frame(width: 64, height: 64)
            Spacer(minLength: 0)
            Text(entry.taskName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.brandText)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.caption2)
                Text("\(entry.streakCount) gün seri")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.brandSubtext)
            }
        }
        .padding(14)
    }

    // MARK: medium (4x2)
    private var medium: some View {
        HStack(alignment: .center, spacing: 16) {
            ProgressRing(percent: entry.progressPercent)
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(Color.brandNeon).frame(width: 8, height: 8)
                    Text("FormAI")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .tracking(2)
                        .foregroundColor(Color.brandSubtext)
                }
                Text(entry.taskName)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.brandText)
                    .lineLimit(1)
                Text(entry.subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color.brandSubtext)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Label("\(entry.streakCount) gün", systemImage: "flame.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.brandNeon)
                    Text("\(entry.completedDays)/\(entry.totalDays)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.brandSubtext)
                    Spacer()
                    StartCTA()
                }
            }
        }
        .padding(16)
    }
}

private struct ProgressRing: View {
    let percent: Int
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 0), 100)) / 100.0)
                .stroke(
                    LinearGradient(
                        colors: [.brandNeonAccent, .brandNeon],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("%\(percent)")
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(.brandText)
            }
        }
    }
}

private struct StartCTA: View {
    var body: some View {
        Text("Başlat")
            .font(.caption)
            .fontWeight(.heavy)
            .tracking(0.5)
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(red: 0.22, green: 1.00, blue: 0.08))
            )
    }
}

// MARK: - Widget bundle entry

struct FormAIWidget: Widget {
    let kind: String = "FormAIWidget" // Must match `_iosWidgetName` in Flutter.

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FormAIProvider()) { entry in
            FormAIWidgetEntryView(entry: entry)
                .containerBackground(.brandSurface, for: .widget)
        }
        .configurationDisplayName("FormAI · Bugün")
        .description("Bugünkü antrenman görevini, ilerlemeni ve serini gör.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
