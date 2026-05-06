// RadarSweep.cs
// Procedurally renders a rotating radar sweep fan above the radar floor.
// Uses a series of LineRenderers (main bright line + fading trail) — no new packages.
//
// Attach to any GameObject (ScenarioReplayManager spawns it automatically).
// Works standalone; no prefab required.

using UnityEngine;

public class RadarSweep : MonoBehaviour
{
    [Header("Geometry")]
    public float radius        = 9.0f;    // should match RadarFloor.outerRingRadius
    public float sweepHeight   = 0.008f;  // just above radar floor rings

    [Header("Rotation")]
    public float rotationSpeed = 55f;     // degrees per second (CCW)

    [Header("Sweep line")]
    public float   lineWidth       = 0.06f;
    public Color   sweepColor      = new Color(0.05f, 1f, 0.5f, 0.9f);

    [Header("Trail fan")]
    public int   trailCount        = 14;   // number of fading trail lines
    public float trailArcDegrees   = 55f;  // arc covered by trail
    public float trailMaxAlpha     = 0.45f;
    public float trailWidthScale   = 0.5f; // trail lines thinner than main

    // ── Internal ──────────────────────────────────────────────────────────────
    private float          _angle;
    private LineRenderer   _mainLine;
    private LineRenderer[] _trailLines;

    private void Awake()
    {
        CreateLines();
    }

    private void Update()
    {
        _angle = (_angle + rotationSpeed * Time.deltaTime) % 360f;
        UpdateLines();
    }

    // ── Setup ─────────────────────────────────────────────────────────────────
    private void CreateLines()
    {
        _mainLine = MakeLine("_Sweep_Main", lineWidth, sweepColor, sweepColor);

        _trailLines = new LineRenderer[trailCount];
        for (int i = 0; i < trailCount; i++)
        {
            // Alpha fades from near-main to zero
            float t   = (float)(i + 1) / trailCount;
            float a   = trailMaxAlpha * (1f - t);
            var col   = new Color(sweepColor.r, sweepColor.g, sweepColor.b, a);
            var colTip = new Color(sweepColor.r, sweepColor.g, sweepColor.b, a * 0.15f);
            _trailLines[i] = MakeLine($"_Sweep_Trail_{i}",
                lineWidth * trailWidthScale * (1f - t * 0.5f), col, colTip);
        }
    }

    // ── Each frame ────────────────────────────────────────────────────────────
    private void UpdateLines()
    {
        SetLine(_mainLine, _angle);

        for (int i = 0; i < trailCount; i++)
        {
            float offset = (i + 1) * (trailArcDegrees / trailCount);
            SetLine(_trailLines[i], _angle - offset);
        }
    }

    private void SetLine(LineRenderer lr, float angleDeg)
    {
        float rad = angleDeg * Mathf.Deg2Rad;
        var origin = new Vector3(0f, sweepHeight, 0f);
        var tip    = new Vector3(Mathf.Cos(rad) * radius,
                                 sweepHeight,
                                 Mathf.Sin(rad) * radius);
        lr.SetPosition(0, origin);
        lr.SetPosition(1, tip);
    }

    // ── Line renderer factory ─────────────────────────────────────────────────
    private LineRenderer MakeLine(string goName, float width, Color startCol, Color endCol)
    {
        var go = new GameObject(goName);
        go.transform.SetParent(transform);

        var lr = go.AddComponent<LineRenderer>();
        lr.positionCount = 2;
        lr.useWorldSpace = true;
        lr.startWidth    = width;
        lr.endWidth      = width * 0.1f;   // taper toward tip
        lr.startColor    = startCol;
        lr.endColor      = endCol;

        // Try URP unlit first, fall back to legacy Sprites/Default
        var mat = new Material(
            Shader.Find("Universal Render Pipeline/Particles/Unlit")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Color")
        );
        mat.color = startCol;
        lr.material = mat;

        lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        lr.receiveShadows    = false;
        return lr;
    }
}
