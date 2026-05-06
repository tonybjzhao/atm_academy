// AircraftController.cs
// Attached to each aircraft prefab.  Handles:
//   - Smooth interpolation from initial → final position
//   - Aircraft body rotation to match heading
//   - World-space label (callsign / FL / speed) via TextMeshPro
//   - Selection highlight (yellow) and conflict highlight (red)
//
// Prefab setup:
//   • Root GameObject with this script
//   • Child "Model" (any simple mesh — cube, cylinder, or import a .fbx)
//   • Child "Label" with TextMeshPro - World component

using UnityEngine;
using TMPro;

public class AircraftController : MonoBehaviour
{
    [Header("References")]
    public Transform modelTransform;   // child "Model" object
    public TextMeshPro labelText;      // child "Label" TMP component

    [Header("Visual")]
    public Color normalColor    = new Color(0f, 0.9f, 0.42f);   // green  (ATM primary)
    public Color selectedColor  = Color.yellow;
    public Color conflictColor  = new Color(1f, 0.1f, 0.22f);   // red
    public Color pathNormalColor  = new Color(0f, 0.9f, 0.42f, 0.6f);
    public Color pathConflictColor = new Color(1f, 0.1f, 0.22f, 0.6f);

    // ── Runtime state ─────────────────────────────────────────────────────────
    private Vector3 _startPos;
    private Vector3 _endPos;
    private float   _startHeading;
    private float   _endHeading;
    private string  _callsign;
    private int     _altitude;
    private float   _speed;
    private bool    _wasSelected;
    private bool    _wasConflicting;

    private Renderer _renderer;

    // ── Init called by ScenarioReplayManager ─────────────────────────────────
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
        // For the end heading we keep the start heading (no heading data in final snapshot)
        _endHeading   = data.heading;

        _renderer = modelTransform != null
            ? modelTransform.GetComponent<Renderer>()
            : GetComponentInChildren<Renderer>();

        UpdateVisuals(0f);
    }

    // ── Called every frame during replay (t: 0 → 1) ──────────────────────────
    public void SetProgress(float t)
    {
        transform.position = Vector3.Lerp(_startPos, _endPos, t);

        float heading = Mathf.LerpAngle(_startHeading, _endHeading, t);
        if (modelTransform != null)
        {
            // Aircraft nose points along heading on XZ plane
            modelTransform.rotation = Quaternion.Euler(0f, heading, 0f);
        }

        UpdateVisuals(t);
        UpdateLabel();
    }

    private void UpdateVisuals(float t)
    {
        if (_renderer == null) return;
        Color c = _wasConflicting ? conflictColor
                : _wasSelected    ? selectedColor
                : normalColor;

        // Pulse selected aircraft slightly
        if (_wasSelected)
        {
            float pulse = 0.7f + 0.3f * Mathf.Sin(Time.time * 4f);
            c *= pulse;
            c.a = 1f;
        }

        _renderer.material.color = c;

        // Glow-style emissive (works on Standard/URP Lit shader)
        if (_renderer.material.HasProperty("_EmissionColor"))
        {
            _renderer.material.SetColor("_EmissionColor", c * 0.5f);
            _renderer.material.EnableKeyword("_EMISSION");
        }
    }

    private void UpdateLabel()
    {
        if (labelText == null) return;
        labelText.text = $"{_callsign}\nFL{_altitude}\n{_speed:F1} kt";
        labelText.color = _wasConflicting ? conflictColor
                        : _wasSelected    ? selectedColor
                        : normalColor;
        // Billboard — face camera
        if (Camera.main != null)
        {
            labelText.transform.LookAt(labelText.transform.position + Camera.main.transform.rotation * Vector3.forward,
                                       Camera.main.transform.rotation * Vector3.up);
        }
    }

    // Used by PathRenderer to get current world position each frame
    public Vector3 CurrentPosition => transform.position;
    public bool WasConflicting => _wasConflicting;
}
