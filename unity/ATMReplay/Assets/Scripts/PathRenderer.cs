// PathRenderer.cs
// Draws a coloured trail line behind each aircraft using Unity's LineRenderer.
// Green = safe separation.  Red = conflict / LOS.
//
// Prefab setup:
//   • Empty GameObject with this script + LineRenderer component
//   • Set LineRenderer material to a simple unlit colour material

using System.Collections.Generic;
using UnityEngine;

public class PathRenderer : MonoBehaviour
{
    [Header("Trail")]
    public int    maxPoints     = 200;
    public float  lineWidth     = 0.04f;
    public float  recordInterval = 0.05f; // seconds between recorded points

    // ── Internal ──────────────────────────────────────────────────────────────
    private AircraftController _aircraft;
    private LineRenderer       _line;
    private List<Vector3>      _points = new();
    private float              _timer;
    private float              _conflictThreshold; // world units
    private float              _coordScale;

    private Color _safeColor     = new Color(0f, 0.9f, 0.42f, 0.7f);
    private Color _conflictColor = new Color(1f, 0.1f, 0.22f, 0.7f);

    public void Initialise(AircraftController aircraft, float minHorizDistPx, float coordScale)
    {
        _aircraft   = aircraft;
        _coordScale = coordScale;
        // Convert pixel threshold to world units for approximate colouring
        _conflictThreshold = (minHorizDistPx / coordScale) * 1.5f;

        _line = GetComponent<LineRenderer>();
        if (_line == null) _line = gameObject.AddComponent<LineRenderer>();
        _line.startWidth = lineWidth;
        _line.endWidth   = lineWidth;
        _line.useWorldSpace = true;
        _line.positionCount = 0;

        // Gradient: green → red as aircraft approaches conflict
        var grad = new Gradient();
        grad.SetKeys(
            new[] { new GradientColorKey(_safeColor, 0f), new GradientColorKey(_conflictColor, 1f) },
            new[] { new GradientAlphaKey(0.7f, 0f), new GradientAlphaKey(0.7f, 1f) }
        );
        _line.colorGradient = grad;
    }

    private void Update()
    {
        if (_aircraft == null) return;

        _timer += Time.deltaTime;
        if (_timer < recordInterval) return;
        _timer = 0f;

        var pos = _aircraft.CurrentPosition;
        _points.Add(pos);
        if (_points.Count > maxPoints) _points.RemoveAt(0);

        _line.positionCount = _points.Count;
        _line.SetPositions(_points.ToArray());

        // Colour the most recent segment based on proximity to other aircraft
        UpdateLineColor();
    }

    private void UpdateLineColor()
    {
        // If this aircraft was flagged as conflicting, shift gradient toward red
        bool inConflict = _aircraft.WasConflicting;
        var grad = new Gradient();
        var startColor = inConflict ? _conflictColor : _safeColor;
        grad.SetKeys(
            new[] { new GradientColorKey(startColor, 0f), new GradientColorKey(startColor, 1f) },
            new[] { new GradientAlphaKey(0.3f, 0f), new GradientAlphaKey(0.8f, 1f) }
        );
        _line.colorGradient = grad;
    }
}
