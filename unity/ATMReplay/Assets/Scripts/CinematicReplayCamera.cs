// CinematicReplayCamera.cs
// Attach to Main Camera.
// Provides a three-phase cinematic orbit for scenario replays:
//
//   INTRO  — ease-in from far, pull down to orbitHeight, orbit begins
//   MID    — slow zoom-in toward zoomInRadius at replay midpoint
//   OUTRO  — gentle zoom-out as replay approaches end
//
// Call BeginReplay(totalDuration) from ScenarioReplayManager when replay starts.

using UnityEngine;

public class CinematicReplayCamera : MonoBehaviour
{
    [Header("Target")]
    public Transform target;           // set to ScenarioReplayManager transform (scene centre)

    [Header("Orbit")]
    public float orbitRadius   = 10f;  // default cruise radius
    public float orbitHeight   = 5f;   // camera Y position
    public float orbitSpeed    = 14f;  // degrees per second
    public float smoothing     = 3.5f; // position lerp factor

    [Header("Intro")]
    public float introDuration   = 1.8f;  // ease-in duration (seconds)
    public float introStartScale = 2.0f;  // start radius = orbitRadius * this

    [Header("Mid zoom")]
    public float zoomInRadius    = 7f;    // closer radius at mid-replay
    public float zoomInStartPct  = 0.30f; // begin zoom at X% of replay
    public float zoomInPeakPct   = 0.55f; // peak zoom at X%

    [Header("Outro")]
    public float outroStartPct  = 0.75f; // begin pull-back at X%
    public float outroEndRadius = 11f;   // radius at replay end

    // ── Internal ──────────────────────────────────────────────────────────────
    private float _totalDuration;
    private float _elapsed;
    private bool  _active;
    private float _angle;
    private Vector3 _desiredPos;

    private void Awake()
    {
        // Default target: world origin
        if (target == null)
        {
            var go = new GameObject("_CameraTarget");
            target = go.transform;
        }
        // Park camera at intro position before BeginReplay is called
        _angle = 0f;
        _desiredPos = ComputeOrbitPos(orbitRadius * introStartScale, _angle);
        transform.position = _desiredPos;
        transform.LookAt(target.position);
    }

    /// <summary>Called by ScenarioReplayManager when replay begins.</summary>
    public void BeginReplay(float totalDuration)
    {
        _totalDuration = Mathf.Max(totalDuration, 0.1f);
        _elapsed = 0f;
        _active  = true;
    }

    private void LateUpdate()
    {
        if (target == null) return;

        _angle += orbitSpeed * Time.deltaTime;

        float radius;

        if (!_active)
        {
            // Pre-replay: hold intro position, slowly drift orbit
            radius = orbitRadius * introStartScale;
        }
        else
        {
            _elapsed += Time.deltaTime;
            float pct = Mathf.Clamp01(_elapsed / _totalDuration);
            radius = ComputeRadius(pct);
        }

        _desiredPos = ComputeOrbitPos(radius, _angle);
        transform.position = Vector3.Lerp(transform.position, _desiredPos,
                                          Time.deltaTime * smoothing);
        // Smooth look-at
        var lookDir = (target.position - transform.position).normalized;
        if (lookDir != Vector3.zero)
        {
            transform.rotation = Quaternion.Slerp(
                transform.rotation,
                Quaternion.LookRotation(lookDir),
                Time.deltaTime * smoothing * 1.5f
            );
        }
    }

    // ── Radius curve ──────────────────────────────────────────────────────────
    private float ComputeRadius(float pct)
    {
        // 0 → introDuration: ease from introStartScale → 1.0
        float introFraction = Mathf.Clamp01(_elapsed / Mathf.Max(introDuration, 0.01f));
        float introEase     = 1f - Mathf.Pow(1f - introFraction, 3f); // cubic ease-out

        // Base radius after intro
        float baseRadius = Mathf.Lerp(orbitRadius * introStartScale, orbitRadius, introEase);

        // Mid zoom: smoothly dip to zoomInRadius between zoomInStartPct and outroStartPct
        float zoomT = 0f;
        if (pct >= zoomInStartPct && pct <= outroStartPct)
        {
            float span = outroStartPct - zoomInStartPct;
            float local = (pct - zoomInStartPct) / span;
            // Triangle wave: 0→1→0 peaking at zoomInPeakPct
            float normPeak = (zoomInPeakPct - zoomInStartPct) / span;
            zoomT = local <= normPeak
                ? local / normPeak
                : 1f - (local - normPeak) / (1f - normPeak);
            zoomT = Mathf.SmoothStep(0f, 1f, zoomT);
        }
        float midRadius = Mathf.Lerp(baseRadius, zoomInRadius, zoomT);

        // Outro pull-back
        float outroT = 0f;
        if (pct >= outroStartPct)
        {
            outroT = Mathf.SmoothStep(0f, 1f, (pct - outroStartPct) / (1f - outroStartPct));
        }
        return Mathf.Lerp(midRadius, outroEndRadius, outroT);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private Vector3 ComputeOrbitPos(float radius, float angleDeg)
    {
        float rad = angleDeg * Mathf.Deg2Rad;
        return new Vector3(
            target.position.x + Mathf.Cos(rad) * radius,
            target.position.y + orbitHeight,
            target.position.z + Mathf.Sin(rad) * radius
        );
    }
}
