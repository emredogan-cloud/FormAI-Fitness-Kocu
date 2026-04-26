// Phase 55 · ActivityKit attributes for the workout Live Activity.
//
// The `live_activities` Flutter plugin sends payload maps; on the
// Swift side it routes those payloads through the App Group file
// service into a JSON file the activity reads at update time. The
// `ContentState` here MUST match the keys produced by
// `WorkoutLiveActivityService._payload` in
// `lib/core/services/live_activity_service.dart` exactly — bumping a
// key on one side requires bumping it on the other.
//
// `ActivityAttributes` are the immutable per-activity attributes
// (set at create time, never mutated). `ContentState` is everything
// that changes set-to-set.

import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct WorkoutAttributes: ActivityAttributes {
    public typealias WorkoutContentState = ContentState

    public struct ContentState: Codable, Hashable {
        public var dayNumber: Int
        public var exerciseName: String
        public var setLabel: String        // pre-formatted "Set 2/4"
        public var setIndex: Int
        public var totalSets: Int
        public var exerciseIndex: Int
        public var totalExercises: Int
        public var progress: Double        // 0.0 … 1.0
        public var elapsedSeconds: Int
        public var isResting: Bool
        public var restSecondsRemaining: Int
        public var deepLink: String

        public init(
            dayNumber: Int,
            exerciseName: String,
            setLabel: String,
            setIndex: Int,
            totalSets: Int,
            exerciseIndex: Int,
            totalExercises: Int,
            progress: Double,
            elapsedSeconds: Int,
            isResting: Bool,
            restSecondsRemaining: Int,
            deepLink: String
        ) {
            self.dayNumber = dayNumber
            self.exerciseName = exerciseName
            self.setLabel = setLabel
            self.setIndex = setIndex
            self.totalSets = totalSets
            self.exerciseIndex = exerciseIndex
            self.totalExercises = totalExercises
            self.progress = progress
            self.elapsedSeconds = elapsedSeconds
            self.isResting = isResting
            self.restSecondsRemaining = restSecondsRemaining
            self.deepLink = deepLink
        }
    }

    // No immutable attributes — every per-activity field can change as
    // the user progresses. This empty initialiser is intentional.
    public init() {}
}
