// RadarFloor.cs
// Procedurally generates a dark radar-style floor at runtime:
//   • Dark plane (no texture needed)
//   • Circular range rings (LineRenderer)
//   • Crosshair / compass lines
//   • Optional inner tick marks
//
// Attach to an empty GameObject named "RadarFloor".
// Call from ScenarioReplayManager.Awake() or place in scene manually.

using System.Collections.Generic;
using UnityEngine;

public class RadarFloor : MonoBehaviour
{
    [Header("Floor plane")]
    public float floorSize       = 22f;
    public Color floorColor      = new Color(0.02f, 0.05f, 0.03f, 1f); // near-black green

    [Header("Rings")]
    public int   ringCount       = 4;
    public float outerRingRadius = 9f;
    public int   ringSegments    = 128;
    public float ringLineWidth   = 0.025f;
    public Color ringColor       = new Color(0f, 0.7f, 0.35f, 0.25f);

    [Header("Crosshair")]
    public float crosshairLength = 9.2f;
    public float crosshairWidth  = 0.02f;
    public Color crosshairColor  = new Color(0f, 0.7f, 0.35f, 0.18f);
    public int   compassLines    = 12;  // N,NNE,NE … (every 30°)

    [Header("Centre dot")]
    public float centreDotRadius = 0.08f;
    public Color centreDotColor  = new Color(0f, 0.9f, 0.45f, 0.6f);

    // ── Awake ─────────────────────────────────────────────────────────────────
    private void Awake()
    {
        CreateFloorPlane();
        CreateRings();
        CreateCrosshair();
        CreateCentreDot();
    }

    // ── Floor plane ───────────────────────────────────────────────────────────
    private void CreateFloorPlane()
    {
        var go  = GameObject.CreatePrimitive(PrimitiveType.Plane);
        go.name = "_RadarPlane";
        go.transform.SetParent(transform);
        go.transform.localPosition = Vector3.zero;
        go.transform.localScale    = new Vector3(floorSize / 10f, 1f, floorSize / 10f);

        // Remove collider (not needed)
        Destroy(go.GetComponent<Collider>());

        var mat = new Material(Shader.Find("Universal Render Pipeline/Lit")
                  ?? Shader.Find("Standard"));
        mat.color = floorColor;
        mat.SetFloat("_Metallic", 0f);
        mat.SetFloat("_Smoothness", 0.05f);
        // Very subtle emissive so the plane is visible in dark scenes
        mat.SetColor("_EmissionColor", floorColor * 0.4f);
        mat.EnableKeyword("_EMISSION");
        go.GetComponent<Renderer>().material = mat;
    }

    // ── Range rings ───────────────────────────────────────────────────────────
    private void CreateRings()
    {
        for (int r = 1; r <= ringCount; r++)
        {
            float radius = outerRingRadius * r / ringCount;
            var lr = CreateLineRenderer($"_Ring_{r}", ringLineWidth, ringColor, true);
            DrawCircle(lr, radius, ringSegments, 0.001f);
        }
    }

    // ── Crosshair + compass spokes ────────────────────────────────────────────
    private void CreateCrosshair()
    {
        for (int i = 0; i < compassLines; i++)
        {
            float angleRad = i * Mathf.PI * 2f / compassLines;
            float cos = Mathf.Cos(angleRad);
            float sin = Mathf.Sin(angleRad);

            // Full length only for N/S/E/W, shorter for diagonals
            bool cardinal = (i % 3 == 0);
            float len = cardinal ? crosshairLength : crosshairLength * 0.55f;
            float width = cardinal ? crosshairWidth * 1.2f : crosshairWidth * 0.7f;

            var lr = CreateLineRenderer($"_Spoke_{i}", width, crosshairColor, false);
            lr.positionCount = 2;
            lr.SetPosition(0, new Vector3(cos * 0.1f, 0.001f, sin * 0.1f));
            lr.SetPosition(1, new Vector3(cos * len,  0.001f, sin * len));
        }
    }

    // ── Centre dot ────────────────────────────────────────────────────────────
    private void CreateCentreDot()
    {
        var lr = CreateLineRenderer("_CentreDot", centreDotRadius * 2f, centreDotColor, true);
        DrawCircle(lr, centreDotRadius, 32, 0.002f);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private LineRenderer CreateLineRenderer(string goName, float width, Color color, bool loop)
    {
        var go = new GameObject(goName);
        go.transform.SetParent(transform);
        go.transform.localPosition = Vector3.zero;

        var lr = go.AddComponent<LineRenderer>();
        lr.useWorldSpace = false;
        lr.loop          = loop;
        lr.startWidth    = width;
        lr.endWidth      = width;

        var mat = new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit")
                  ?? Shader.Find("Sprites/Default")
                  ?? Shader.Find("Unlit/Color"));
        mat.color = color;
        lr.material = mat;

        // Disable shadow casting for UI-style lines
        lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        lr.receiveShadows    = false;
        return lr;
    }

    private static void DrawCircle(LineRenderer lr, float radius, int segments, float yOffset)
    {
        lr.positionCount = segments;
        for (int i = 0; i < segments; i++)
        {
            float a = i * Mathf.PI * 2f / segments;
            lr.SetPosition(i, new Vector3(Mathf.Cos(a) * radius, yOffset, Mathf.Sin(a) * radius));
        }
    }
}
