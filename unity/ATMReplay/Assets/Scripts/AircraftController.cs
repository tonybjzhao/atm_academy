// AircraftController.cs
// Attached to each aircraft prefab.
//
// Visual states:
//   CONFLICTING — red, fast pulse (draws attention immediately)
//   SELECTED    — yellow, slow pulse (user-selected aircraft)
//   NORMAL      — green/cyan, no pulse
//
// Prefab setup:
//   • Root GameObject with this script
//   • Child "Model" (cube / cylinder / simple mesh)
//   • Child "Label" with TextMeshPro - World (assign labelText below)

using UnityEngine;
using TMPro;

public class AircraftController : MonoBehaviour
{
    [Header("References")]
    public Transform  modelTransform;  // child "Model"
    public TextMeshPro labelText;      // child "Label" TMP

    [Header("Colours")]
    public Color normalColor    = new Color(0.00f, 0.90f, 0.50f, 1f); // ATM green
    public Color selectedColor  = new Color(1.00f, 0.90f, 0.00f, 1f); // yellow
    public Color conflictColor  = new Color(1.00f, 0.15f, 0.20f, 1f); // red

    [Header("Pulse")]
    public float conflictPulseSpeed = 5.5f;  // Hz for conflicting
    public float selectedPulseSpeed = 1.8f;  // Hz for selected
    public float pulseMinBrightness = 0.55f;
    public float conflictEmitScale  = 2.0f;  // emissive multiplier for red glow

    [Header("Label")]
    public float labelOffsetY = 0.35f;

    // ── State ─────────────────────────────────────────────────────────────────
    private Vector3 _startPos;
    private Vector3 _endPos;
    private float   _startHeading;
    private string  _callsign;
    private int     _altitude;
    private float   _speed;
    private bool    _wasSelected;
    private bool    _wasConflicting;

    private Renderer _rend;

    // ── Called by ScenarioReplayManager ──────────────────────────────────────
    public void Initialise(AircraftData data, Vector3 worldEndPos)
    {
        _callsign       = data.callsign;
        _altitude       = data.altitude;
        _speed          = data.speed;
        _wasSelected    = data.wasSelected;
        _wasConflicting = data.wasConflicting;

        _startPos     = transform.position;
        _endPos       = worldEndPos;
        _startHeading = data.heading;

        _rend = modelTransform != null
            ? modelTransform.GetComponent<Renderer>()
            : GetComponentInChildren<Renderer>();

        if (_rend != null)
        {
            // Enable emission keyword once at startup
            _rend.material.EnableKeyword("_EMISSION");
        }

        ApplyVisuals(0f);
        UpdateLabel();
    }

    // ── Called every frame (t: 0 → 1) ────────────────────────────────────────
    public void SetProgress(float t)
    {
        // Smooth step for natural-feeling deceleration at ends
        float eased = Mathf.SmoothStep(0f, 1f, t);
        transform.position = Vector3.Lerp(_startPos, _endPos, eased);

        // Rotate model to face heading (constant for V1)
        if (modelTransform != null)
            modelTransform.rotation = Quaternion.Euler(0f, _startHeading, 0f);

        ApplyVisuals(t);
        UpdateLabel();
    }

    // ── Visual update ─────────────────────────────────────────────────────────
    private void ApplyVisuals(float t)
    {
        if (_rend == null) return;

        Color baseColor;
        float emitScale;

        if (_wasConflicting)
        {
            // Fast pulse: min brightness to full
            float pulse = pulseMinBrightness + (1f - pulseMinBrightness)
                          * (0.5f + 0.5f * Mathf.Sin(Time.time * conflictPulseSpeed * Mathf.PI * 2f));
            baseColor  = conflictColor * pulse;
            baseColor.a = 1f;
            emitScale  = conflictEmitScale * pulse;
        }
        else if (_wasSelected)
        {
            float pulse = pulseMinBrightness + (1f - pulseMinBrightness)
                          * (0.5f + 0.5f * Mathf.Sin(Time.time * selectedPulseSpeed * Mathf.PI * 2f));
            baseColor  = selectedColor * pulse;
            baseColor.a = 1f;
            emitScale  = 0.6f * pulse;
        }
        else
        {
            baseColor  = normalColor;
            emitScale  = 0.35f;
        }

        _rend.material.color = baseColor;

        Color emit = new Color(baseColor.r * emitScale,
                               baseColor.g * emitScale,
                               baseColor.b * emitScale, 1f);
        if (_rend.material.HasProperty("_EmissionColor"))
            _rend.material.SetColor("_EmissionColor", emit);
    }

    // ── Label update ──────────────────────────────────────────────────────────
    private void UpdateLabel()
    {
        if (labelText == null) return;

        labelText.text = $"<b>{_callsign}</b>\nFL{_altitude}\n{_speed:F1}";

        labelText.color = _wasConflicting ? conflictColor
                        : _wasSelected    ? selectedColor
                        : normalColor;

        // Position label above aircraft
        if (labelText.transform.parent != null)
            labelText.transform.localPosition = new Vector3(0.2f, labelOffsetY, 0f);

        // Billboard toward camera
        if (Camera.main != null)
        {
            labelText.transform.LookAt(
                labelText.transform.position + Camera.main.transform.rotation * Vector3.forward,
                Camera.main.transform.rotation * Vector3.up
            );
        }
    }

    // Exposed for PathRenderer colour queries
    public bool WasConflicting => _wasConflicting;
    public bool WasSelected    => _wasSelected;
    public Color ConflictColor => conflictColor;
    public Color NormalColor   => normalColor;
    public Vector3 CurrentPosition => transform.position;
}
