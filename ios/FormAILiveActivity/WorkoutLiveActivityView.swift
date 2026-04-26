// Phase 55 · SwiftUI presentation for the workout Live Activity.
//
// Implements all four Dynamic Island states (compact leading,
// compact trailing, minimal, expanded) plus the Lock Screen / Banner
// presentation. Compiled into the FormAIWidget extension target — the
// `WidgetBundle` in FormAIWidgetBundle.swift declares both this
// activity and the home-screen widget, so a single extension target
// covers both surfaces.

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
public struct WorkoutActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            // Lock-screen / Banner presentation.
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.05, green: 0.04, blue: 0.10))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    LeadingExpanded(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingExpanded(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    CenterExpanded(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BottomExpanded(state: context.state)
                }
            } compactLeading: {
                CompactLeading(state: context.state)
            } compactTrailing: {
                CompactTrailing(state: context.state)
            } minimal: {
                Minimal(state: context.state)
            }
            // Tapping the Dynamic Island deep-links into the live workout
            // session in FormAI.
            .widgetURL(URL(string: context.state.deepLink))
            .keylineTint(.purple)
        }
    }
}

// MARK: - Brand palette (kept in-sync with FormAIWidget.swift).

@available(iOS 16.1, *)
private extension Color {
    static let brandNeon       = Color(red: 0.55, green: 0.36, blue: 1.00)
    static let brandNeonAccent = Color(red: 0.30, green: 0.65, blue: 1.00)
    static let brandRest       = Color(red: 1.00, green: 0.55, blue: 0.30)
}

// MARK: - Lock Screen / Banner

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ProgressBubble(progress: state.progress, isResting: state.isResting)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(state.isResting ? "DİNLEN" : "SET")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .tracking(2)
                        .foregroundColor(state.isResting ? .brandRest : .brandNeon)
                    Text(state.setLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.65))
                }
                Text(state.exerciseName)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Egzersiz \(state.exerciseIndex + 1) / \(state.totalExercises)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            CountdownPill(state: state)
        }
        .padding(16)
    }
}

// MARK: - Dynamic Island regions

@available(iOS 16.1, *)
private struct LeadingExpanded: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        ProgressBubble(progress: state.progress, isResting: state.isResting)
            .frame(width: 56, height: 56)
            .padding(.leading, 4)
    }
}

@available(iOS 16.1, *)
private struct TrailingExpanded: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        CountdownPill(state: state)
    }
}

@available(iOS 16.1, *)
private struct CenterExpanded: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.exerciseName)
                .font(.headline)
                .fontWeight(.heavy)
                .lineLimit(1)
                .foregroundColor(.white)
            Text(state.setLabel)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

@available(iOS 16.1, *)
private struct BottomExpanded: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        HStack {
            Image(systemName: state.isResting ? "pause.circle.fill" : "bolt.fill")
                .foregroundColor(state.isResting ? .brandRest : .brandNeon)
            Text(state.isResting
                 ? "Dinlenme · \(state.restSecondsRemaining)s"
                 : "Egzersiz \(state.exerciseIndex + 1) / \(state.totalExercises)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text("Aç")
                .font(.caption)
                .fontWeight(.heavy)
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white))
        }
    }
}

@available(iOS 16.1, *)
private struct CompactLeading: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        // Small ring or rest icon in the leading slot.
        if state.isResting {
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.brandRest)
        } else {
            ProgressBubble(progress: state.progress, isResting: false)
                .frame(width: 18, height: 18)
        }
    }
}

@available(iOS 16.1, *)
private struct CompactTrailing: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        Text(state.isResting
             ? "\(state.restSecondsRemaining)s"
             : state.setLabel)
            .font(.caption2)
            .fontWeight(.heavy)
            .foregroundColor(.white)
    }
}

@available(iOS 16.1, *)
private struct Minimal: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        Image(systemName: state.isResting ? "pause.circle.fill" : "bolt.fill")
            .foregroundColor(state.isResting ? .brandRest : .brandNeon)
    }
}

// MARK: - Shared bits

@available(iOS 16.1, *)
private struct ProgressBubble: View {
    let progress: Double
    let isResting: Bool
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    LinearGradient(
                        colors: isResting
                            ? [.brandRest, .brandRest.opacity(0.6)]
                            : [.brandNeonAccent, .brandNeon],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: isResting ? "pause.fill" : "bolt.fill")
                .foregroundColor(.white)
                .font(.caption)
        }
    }
}

@available(iOS 16.1, *)
private struct CountdownPill: View {
    let state: WorkoutAttributes.ContentState
    var body: some View {
        VStack(spacing: 0) {
            if state.isResting {
                Text("\(state.restSecondsRemaining)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(.brandRest)
                Text("DİNLEN")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.brandRest.opacity(0.85))
            } else {
                Text(state.setLabel)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.brandNeon)
                Text("AKTİF")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.brandNeon.opacity(0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    (state.isResting ? Color.brandRest : Color.brandNeon)
                        .opacity(0.55),
                    lineWidth: 1
                )
        )
    }
}
