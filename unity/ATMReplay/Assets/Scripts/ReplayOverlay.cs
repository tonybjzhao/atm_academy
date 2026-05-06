// ReplayOverlay.cs
// World-space TextMeshPro overlay showing score, rating, separation result,
// and conflict summary.  Values come from Flutter via ScenarioReplayManager —
// Unity never calculates score or conflict logic itself.
//
// Setup:
//   1. Create a Canvas (World Space, 1 unit/m) in the scene.
//   2. Add a child Panel → attach this script.
//   3. Assign the four TMP labels in the Inspector.
//   4. Call Populate(payload) from ScenarioReplayManager after parsing JSON.

using UnityEngine;
using TMPro;

public class ReplayOverlay : MonoBehaviour
{
    [Header("Labels — assign TMP components in Inspector")]
    public TextMeshProUGUI resultLabel;       // "LOSS OF SEPARATION" / "SEPARATION MAINTAINED"
    public TextMeshProUGUI scoreLabel;        // "Score: 85 / 120"
    public TextMeshProUGUI separationLabel;   // "Min sep: 48 px / 800 ft"
    public TextMeshProUGUI conflictPairLabel; // "QFA123 ↔ UAE406"
    public TextMeshProUGUI actionLabel;       // "Action: Turn left on QFA123 (3.2 s)"

    [Header("Colours")]
    public Color losColor  = new Color(1f, 0.12f, 0.18f, 1f);
    public Color safeColor = new Color(0f, 1f, 0.55f, 1f);

    private static readonly Color _dimWhite = new Color(0.85f, 0.92f, 0.88f, 1f);

    public void Populate(ReplayPayload p)
    {
        if (p == null) return;

        // Result banner
        bool hadLOS = p.hadLOS;
        if (resultLabel != null)
        {
            resultLabel.text  = hadLOS ? "⚠ LOSS OF SEPARATION" : "✔ SEPARATION MAINTAINED";
            resultLabel.color = hadLOS ? losColor : safeColor;
        }

        // Score
        if (scoreLabel != null)
        {
            scoreLabel.text  = $"Score: <b>{p.score}</b> / 120  ·  {FriendlyRating(p.ratingKey)}";
            scoreLabel.color = _dimWhite;
        }

        // Min separation
        if (separationLabel != null)
        {
            separationLabel.text =
                $"Min sep: {p.minHorizDist:F0} px  ·  threshold {p.thresholdHorizontalPx:F0} px";
            separationLabel.color = hadLOS ? losColor : _dimWhite;
        }

        // Conflict pair
        if (conflictPairLabel != null && p.conflictPairCallsigns != null
            && p.conflictPairCallsigns.Count >= 2)
        {
            conflictPairLabel.text  = $"{p.conflictPairCallsigns[0]}  ↔  {p.conflictPairCallsigns[1]}";
            conflictPairLabel.color = hadLOS ? losColor : _dimWhite;
        }

        // User action
        if (actionLabel != null)
        {
            if (string.IsNullOrEmpty(p.userCommandSummary) || p.actionTimeSec <= 0)
                actionLabel.text = "No command issued";
            else
                actionLabel.text = $"Action: {p.userCommandSummary}  ({p.actionTimeSec:F1} s)";
            actionLabel.color = _dimWhite;
        }
    }

    private static string FriendlyRating(string key) => key switch
    {
        "ratingExcellent"        => "Excellent",
        "ratingSafe"             => "Safe",
        "ratingNeedsImprovement" => "Needs Improvement",
        "ratingUnsafe"           => "Unsafe",
        _                        => key,
    };
}
