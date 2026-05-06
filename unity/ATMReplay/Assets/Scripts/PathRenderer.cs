// PathRenderer.cs
// Draws a coloured trail behind each aircraft using Unity's LineRenderer.
//
//   Conflicting aircraft → RED trail (fades from bright near head to transparent)
//   Selected aircraft    → YELLOW trail
//   Normal aircraft      → GREEN/CYAN trail
//
// Prefab: empty GameObject with this script (LineRenderer added at runtime).

using System.Collections.Generic;
using UnityEngine;

public class PathRenderer : MonoBehaviour
{
    [Header("Trail")]
    public int   maxPoints      = 400;
    public float recordInterval = 0.033f; // ~30 fps recording
    public float lineWidth      = 0.08f;  // wider trail = more visible

    [Header("Colours (override from aircraft at runtime)")]
    public Color normalColor   = new Color(0.00f, 1.00f, 0.55f, 1f);  // bright green
    public Color conflictColor = new Color(1.00f, 0.10f, 0.15f, 1f);  // vivid red
    public Color selectedColor = new Color(1.00f, 0.92f, 0.00f, 1f);  // yellow

    // ── Internal ──────────────────────────────────────────────────────────────
    private AircraftController _aircraft;
    private LineRenderer       _line;
    private List<Vector3>      _pts  = new();
    private float              _timer;
    private Color              _trailColor;

    public void Initialise(AircraftController aircraft, float minHorizDistPx, float coordScale)
    {
        _aircraft = aircraft;

        // Pick colour from aircraft state
        _trailColor = aircraft.WasConflicting ? conflictColor
                    : aircraft.WasSelected    ? selectedColor
                    : normalColor;

        _line = gameObject.GetComponent<LineRenderer>()
             ?? gameObject.AddComponent<LineRenderer>();

        _line.useWorldSpace   = true;
        _line.positionCount   = 0;
        _line.startWidth      = lineWidth;
        _line.endWidth        = lineWidth * 0.05f; // taper to a point

        // Gradient: opaque at tail tip, transparent at oldest point
        var grad = new Gradient();
        grad.SetKeys(
            new[]
            {
                new GradientColorKey(_trailColor, 0f),
                new GradientColorKey(_trailColor, 1f)
            },
            new[]
            {
                new GradientAlphaKey(0.00f, 0f),   // oldest: invisible
                new GradientAlphaKey(0.75f, 0.70f), // recent: semi-opaque
                new GradientAlphaKey(0.90f, 1f)    // newest: bright
            }
        );
        _line.colorGradient = grad;

        var mat = new Material(
            Shader.Find("Universal Render Pipeline/Particles/Unlit")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Color")
        );
        mat.color = _trailColor;
        _line.material = mat;

        _line.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        _line.receiveShadows    = false;
    }

    private void Update()
    {
        if (_aircraft == null) return;

        _timer += Time.deltaTime;
        if (_timer < recordInterval) return;
        _timer = 0f;

        // Record position — keep Y constant to floor height for visual clarity
        var pos = _aircraft.CurrentPosition;
        pos.y = 0.003f; // hugs the floor slightly
        _pts.Add(pos);

        if (_pts.Count > maxPoints) _pts.RemoveAt(0);

        _line.positionCount = _pts.Count;
        _line.SetPositions(_pts.ToArray());

        // Conflicting aircraft: pulse trail intensity
        if (_aircraft.WasConflicting)
        {
            float pulse = 0.5f + 0.5f * Mathf.Sin(Time.time * 5f * Mathf.PI * 2f);
            var pulsedColor = new Color(
                conflictColor.r,
                conflictColor.g * 0.3f,
                conflictColor.b * 0.3f,
                1f
            );
            _line.material.color = Color.Lerp(conflictColor, pulsedColor, pulse * 0.4f);
        }
    }
}
