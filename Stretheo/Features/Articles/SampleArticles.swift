//
//  SampleArticles.swift
//  Stretheo
//
//  Bundled wellness articles seeded when the local article store is empty.
//

import Foundation

enum SampleArticles {
    struct ArticleSeedData: Sendable {
        let cloudKitRecordID: String
        let title: String
        let category: String
        let summary: String
        let content: String
        let author: String
        let publishedDate: Date
        let isFeatured: Bool
    }

    /// Whole-percent display of algorithm weights (same rounding as onboarding copy).
    private static var hrvWeightPercent: Int {
        Int((StressAlgorithmWeights.hrv * 100).rounded())
    }

    private static var sleepWeightPercent: Int {
        Int((StressAlgorithmWeights.sleep * 100).rounded())
    }

    private static var activityTemperatureWeightPercent: Int {
        Int((StressAlgorithmWeights.activityTemperature * 100).rounded())
    }

    static var all: [ArticleSeedData] { [
        ArticleSeedData(
            cloudKitRecordID: "sample-001",
            title: "Understanding HRV: Your Body's Stress Barometer",
            category: "stress",
            summary: "Heart rate variability is one of the most reliable indicators of stress and recovery. Learn what your HRV numbers actually mean.",
            content: """
Heart rate variability (HRV) measures the variation in time between consecutive heartbeats. Unlike heart rate, which counts beats per minute, HRV captures the subtle fluctuations between each beat — and those fluctuations tell a surprisingly rich story about your nervous system.

A high HRV generally indicates that your autonomic nervous system is flexible and responsive, able to shift smoothly between activation and recovery. A low HRV often signals that your body is under strain — whether from physical exertion, psychological stress, poor sleep, or illness.

HRV is measured in milliseconds. The SDNN metric (standard deviation of normal-to-normal intervals) is one of the most common. Most healthy adults have resting SDNN values between 20ms and 70ms, though this varies significantly with age, fitness level, and genetics. What matters most is your personal baseline — not comparison to population averages.

Stretheo tracks your HRV continuously through Apple Watch and uses it as the primary input to the stress algorithm, weighted at \(hrvWeightPercent)% of the total score. When your HRV drops below your personal baseline, it's one of the earliest signs that your body is managing more stress than usual.

Practical steps to improve your HRV: consistent sleep timing, slow diaphragmatic breathing, regular moderate exercise, and reducing alcohol consumption have all been shown in research to increase HRV over time.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-7 * 24 * 3600),
            isFeatured: true
        ),
        ArticleSeedData(
            cloudKitRecordID: "sample-002",
            title: "The Science Behind Box Breathing",
            category: "breathing",
            summary: "Used by Navy SEALs and surgeons under pressure, box breathing is one of the most researched techniques for rapid stress reduction.",
            content: """
Box breathing — four equal phases of inhale, hold, exhale, hold, each lasting four seconds — has an unusually strong evidence base for such a simple technique.

The mechanism is well understood. Slow, paced breathing at around five to six breaths per minute stimulates the vagus nerve, shifting the autonomic nervous system toward parasympathetic dominance. This is the "rest and digest" state: heart rate slows, blood pressure drops, cortisol levels fall, and cognitive function sharpens.

The box pattern specifically creates a rhythmic oscillation in heart rate that synchronises with respiration — a phenomenon called respiratory sinus arrhythmia. This synchronisation maximises heart rate variability, which Stretheo measures as a proxy for recovery capacity.

Research on military and emergency personnel — populations under extreme and sustained stress — has consistently found that regular box breathing practice reduces baseline anxiety, improves decision-making under pressure, and accelerates recovery between high-stress events.

Stretheo's implementation follows the standard 4-4-4-4 pattern. For best results, practice for five minutes daily rather than only during acute stress. The cumulative training effect on your nervous system is significantly greater than on-demand use alone.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-5 * 24 * 3600),
            isFeatured: false
        ),
        ArticleSeedData(
            cloudKitRecordID: "sample-003",
            title: "Why Sleep Is the Foundation of Stress Resilience",
            category: "sleep",
            summary: "Even one night of poor sleep measurably increases cortisol, reduces HRV, and impairs emotional regulation the following day.",
            content: """
Sleep is not passive recovery — it is an active biological process that repairs the stress response system itself. During deep sleep, the brain clears metabolic waste, consolidates emotional memories, and resets the hypothalamic-pituitary-adrenal (HPA) axis, which governs the cortisol stress response.

When sleep is cut short or fragmented, the HPA axis remains in a heightened state. Cortisol levels the following day are measurably elevated. Emotional reactivity increases — the amygdala, which processes threat responses, becomes hyperactive while the prefrontal cortex, which moderates those responses, becomes underactive. The result is a nervous system that overreacts to minor stressors and recovers more slowly from major ones.

Stretheo captures sleep duration and quality through HealthKit and uses both as inputs to the stress algorithm, contributing \(sleepWeightPercent)% of the total score. Consistently short sleep (under six hours) correlates strongly with elevated stress scores across the following day, a pattern that becomes visible in the History tab over time.

The most evidence-supported sleep hygiene practices: keep a consistent wake time regardless of when you fall asleep, keep the bedroom cool and dark, avoid screens for 30 minutes before bed, and avoid alcohol in the evening — it fragments sleep architecture even when it helps you fall asleep initially.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-3 * 24 * 3600),
            isFeatured: false
        ),
        ArticleSeedData(
            cloudKitRecordID: "sample-004",
            title: "Coherent Breathing: The 5-Breath Technique That Maximises HRV",
            category: "breathing",
            summary: "Breathing at exactly five breaths per minute triggers a resonance effect in the cardiovascular system that measurably boosts heart rate variability.",
            content: """
Coherent breathing, also called resonance breathing, is built on a specific physiological phenomenon: when breathing rate matches the resonant frequency of the cardiovascular system — approximately 0.1 Hz, or five to six breaths per minute — heart rate variability reaches its maximum possible value for that individual.

This resonance effect is not metaphorical. It is a measurable, reproducible cardiovascular response that has been documented in peer-reviewed research by Dr. Richard Gevirtz, Dr. Paul Lehrer, and others over several decades. At resonance frequency, the oscillations in heart rate caused by breathing (respiratory sinus arrhythmia) synchronise with the oscillations caused by blood pressure regulation (Mayer waves), producing constructive interference — the HRV equivalent of two waves combining to form a larger wave.

The practical implication: five minutes of coherent breathing before a stressful event or after a difficult day produces a measurable shift in autonomic balance that persists beyond the practice session. Regular daily practice has been shown to raise resting HRV baseline over weeks.

Stretheo's coherent breathing guide targets five breaths per minute — a five-second inhale and a five-second exhale, with no holds. The simplicity of the pattern makes it the most accessible of the three techniques for sustained daily practice.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-2 * 24 * 3600),
            isFeatured: true
        ),
        ArticleSeedData(
            cloudKitRecordID: "sample-005",
            title: "Reading Your Stress Patterns: What the History Tab Tells You",
            category: "stress",
            summary: "The most valuable stress data is not any single reading — it is the pattern across days and weeks that reveals your personal stress profile.",
            content: """
A single stress measurement is a snapshot. The History tab is the film reel. The difference matters enormously for how you interpret and act on your data.

Most people have predictable stress rhythms that become visible only over time. Common patterns include: elevated stress on weekday mornings that drops on weekends, a consistent late-evening spike that correlates with screen time, or a weekly cycle where stress accumulates through Thursday and partially recovers over the weekend.

Stretheo's Trends & Insights engine looks for these patterns automatically. It correlates your stress measurements with your sleep data, mood entries, and time-of-day information to surface observations that would be difficult to notice manually.

But you can also read patterns yourself. In the History tab, look for: the difference between your weekend and weekday averages; whether your stress scores are trending up or down over the last two weeks; and whether your mood entries correlate with your stress scores (they usually do, with a slight lag — high stress today often predicts lower mood tomorrow).

The most actionable insight from pattern recognition is identifying your highest-risk time windows — the hours and situations where your stress consistently peaks — and targeting those specifically with breathing exercises, movement, or schedule changes.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-1 * 24 * 3600),
            isFeatured: false
        ),
        ArticleSeedData(
            cloudKitRecordID: "sample-006",
            title: "The 4-7-8 Method: A Clinical Perspective",
            category: "breathing",
            summary: "Developed by Dr. Andrew Weil, the 4-7-8 technique uses an extended exhale to activate the parasympathetic nervous system within seconds.",
            content: """
The 4-7-8 breathing technique was popularised by integrative medicine physician Dr. Andrew Weil, who described it as a natural tranquiliser for the nervous system. The pattern — inhale for four seconds, hold for seven, exhale for eight — is designed around a specific physiological principle: the extended exhale.

Exhalation activates the parasympathetic nervous system more strongly than inhalation. This is because the vagus nerve, which carries parasympathetic signals to the heart and digestive system, is more sensitive to the intrathoracic pressure changes that occur during exhalation. A long exhale — longer than the inhale — reliably shifts autonomic balance toward the rest-and-digest state.

The breath hold extends the duration of elevated carbon dioxide in the bloodstream, which has a mild vasodilatory and calming effect. Some practitioners find the hold challenging; if breath-holding causes anxiety, shortening the hold or eliminating it while maintaining the inhale-to-exhale ratio (1:2) preserves the core mechanism.

A 2024 scoping review of 15 studies on the 4-7-8 technique found consistent evidence of reduced anxiety and improved stress markers across diverse populations, including surgical patients, nursing students, and individuals with chronic respiratory conditions. The technique's simplicity — no equipment, no special environment — makes it particularly useful in acute stress situations.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-6 * 24 * 3600),
            isFeatured: false
        ),
        ArticleSeedData(
            cloudKitRecordID: "sample-007",
            title: "Wrist Temperature and Stress: An Emerging Signal",
            category: "stress",
            summary: "Apple Watch Ultra's wrist temperature sensor captures subtle thermoregulatory changes that correlate with physiological stress and recovery.",
            content: """
Wrist temperature is one of the newer biometrics in consumer wearables, and its relationship with stress is less intuitive than heart rate or HRV — but increasingly well-supported by research.

The body's thermoregulatory system is tightly coupled with the autonomic nervous system. During stress activation, blood is redirected from the periphery (skin, extremities) toward the core and major muscle groups — a response governed by sympathetic nervous system activation. This peripheral vasoconstriction causes measurable temperature drops at the wrist.

Conversely, during recovery and deep sleep, peripheral blood flow increases as the body dissipates heat and down-regulates sympathetically. Wrist temperature rises. This is why wrist temperature at night is one of the better passive indicators of sleep quality and recovery — a warmer wrist during sleep generally corresponds to deeper, more restorative rest.

Apple Watch Ultra measures wrist temperature continuously. Stretheo incorporates this data into the stress algorithm as part of the activity and temperature composite, weighted at \(activityTemperatureWeightPercent)% of the total score. The individual contribution is modest — temperature alone is not a reliable stress indicator — but as part of a multi-signal algorithm it adds meaningful signal, particularly for detecting physiological arousal that other metrics miss.

Over time, your personal baseline wrist temperature during rest becomes a reference point. Deviations from that baseline, particularly sustained low readings during waking hours, can indicate elevated sympathetic tone even when heart rate appears normal.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-4 * 24 * 3600),
            isFeatured: false
        ),
        ArticleSeedData(
            cloudKitRecordID: "sample-008",
            title: "Mood Tracking: Why Subjective Data Matters as Much as Biometrics",
            category: "stress",
            summary: "Biometrics measure physiological stress. Mood captures how you experience it. Both perspectives together tell a more complete story.",
            content: """
Stretheo's stress algorithm is built on objective biometric data — HRV, heart rate, sleep, respiration, temperature. These signals are precise, continuous, and free from reporting bias. But they capture only one dimension of the stress experience: the physiological.

Psychological stress — perceived pressure, emotional exhaustion, cognitive overload — does not always produce strong physiological signals, particularly in people who are practiced at suppressing visible stress responses. Equally, physiological arousal does not always feel stressful; exercise produces many of the same biometric signatures as anxiety.

Mood logging bridges this gap. When you log a mood score of 2 on a day when your biometric stress score is 45, Stretheo learns that your subjective experience is more distressed than your physiology suggests. The Trends & Insights engine uses this discordance to identify patterns — including cases where emotional stress consistently precedes physiological stress by a day or two.

Research in health psychology consistently finds that subjective wellbeing measures predict health outcomes independently of objective physiological measures. Self-reported mood is not a softer or less valid signal — it is a different and complementary one.

Even a brief daily mood log — thirty seconds, a single score and optional word — accumulates into a dataset that can reveal emotional patterns you would otherwise never notice: the slow drift of mood across a difficult month, the reliable lift after exercise, the correlation between low mood and poor sleep the previous night.
""",
            author: "Stretheo Health Team",
            publishedDate: Date().addingTimeInterval(-8 * 24 * 3600),
            isFeatured: false
        )
    ] }

    static func makeArticles() -> [Article] {
        all.map { seed in
            Article(
                cloudKitRecordID: seed.cloudKitRecordID,
                title: seed.title,
                category: seed.category,
                summary: seed.summary,
                content: seed.content,
                author: seed.author,
                publishedDate: seed.publishedDate,
                imageURL: nil,
                isFeatured: seed.isFeatured,
                cachedAt: Date()
            )
        }
    }
}
