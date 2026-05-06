// ScenarioReplayManager.cs
// Root controller for the ATM Academy 3D Scenario Replay.
// Receives JSON from Flutter via flutter_unity_widget, spawns aircraft,
// plays the replay animation, and notifies Flutter when done.
//
// Unity setup:
//   1. Create an empty GameObject named "ScenarioReplayManager" in the scene.
//   2. Attach this script.
//   3. Assign aircraftPrefab in the Inspector (see AircraftController.cs).
//   4. Assign pathRendererPrefab in the Inspector (see PathRenderer.cs).

using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public class AircraftData
{
    public string callsign;
    public float x;
    public float y;
    public float heading;
    public float speed;
    public int altitude;
    public bool wasSelected;
    public bool wasConflicting;
}

[Serializable]
public class ReplayPayload
{
    public string scenarioId;
    public string scenarioTitle;
    public List<AircraftData> initialAircraft;
    public List<AircraftData> finalAircraft;
    public float minHorizDist;
    public bool hadLOS;
    public int score;
    public string ratingKey;
}

public class ScenarioReplayManager : MonoBehaviour
{
    [Header("Prefabs")]
    public GameObject aircraftPrefab;       // assign in Inspector
    public GameObject pathRendererPrefab;   // assign in Inspector

    [Header("Scene scale")]
    // Flutter radar coords are ~370 x 430 px.
    // Map to Unity world units: divide by this factor.
    public float coordScale = 40f;

    [Header("Replay timing")]
    public float animationDuration = 6f;   // seconds for full replay
    public float holdAfterFinish   = 2f;   // seconds to hold final frame

    // ── Internal ──────────────────────────────────────────────────────────────
    private ReplayPayload _payload;
    private List<AircraftController> _controllers = new();
    private List<PathRenderer>       _paths       = new();
    private bool _replayStarted;

    // ── Entry point called by flutter_unity_widget ────────────────────────────
    // Flutter calls: controller.postMessage("ScenarioReplayManager", "LoadReplayData", jsonString)
    public void LoadReplayData(string json)
    {
        _payload = JsonUtility.FromJson<ReplayPayload>(json);
        if (_payload == null) { Debug.LogError("[ATMReplay] Failed to parse JSON"); return; }
        StartCoroutine(RunReplay());
    }

    // ── Replay coroutine ──────────────────────────────────────────────────────
    private IEnumerator RunReplay()
    {
        // Spawn aircraft at initial positions
        for (int i = 0; i < _payload.initialAircraft.Count; i++)
        {
            var init  = _payload.initialAircraft[i];
            var final_ = i < _payload.finalAircraft.Count
                ? _payload.finalAircraft[i]
                : init;

            var go = Instantiate(aircraftPrefab, ToWorld(init.x, init.y, init.altitude), Quaternion.identity);
            var ctrl = go.GetComponent<AircraftController>();
            ctrl.Initialise(init, ToWorld(final_.x, final_.y, final_.altitude));
            _controllers.Add(ctrl);

            // Path renderer for this aircraft
            var prGo = Instantiate(pathRendererPrefab);
            var pr   = prGo.GetComponent<PathRenderer>();
            pr.Initialise(ctrl, _payload.minHorizDist, coordScale);
            _paths.Add(pr);
        }

        // Animate to final positions
        float elapsed = 0f;
        _replayStarted = true;

        while (elapsed < animationDuration)
        {
            float t = elapsed / animationDuration;
            foreach (var ctrl in _controllers) ctrl.SetProgress(t);
            elapsed += Time.deltaTime;
            yield return null;
        }

        // Snap to final
        foreach (var ctrl in _controllers) ctrl.SetProgress(1f);

        yield return new WaitForSeconds(holdAfterFinish);

        // Notify Flutter replay complete
        // flutter_unity_widget will trigger OnUnityMessage("REPLAY_COMPLETE")
#if UNITY_WEBGL && !UNITY_EDITOR
        ReactUnityWebGL.ReactUnityBridgeCallback("REPLAY_COMPLETE");
#else
        // flutter_unity_widget native bridge
        try
        {
            // The method name matches what is registered in UnityWidgetController.onUnityMessage
            SendMessageUpwards("OnUnityMessage", "REPLAY_COMPLETE", SendMessageOptions.DontRequireReceiver);
        }
        catch { /* swallow if bridge not present during development */ }
#endif
    }

    // ── Coordinate mapping ────────────────────────────────────────────────────
    // Flutter: origin top-left, Y down. Unity: origin centre, Y up (XZ plane).
    private Vector3 ToWorld(float fx, float fy, int flightLevel)
    {
        // Centre the Flutter 370x430 space around world origin
        float wx = (fx - 185f) / coordScale;
        float wz = (fy - 215f) / coordScale;
        // Altitude: FL320 → 32,000 ft. Scale to a visible height range.
        float wy = (flightLevel - 250f) * 0.02f;
        return new Vector3(wx, wy, wz);
    }

    // Called if user presses Back inside Unity (optional)
    public void OnBackPressed()
    {
        StopAllCoroutines();
        SendMessageUpwards("OnUnityMessage", "REPLAY_COMPLETE", SendMessageOptions.DontRequireReceiver);
    }
}
