// AircraftController.cs
// Visual states:
//   CONFLICTING — red, fast scale+emission pulse, conflict halo ring
//   SELECTED    — yellow, slow pulse
//   NORMAL      — green, no pulse
//
// Prefab: root object (this script) + child "Model" + child "Label" (TMP).

using UnityEngine;
using TMPro;

public class AircraftController : MonoBehaviour
{
    [Header("References")]
    public Transform   modelTransform;
    public TextMeshPro labelText;

    [Header("Colours")]
    public Color normalColor   = new Color(0.00f, 1.00f, 0.55f, 1f);  // bright green
    public Color selectedColor = new Color(1.00f, 0.92f, 0.00f, 1f);  // yellow
    public Color conflictColor = new Color(1.00f, 0.10f, 0.15f, 1f);  // vivid red

    [Header("Pulse — conflict")]
    public float conflictPulseHz        = 3.0f;   // oscillations per second
    public float conflictScaleMin       = 0.85f;  // shrink to this
    public float conflictScaleMax       = 1.40f;  // grow to this
    public float conflictEmitMultiplier = 4.0f;   // emission boost (HDR)

    [Header("Pulse — selected")]
    public float selectedPulseHz   = 1.2f;
    public float selectedEmitMult  = 1.2f;

    [Header("Normal emission")]
    public float normalEmitMult = 0.5f;

    [Header("Halo ring — conflict only")]
    public float haloRadius    = 0.55f;
    public float haloWidth     = 0.06f;
    public int   haloSegments  = 48;

    [Header("Label")]
    public float labelOffsetX = 0.25f;
    public float labelOffsetY = 0.40f;

    // ── State ─────────────────────────────────────────────────────────────────
    private Vector3  _startPos;
    private Vector3  _endPos;
    private float    _startHeading;
    private string   _callsign;
    private int      _altitude;
    private float    _speed;
    private bool     _wasSelected;
    private bool     _wasConflicting;

    private Renderer     _rend;
    private Vector3      _baseScale;
    private LineRenderer _haloLr;

    // ── Init ──────────────────────────────────────────────────────────────────
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

        if (_rend != null) _rend.material.EnableKeyword("_EMISSION");

        _baseScale = modelTransform != null
            ? modelTransform.localScale
            : Vector3.one;

        // Conflict halo ring
        if (_wasConflicting) CreateHalo();

        ApplyVisuals();
        UpdateLabel();
    }

    // ── Called every frame during replay ─────────────────────────────────────
    public void SetProgress(float t)
    {
        transform.position = Vector3.Lerp(_startPos, _endPos, Mathf.SmoothStep(0f, 1f, t));

        if (modelTransform != null)
            modelTransform.rotation = Quaternion.Euler(0f, _startHeading, 0f);

        ApplyVisuals();
        UpdateLabel();
        UpdateHalo();
    }

    // ── Visuals ───────────────────────────────────────────────────────────────
    private void ApplyVisuals()
    {
        if (_rend == null) return;

        float   emitMult;
        Color   baseColor;
        Vector3 scale = _baseScale;

        if (_wasConflicting)
        {
            // Fast sin pulse: drives BOTH scale and emission
            float sin   = Mathf.Sin(Time.time * conflictPulseHz * Mathf.PI * 2f);
            float pulse = sin * 0.5f + 0.5f;                          // 0 → 1

            float s    = Mathf.Lerp(conflictScaleMin, conflictScaleMax, pulse);
            scale      = _baseScale * s;

            baseColor  = conflictColor;
            emitMult   = Mathf.Lerp(1.0f, conflictEmitMultiplier, pulse);
        }
        else if (_wasSelected)
        {
            float sin   = Mathf.Sin(Time.time * selectedPulseHz * Mathf.PI * 2f);
            float pulse = sin * 0.5f + 0.5f;

            baseColor  = selectedColor;
            emitMult   = Mathf.Lerp(0.6f, selectedEmitMult, pulse);
        }
        else
        {
            baseColor  = normalColor;
            emitMult   = normalEmitMult;
        }

        if (modelTransform != null) modelTransform.localScale = scale;

        _rend.material.color = baseColor;
        Color emit = new Color(baseColor.r * emitMult,
                               baseColor.g * emitMult,
                               baseColor.b * emitMult, 1f);
        if (_rend.material.HasProperty("_EmissionColor"))
            _rend.material.SetColor("_EmissionColor", emit);
    }

    // ── Halo ring ─────────────────────────────────────────────────────────────
    private void CreateHalo()
    {
        var go = new GameObject("_Halo");
        go.transform.SetParent(transform);
        go.transform.localPosition = Vector3.zero;

        _haloLr = go.AddComponent<LineRenderer>();
        _haloLr.loop            = true;
        _haloLr.useWorldSpace   = false;
        _haloLr.positionCount   = haloSegments;
        _haloLr.startWidth      = haloWidth;
        _haloLr.endWidth        = haloWidth;
        _haloLr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        _haloLr.receiveShadows  = false;

        var mat = new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit")
                  ?? Shader.Find("Sprites/Default") ?? Shader.Find("Unlit/Color"));
        mat.color = conflictColor;
        _haloLr.material = mat;

        for (int i = 0; i < haloSegments; i++)
        {
            float a = i * Mathf.PI * 2f / haloSegments;
            _haloLr.SetPosition(i,
                new Vector3(Mathf.Cos(a) * haloRadius, 0.01f, Mathf.Sin(a) * haloRadius));
        }
    }

    private void UpdateHalo()
    {
        if (_haloLr == null) return;
        // Pulse halo alpha in sync with aircraft pulse
        float sin   = Mathf.Sin(Time.time * conflictPulseHz * Mathf.PI * 2f);
        float alpha = 0.3f + 0.7f * (sin * 0.5f + 0.5f);
        _haloLr.startColor = new Color(conflictColor.r, conflictColor.g, conflictColor.b, alpha);
        _haloLr.endColor   = _haloLr.startColor;
    }

    // ── Label ─────────────────────────────────────────────────────────────────
    private void UpdateLabel()
    {
        if (labelText == null) return;

        labelText.text = $"<b>{_callsign}</b>\nFL{_altitude}";
        labelText.color = _wasConflicting ? conflictColor
                        : _wasSelected    ? selectedColor
                        : normalColor;

        labelText.transform.localPosition =
            new Vector3(labelOffsetX, labelOffsetY, 0f);

        if (Camera.main != null)
            labelText.transform.LookAt(
                labelText.transform.position + Camera.main.transform.rotation * Vector3.forward,
                Camera.main.transform.rotation * Vector3.up);
    }

    // ── Exposed ───────────────────────────────────────────────────────────────
    public bool     WasConflicting    => _wasConflicting;
    public bool     WasSelected       => _wasSelected;
    public Color    ConflictColor     => conflictColor;
    public Color    NormalColor       => normalColor;
    public Vector3  CurrentPosition   => transform.position;
}
