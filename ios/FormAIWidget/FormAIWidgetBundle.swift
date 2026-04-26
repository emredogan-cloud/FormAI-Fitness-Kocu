// Phase 55 · WidgetBundle entry point.
//
// The Live Activity's `WorkoutActivityWidget` (defined in
// ios/FormAILiveActivity/WorkoutLiveActivityView.swift) must live in
// the SAME widget extension target as the home-screen widget for
// `live_activities` package to find it. So this bundle declares both
// — `FormAIWidget` (timeline-based home-screen tile) and
// `WorkoutActivityWidget` (ActivityKit Live Activity).

import SwiftUI
import WidgetKit

@main
struct FormAIWidgetBundle: WidgetBundle {
    var body: some Widget {
        FormAIWidget()
        if #available(iOS 16.1, *) {
            WorkoutActivityWidget()
        }
    }
}
