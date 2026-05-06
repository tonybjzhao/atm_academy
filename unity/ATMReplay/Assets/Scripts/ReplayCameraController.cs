// ReplayCameraController.cs
// Smoothly orbits the camera around the centre of the scene during replay.
// Attach to the Main Camera.  Optionally follows the selected aircraft.

using UnityEngine;

public class ReplayCameraController : MonoBehaviour
{
    [Header("Orbit")]
    public float orbitRadius   = 8f;
    public float orbitHeight   = 4f;
    public float orbitSpeed    = 18f;   // degrees per second
    public float orbitSmoothing = 3f;

    [Header("Target")]
    public Transform lookTarget;        // assign ScenarioReplayManager's Transform (scene centre)

    [Header("Cinematic intro")]
    public float introDuration = 1.5f;  // seconds to ease in from far

    // ── Internal ──────────────────────────────────────────────────────────────
    private float _angle;
    private float _introTimer;
    private bool  _introComplete;

    private void Start()
    {
        // Start camera pointing toward the scene
        _angle = 0f;
        if (lookTarget == null)
        {
            // Default to world origin
            var go = new GameObject("_SceneCentre");
            lookTarget = go.transform;
        }
    }

    private void LateUpdate()
    {
        _angle += orbitSpeed * Time.deltaTime;

        // Cinematic intro: pull camera in from 1.5× radius
        float radius = orbitRadius;
        if (!_introComplete)
        {
            _introTimer += Time.deltaTime;
            float t = Mathf.Clamp01(_introTimer / introDuration);
            float ease = 1f - Mathf.Pow(1f - t, 3f);       // ease-out cubic
            radius = Mathf.Lerp(orbitRadius * 1.5f, orbitRadius, ease);
            if (_introTimer >= introDuration) _introComplete = true;
        }

        float rad = _angle * Mathf.Deg2Rad;
        Vector3 target = new Vector3(
            lookTarget.position.x + Mathf.Cos(rad) * radius,
            lookTarget.position.y + orbitHeight,
            lookTarget.position.z + Mathf.Sin(rad) * radius
        );

        transform.position = Vector3.Lerp(transform.position, target,
                                          Time.deltaTime * orbitSmoothing);
        transform.LookAt(lookTarget.position);
    }
}
