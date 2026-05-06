// ScenarioReplayManager.cs
// Root controller for the ATM Academy 3D Scenario Replay.
// Receives JSON from Flutter via flutter_unity_widget, spawns aircraft,
// plays the replay animation, and notifies Flutter when done.
//
// Scene setup (see unity/SETUP.md for full guide):
//   1. Empty GameObject named exactly "ScenarioReplayManager" — attach this script.
//   2. Assign aircraftPrefab and pathRendererPrefab in Inspector.
//   3. RadarFloor is spawned automatically at Awake.
//   4. Main Camera needs CinematicReplayCamera component — assign its target
//      to this GameObject's Transform.

using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// ── Data classes (must match Flutter's ScenarioReplayData.toJson()) ───────────

[Serializable]
public class AircraftData
{
    public string callsign;
    public float  x;
    public float  y;
    public float  heading;
    public float  speed;
    public int    altitude;
    public bool   wasSelected;
    public bool   wasConflicting;
}

[Serializable]
public class ReplayPayload
{
    public string             scenarioId;
    public string             scenarioTitle;
    public List<AircraftData> initialAircraft;
    public List<AircraftData> finalAircraft;

    // Conflict metrics (from Flutter ScenarioEngine)
    public List<string> conflictPairCallsigns;
    public float        closestPointPxX;
    public float        closestPointPxY;
    public float        closestPointTimeSec;
    public float        thresholdHorizontalPx;
    public int          thresholdVerticalFt;

    // User action
    public float        actionTimeSec;
    public string       userCommandSummary;

    // Score (Flutter calculates; Unity only displays)
    public float        minHorizDist;
    public bool         hadLOS;
    public int          score;
    public string       ratingKey;

    // Breakdown
    public List<string> penaltyBreakdown;
    public List<string> bonusBreakdown;
}

// ── Main controller ───────────────────────────────────────────────────────────

public class ScenarioReplayManager : MonoBehaviour
{
    [Header("Prefabs")]
    public GameObject aircraftPrefab;       // assign in Inspector
    public GameObject pathRendererPrefab;   // assign in Inspector

    [Header("Overlay (optional)")]
    public ReplayOverlay overlay;           // assign a world-space canvas overlay

    [Header("Scene scale")]
    // Flutter radar coords: ~370 x 430 px → divide by coordScale for world units
    public float coordScale    = 40f;
    // Scale applied to aircraft prefab at spawn (increase if aircraft look too small)
    public float aircraftScale = 2.2f;

    [Header("Replay timing")]
    public float animationDuration = 6f;   // seconds for full replay
    public float holdAfterFinish   = 2f;   // seconds to hold final frame

    // ── Internal ──────────────────────────────────────────────────────────────
    private ReplayPayload              _payload;
    private List<AircraftController>   _controllers = new();
    private List<PathRenderer>         _paths       = new();
    private RadarFloor                 _radarFloor;
    private RadarSweep                 _radarSweep;
    private CinematicReplayCamera      _cinCam;

    // ── Unity lifecycle ───────────────────────────────────────────────────────
    private void Awake()
    {
        // Spawn radar floor + sweep procedurally
        var floorGo = new GameObject("RadarFloor");
        _radarFloor = floorGo.AddComponent<RadarFloor>();

        var sweepGo = new GameObject("RadarSweep");
        _radarSweep = sweepGo.AddComponent<RadarSweep>();

        // Find cinematic camera on Main Camera
        if (Camera.main != null)
            _cinCam = Camera.main.GetComponent<CinematicReplayCamera>();

        // Point cinematic camera at this GameObject (scene centre)
        if (_cinCam != null && _cinCam.target == null)
            _cinCam.target = transform;
    }

    // ── Entry point called by flutter_unity_widget ────────────────────────────
    // Flutter: controller.postMessage("ScenarioReplayManager", "LoadReplayData", jsonString)
    public void LoadReplayData(string json)
    {
        // Clear any previous replay
        foreach (var c in _controllers) if (c) Destroy(c.gameObject);
        foreach (var p in _paths)       if (p) Destroy(p.gameObject);
        _controllers.Clear();
        _paths.Clear();
        StopAllCoroutines();

        _payload = UnityEngine.JsonUtility.FromJson<ReplayPayload>(json);
        if (_payload == null)
        {
            Debug.LogError("[ATMReplay] Failed to parse JSON. Check that the JSON matches ReplayPayload fields.");
            return;
        }
        StartCoroutine(RunReplay());
    }

    // ── Replay coroutine ──────────────────────────────────────────────────────
    private IEnumerator RunReplay()
    {
        // Spawn aircraft at initial positions
        for (int i = 0; i < _payload.initialAircraft.Count; i++)
        {
            var init   = _payload.initialAircraft[i];
            var final_ = i < _payload.finalAircraft.Count
                ? _payload.finalAircraft[i]
                : init;

            var go   = Instantiate(aircraftPrefab,
                                   ToWorld(init.x, init.y, init.altitude),
                                   Quaternion.identity);
            go.transform.localScale = Vector3.one * aircraftScale;
            var ctrl = go.GetComponent<AircraftController>();
            ctrl.Initialise(init, ToWorld(final_.x, final_.y, final_.altitude));
            _controllers.Add(ctrl);

            // Path renderer
            var prGo = Instantiate(pathRendererPrefab);
            var pr   = prGo.GetComponent<PathRenderer>();
            pr.Initialise(ctrl, _payload.minHorizDist, coordScale);
            _paths.Add(pr);
        }

        // Closest-point marker (small pulsing sphere at conflict midpoint)
        SpawnClosestPointMarker();

        // Populate score overlay before animation begins
        overlay?.Populate(_payload);

        // Notify cinematic camera replay is starting
        _cinCam?.BeginReplay(animationDuration + holdAfterFinish);

        // One frame delay so camera has correct initial state
        yield return null;

        // Animate initial → final positions
        float elapsed = 0f;
        while (elapsed < animationDuration)
        {
            float t = elapsed / animationDuration;
            foreach (var ctrl in _controllers) ctrl.SetProgress(t);
            elapsed += Time.deltaTime;
            yield return null;
        }

        // Snap to final frame
        foreach (var ctrl in _controllers) ctrl.SetProgress(1f);

        yield return new WaitForSeconds(holdAfterFinish);

        NotifyFlutter("REPLAY_COMPLETE");
    }

    // ── Closest-point marker ──────────────────────────────────────────────────
    // A small pulsing ring at the conflict midpoint so the viewer can see exactly
    // where the aircraft came closest.
    private void SpawnClosestPointMarker()
    {
        if (_payload == null) return;
        var worldPos = ToWorld(_payload.closestPointPxX, _payload.closestPointPxY, 300);

        var go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        go.name = "_ClosestPointMarker";
        go.transform.position   = worldPos;
        go.transform.localScale = Vector3.one * 0.25f;
        Destroy(go.GetComponent<Collider>());

        var mat = new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit")
                  ?? Shader.Find("Sprites/Default"));
        bool hadLOS = _payload.hadLOS;
        mat.color = hadLOS
            ? new Color(1f, 0.12f, 0.18f, 0.5f)   // red for LOS
            : new Color(1f, 0.85f, 0f,   0.5f);   // amber for warning
        go.GetComponent<Renderer>().material = mat;

        // Add pulsing scale via coroutine
        StartCoroutine(PulseMarker(go.transform, hadLOS));
    }

    private static IEnumerator PulseMarker(Transform t, bool isLOS)
    {
        float elapsed = 0f;
        float speed   = isLOS ? 4f : 2.5f;
        while (t != null)
        {
            elapsed += Time.deltaTime;
            float s = 0.20f + 0.10f * Mathf.Sin(elapsed * speed * Mathf.PI * 2f);
            t.localScale = Vector3.one * s;
            yield return null;
        }
    }

    // ── Notify Flutter ────────────────────────────────────────────────────────
    private void NotifyFlutter(string message)
    {
#if UNITY_WEBGL && !UNITY_EDITOR
        // WebGL bridge (not used for mobile but kept for completeness)
        try { ReactUnityWebGL.ReactUnityBridgeCallback(message); } catch { }
#else
        try
        {
            // flutter_unity_widget: triggers onUnityMessage callback in Dart
            SendMessageUpwards("OnUnityMessage", message, SendMessageOptions.DontRequireReceiver);
        }
        catch { /* No bridge present (in-editor testing) — ignore */ }
#endif
    }

    // ── Coordinate mapping ────────────────────────────────────────────────────
    // Flutter origin: top-left, Y down.
    // Unity origin: world centre, Y up, aircraft move on XZ plane.
    private Vector3 ToWorld(float fx, float fy, int flightLevel)
    {
        float wx = (fx - 185f) / coordScale;
        float wz = (fy - 215f) / coordScale;
        // FL320 ≈ cruise. Map altitude to a small vertical range for visual clarity.
        float wy = (flightLevel - 300f) * 0.015f;
        return new Vector3(wx, wy, wz);
    }

    // ── Called when user presses Back inside Unity ────────────────────────────
    public void OnBackPressed()
    {
        StopAllCoroutines();
        NotifyFlutter("REPLAY_COMPLETE");
    }

    // ── In-editor test (fires automatically in Play mode) ────────────────────
    // Remove or disable this in a production build to avoid a spurious test replay.
    private void Start()
    {
        const string testJson = @"{
            ""scenarioId"":    ""basic_crossing_same_level"",
            ""scenarioTitle"": ""Crossing Traffic at Same Level"",
            ""initialAircraft"": [
                { ""callsign"":""QFA123"", ""x"":60,  ""y"":210, ""heading"":90,  ""speed"":0.8, ""altitude"":320, ""wasSelected"":true,  ""wasConflicting"":false },
                { ""callsign"":""UAE406"", ""x"":310, ""y"":210, ""heading"":270, ""speed"":0.8, ""altitude"":320, ""wasSelected"":false, ""wasConflicting"":true  }
            ],
            ""finalAircraft"": [
                { ""callsign"":""QFA123"", ""x"":180, ""y"":165, ""heading"":75,  ""speed"":0.8, ""altitude"":320, ""wasSelected"":true,  ""wasConflicting"":false },
                { ""callsign"":""UAE406"", ""x"":222, ""y"":205, ""heading"":270, ""speed"":0.8, ""altitude"":320, ""wasSelected"":false, ""wasConflicting"":true  }
            ],
            ""minHorizDist"": 52.0,
            ""hadLOS"":       false,
            ""score"":        98,
            ""ratingKey"":    ""ratingExcellent""
        }";

        LoadReplayData(testJson);
    }
}
