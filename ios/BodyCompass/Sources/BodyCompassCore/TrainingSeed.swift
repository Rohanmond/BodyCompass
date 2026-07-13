import Foundation

// MARK: - Setup questionnaire

public enum TrainingExperience: String, Codable, CaseIterable, Sendable {
    case beginner
    case intermediate
    case advanced

    public var displayName: String { rawValue.capitalized }

    public var description: String {
        switch self {
        case .beginner: return "Under a year of consistent lifting"
        case .intermediate: return "1–3 years of consistent lifting"
        case .advanced: return "3+ years of structured training"
        }
    }
}

public enum EquipmentAccess: String, Codable, CaseIterable, Sendable {
    case fullGym
    case dumbbellsOnly
    case minimal

    public var displayName: String {
        switch self {
        case .fullGym: return "Full gym"
        case .dumbbellsOnly: return "Dumbbells only"
        case .minimal: return "Minimal / bodyweight"
        }
    }
}

/// Answers collected before detailed prescriptions are generated. The app
/// refuses to invent sets, exercises, or swim durations without this context.
public struct TrainingSetup: Codable, Equatable, Sendable {
    public var experience: TrainingExperience
    public var equipment: EquipmentAccess
    /// Free-text injuries or limitations, e.g. "left shoulder impingement".
    public var limitations: String
    public var swimMinutes: Int
    public var swimIntensity: SwimIntensity

    public init(
        experience: TrainingExperience,
        equipment: EquipmentAccess,
        limitations: String = "",
        swimMinutes: Int = 30,
        swimIntensity: SwimIntensity = .easy
    ) {
        self.experience = experience
        self.equipment = equipment
        self.limitations = limitations
        self.swimMinutes = swimMinutes
        self.swimIntensity = swimIntensity
    }

    public var hasLimitations: Bool {
        !limitations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Seeder

/// Builds the user's starting weekly split:
/// Mon chest+triceps, Tue back+biceps then swim, Wed legs, Thu swim,
/// Fri upper body, Sat arms then swim, Sun swim.
///
/// Two stages on purpose. `skeleton()` is the split with session names only —
/// enough to see the week. `detailed(setup:)` fills in exercises, sets, rep
/// ranges, effort, and rest, and only runs once the setup questionnaire has
/// been answered. Neither stage ever assigns a starting weight.
public enum TrainingRoutineSeeder {
    public static func skeleton() -> TrainingRoutine {
        TrainingRoutine(
            version: 1,
            source: .seed,
            changeSummary: "Starting weekly split",
            days: splitDays(detail: nil)
        )
    }

    public static func detailed(setup: TrainingSetup, version: Int) -> TrainingRoutine {
        TrainingRoutine(
            version: version,
            source: .seed,
            changeSummary: "Detailed prescriptions generated from your setup",
            days: splitDays(detail: setup)
        )
    }

    private static func splitDays(detail setup: TrainingSetup?) -> [TrainingDay] {
        let swim: (String) -> TrainingSession = { title in
            var session = TrainingSession(title: title, kind: .swimming)
            if let setup {
                session.swimPlan = SwimPlan(targetMinutes: setup.swimMinutes, intensity: setup.swimIntensity)
                session.notes = "Log duration, distance if the pool tracks it, and how hard it felt."
            }
            return session
        }

        return [
            TrainingDay(weekday: .monday, sessions: [
                strength("Chest + triceps", ["Chest", "Triceps"], setup, .chestTriceps)
            ]),
            TrainingDay(weekday: .tuesday, sessions: [
                strength("Back + biceps", ["Back", "Biceps"], setup, .backBiceps),
                swim("Swimming")
            ]),
            TrainingDay(weekday: .wednesday, sessions: [
                strength("Legs", ["Quads", "Hamstrings", "Glutes", "Calves"], setup, .legs)
            ]),
            TrainingDay(weekday: .thursday, sessions: [
                swim("Swimming")
            ]),
            TrainingDay(weekday: .friday, sessions: [
                strength("Upper body", ["Chest", "Back", "Shoulders"], setup, .upperBody)
            ]),
            TrainingDay(weekday: .saturday, sessions: [
                strength("Arms", ["Biceps", "Triceps", "Shoulders"], setup, .arms),
                swim("Swimming")
            ]),
            TrainingDay(weekday: .sunday, sessions: [
                swim("Swimming")
            ])
        ]
    }

    private static func strength(
        _ title: String,
        _ muscles: [String],
        _ setup: TrainingSetup?,
        _ template: SessionTemplate
    ) -> TrainingSession {
        var session = TrainingSession(title: title, kind: .strength, muscleGroups: muscles)
        guard let setup else { return session }
        session.exercises = template.exercises(for: setup)
        if setup.hasLimitations {
            session.notes = "You noted: \(setup.limitations). Skip or substitute anything that provokes it."
        }
        return session
    }
}

// MARK: - Session templates

/// Exercise menus for each session of the split, adapted to available
/// equipment and experience. Content lives here in one place so a future
/// Coach model can propose deltas against a known baseline.
private enum SessionTemplate {
    case chestTriceps, backBiceps, legs, upperBody, arms

    func exercises(for setup: TrainingSetup) -> [ExercisePrescription] {
        let names = exerciseNames(for: setup.equipment)
        return names.map { entry in
            ExercisePrescription(
                name: entry.name,
                warmUp: entry.isFirstCompound
                    ? "2–3 lighter ramp-up sets before your working sets. Start empty-bar/light and add gradually."
                    : "One lighter feel set if the muscle is cold.",
                workingSets: setup.experience == .beginner ? 3 : entry.compound ? 4 : 3,
                repRangeLower: entry.compound ? 6 : 10,
                repRangeUpper: entry.compound ? 10 : 15,
                targetRIR: setup.experience == .beginner ? 3 : 2,
                restSeconds: entry.compound ? 150 : 90,
                techniqueNotes: entry.note,
                substitutions: entry.substitutions
            )
        }
    }

    private struct Entry {
        let name: String
        let compound: Bool
        let isFirstCompound: Bool
        let note: String
        let substitutions: [String]

        init(_ name: String, compound: Bool = false, first: Bool = false, note: String = "", subs: [String] = []) {
            self.name = name
            self.compound = compound
            self.isFirstCompound = first
            self.note = note
            self.substitutions = subs
        }
    }

    private func exerciseNames(for equipment: EquipmentAccess) -> [Entry] {
        switch (self, equipment) {
        case (.chestTriceps, .fullGym):
            return [
                Entry("Barbell bench press", compound: true, first: true,
                      note: "Feet planted, slight arch, bar to mid-chest under control.",
                      subs: ["Dumbbell bench press", "Machine chest press"]),
                Entry("Incline dumbbell press", compound: true,
                      note: "30–45° bench. Stop just short of shoulder strain at the bottom.",
                      subs: ["Incline machine press"]),
                Entry("Cable fly", note: "Squeeze the stretch; don't chase heavy weight here.",
                      subs: ["Pec-deck", "Dumbbell fly"]),
                Entry("Cable triceps pushdown", note: "Elbows pinned to your sides.",
                      subs: ["Rope pushdown"]),
                Entry("Overhead cable triceps extension",
                      note: "Full stretch behind the head; light and strict.",
                      subs: ["Dumbbell overhead extension"])
            ]
        case (.chestTriceps, .dumbbellsOnly), (.chestTriceps, .minimal):
            return [
                Entry("Dumbbell bench press", compound: true, first: true,
                      note: "Floor press works if you have no bench.",
                      subs: ["Push-up (weighted if easy)"]),
                Entry("Incline dumbbell press", compound: true,
                      note: "Prop the bench or use decline push-ups as fallback.",
                      subs: ["Pike push-up"]),
                Entry("Dumbbell fly", note: "Slight elbow bend, stop at a comfortable stretch.",
                      subs: ["Deficit push-up"]),
                Entry("Dumbbell overhead triceps extension",
                      note: "Both hands on one dumbbell, elbows tucked.",
                      subs: ["Close-grip push-up", "Bench dips"]),
                Entry("Close-grip push-up", note: "Hands under shoulders, elbows brushing ribs.")
            ]
        case (.backBiceps, .fullGym):
            return [
                Entry("Lat pulldown", compound: true, first: true,
                      note: "Pull to the collarbone, no swinging.",
                      subs: ["Pull-up", "Assisted pull-up"]),
                Entry("Seated cable row", compound: true,
                      note: "Chest tall, squeeze the shoulder blades together.",
                      subs: ["Chest-supported machine row"]),
                Entry("One-arm dumbbell row", compound: true,
                      note: "Brace on the bench; pull to the hip, not the armpit.",
                      subs: ["Barbell row"]),
                Entry("Barbell curl", note: "No hip swing; control the way down.",
                      subs: ["EZ-bar curl", "Dumbbell curl"]),
                Entry("Incline dumbbell curl", note: "Long stretch at the bottom, strict tempo.",
                      subs: ["Cable curl"])
            ]
        case (.backBiceps, .dumbbellsOnly), (.backBiceps, .minimal):
            return [
                Entry("One-arm dumbbell row", compound: true, first: true,
                      note: "Brace on a bench or chair; pull to the hip.",
                      subs: ["Inverted row under a table"]),
                Entry("Chest-supported dumbbell row", compound: true,
                      note: "Lie chest-down on an incline; removes lower-back strain.",
                      subs: ["Band row"]),
                Entry("Dumbbell pullover", note: "Slight elbow bend, feel it in the lats.",
                      subs: ["Band pulldown"]),
                Entry("Dumbbell curl", note: "Alternate arms, no swinging.",
                      subs: ["Band curl"]),
                Entry("Hammer curl", note: "Neutral grip hits the forearms too.")
            ]
        case (.legs, .fullGym):
            return [
                Entry("Barbell back squat", compound: true, first: true,
                      note: "Depth you can control; brace hard before each rep.",
                      subs: ["Leg press", "Goblet squat"]),
                Entry("Romanian deadlift", compound: true,
                      note: "Hinge at the hips, soft knees, flat back.",
                      subs: ["Dumbbell RDL", "Lying leg curl"]),
                Entry("Leg press", compound: true,
                      note: "Don't let the lower back roll off the pad.",
                      subs: ["Hack squat", "Split squat"]),
                Entry("Lying leg curl", note: "Slow negatives; hamstrings respond well to them.",
                      subs: ["Seated leg curl"]),
                Entry("Standing calf raise", note: "Pause at the stretch, full squeeze at the top.",
                      subs: ["Seated calf raise"])
            ]
        case (.legs, .dumbbellsOnly), (.legs, .minimal):
            return [
                Entry("Goblet squat", compound: true, first: true,
                      note: "Dumbbell at the chest, sit between the hips.",
                      subs: ["Bodyweight squat (slow tempo)"]),
                Entry("Dumbbell Romanian deadlift", compound: true,
                      note: "Hinge, flat back, feel the hamstrings load.",
                      subs: ["Single-leg RDL"]),
                Entry("Bulgarian split squat", compound: true,
                      note: "Rear foot on a chair; brutal and effective.",
                      subs: ["Reverse lunge"]),
                Entry("Dumbbell step-up", note: "Knee-height step; drive through the front heel.",
                      subs: ["Walking lunge"]),
                Entry("Single-leg calf raise", note: "On a step for full range; hold a dumbbell when easy.")
            ]
        case (.upperBody, .fullGym):
            return [
                Entry("Overhead barbell press", compound: true, first: true,
                      note: "Glutes tight, ribs down; press slightly back over the head.",
                      subs: ["Seated dumbbell press", "Machine shoulder press"]),
                Entry("Weighted pull-up or lat pulldown", compound: true,
                      note: "Add weight only when strict bodyweight reps exceed the range.",
                      subs: ["Assisted pull-up"]),
                Entry("Flat dumbbell press", compound: true,
                      note: "Lighter than Monday; this is the second chest exposure of the week.",
                      subs: ["Machine chest press"]),
                Entry("Cable lateral raise", note: "Lean slightly away; lead with the elbow.",
                      subs: ["Dumbbell lateral raise"]),
                Entry("Face pull", note: "Pull to the forehead, thumbs back; great for shoulder health.",
                      subs: ["Reverse pec-deck"])
            ]
        case (.upperBody, .dumbbellsOnly), (.upperBody, .minimal):
            return [
                Entry("Seated dumbbell shoulder press", compound: true, first: true,
                      note: "Back supported if possible; don't flare excessively.",
                      subs: ["Pike push-up"]),
                Entry("Chest-supported dumbbell row", compound: true,
                      note: "Second back exposure of the week; keep it strict.",
                      subs: ["Inverted row"]),
                Entry("Flat dumbbell press", compound: true,
                      note: "Lighter than Monday's pressing.",
                      subs: ["Push-up"]),
                Entry("Dumbbell lateral raise", note: "Lead with the elbows, no shrugging.",
                      subs: ["Band lateral raise"]),
                Entry("Rear-delt fly", note: "Chest down, light weight, high control.",
                      subs: ["Band pull-apart"])
            ]
        case (.arms, .fullGym):
            return [
                Entry("Close-grip bench press", compound: true, first: true,
                      note: "Grip just inside shoulder width; elbows tucked.",
                      subs: ["Machine dip"]),
                Entry("EZ-bar curl", note: "Strict; the bar path should be a smooth arc.",
                      subs: ["Barbell curl"]),
                Entry("Cable rope pushdown", note: "Spread the rope at the bottom.",
                      subs: ["Straight-bar pushdown"]),
                Entry("Incline dumbbell curl", note: "Full stretch; keep shoulders back.",
                      subs: ["Preacher curl"]),
                Entry("Dumbbell lateral raise", note: "Extra shoulder volume while arms rest between sets.",
                      subs: ["Cable lateral raise"])
            ]
        case (.arms, .dumbbellsOnly), (.arms, .minimal):
            return [
                Entry("Close-grip push-up", compound: true, first: true,
                      note: "Elevate feet once bodyweight reps exceed the range.",
                      subs: ["Bench dips"]),
                Entry("Dumbbell curl", note: "Alternate arms, strict form.",
                      subs: ["Band curl"]),
                Entry("Dumbbell overhead triceps extension",
                      note: "Both hands on one bell, elbows close to the ears.",
                      subs: ["Close-grip push-up"]),
                Entry("Hammer curl", note: "Neutral grip; slow negatives.",
                      subs: ["Towel curl"]),
                Entry("Dumbbell lateral raise", note: "Light weight, high control.",
                      subs: ["Band lateral raise"])
            ]
        }
    }
}
