// RadarSweep.cs
// Rotating radar sweep with a bright main beam, wide glow layer, and fading trail.
// Spawned by ScenarioReplayManager.Awake() — no prefab required.

using UnityEngine;

public class RadarSweep : MonoBehaviour
{
    [Header("Geometry")]
    public float radius      = 9.2f;
    public float sweepHeight = 0.010f;

    [Header("Rotation")]
    public float rotationSpeed = 38f;  // degrees/second — slow, cinematic

    [Header("Main beam")]
    public float mainWidth = 0.15f;
    public Color mainColor = new Color(0.05f, 1f, 0.55f, 1f);

    [Header("Glow layer (wide, low alpha — creates bloom feel)")]
    public float glowWidth = 0.55f;
    public Color glowColor = new Color(0.05f, 1f, 0.55f, 0.18f);

    [Header("Trail fan")]
    public int   trailCount      = 20;
    public float trailArcDeg     = 65f;
    public float trailMaxAlpha   = 0.55f;
    public float trailWidthScale = 0.6f;

    // ── Internal ──────────────────────────────────────────────────────────────
    private float          _angle;
    private LineRenderer   _mainBeam;
    private LineRenderer   _glowBeam;
    private LineRenderer[] _trail;

    private void Awake()  => Build();
    private void Update() { _angle = (_angle + rotationSpeed * Time.deltaTime) % 360f; Tick(); }

    // ── Build ─────────────────────────────────────────────────────────────────
    private void Build()
    {
        // Glow first (behind main)
        _glowBeam = Line("_Glow", glowWidth, glowColor, new Color(glowColor.r, glowColor.g, glowColor.b, 0.02f));

        // Main bright beam
        _mainBeam = Line("_Main", mainWidth, mainColor, new Color(mainColor.r, mainColor.g, mainColor.b, 0.05f));

        // Trail
        _trail = new LineRenderer[trailCount];
        for (int i = 0; i < trailCount; i++)
        {
            float t     = (float)(i + 1) / trailCount;
            float alpha = trailMaxAlpha * (1f - t);
            var   c0    = new Color(mainColor.r, mainColor.g, mainColor.b, alpha);
            var   c1    = new Color(mainColor.r, mainColor.g, mainColor.b, alpha * 0.08f);
            float w     = mainWidth * trailWidthScale * (1f - t * 0.4f);
            _trail[i]   = Line($"_Trail{i}", w, c0, c1);
        }
    }

    // ── Per-frame ─────────────────────────────────────────────────────────────
    private void Tick()
    {
        Place(_glowBeam, _angle);
        Place(_mainBeam, _angle);
        for (int i = 0; i < trailCount; i++)
            Place(_trail[i], _angle - (i + 1) * (trailArcDeg / trailCount));
    }

    private void Place(LineRenderer lr, float deg)
    {
        float rad = deg * Mathf.Deg2Rad;
        lr.SetPosition(0, new Vector3(0f, sweepHeight, 0f));
        lr.SetPosition(1, new Vector3(Mathf.Cos(rad) * radius, sweepHeight, Mathf.Sin(rad) * radius));
    }

    // ── Factory ───────────────────────────────────────────────────────────────
    private LineRenderer Line(string n, float width, Color start, Color end)
    {
        var go = new GameObject(n);
        go.transform.SetParent(transform);

        var lr = go.AddComponent<LineRenderer>();
        lr.positionCount   = 2;
        lr.useWorldSpace   = true;
        lr.startWidth      = width;
        lr.endWidth        = width * 0.06f;
        lr.startColor      = start;
        lr.endColor        = end;
        lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        lr.receiveShadows  = false;

        var mat = new Material(
            Shader.Find("Universal Render Pipeline/Particles/Unlit")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Color"));
        mat.color = start;
        lr.material = mat;
        return lr;
    }
}
