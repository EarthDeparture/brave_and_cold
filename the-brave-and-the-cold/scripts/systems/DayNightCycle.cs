using Godot;
using TheBraveAndTheCold.Core;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// Drives the sun, ambient light and fog density from the TimeSystem clock.
/// Short winter day (sunrise 08:00, sunset 17:00) — darkness is a gameplay timer.
/// M2 (look-dev) will replace these blunt lerps with a proper graded day curve.
/// </summary>
public partial class DayNightCycle : Node3D
{
    [Export] public DirectionalLight3D Sun { get; set; } = null!;
    [Export] public WorldEnvironment WorldEnv { get; set; } = null!;
    [Export] public float SunriseHour { get; set; } = 8f;
    [Export] public float SunsetHour { get; set; } = 17f;
    [Export] public float MaxSunElevationDeg { get; set; } = 28f;

    private static readonly Color NoonColor = new(1.0f, 0.96f, 0.90f);
    private static readonly Color DuskColor = new(1.0f, 0.62f, 0.35f);
    private static readonly Color MoonColor = new(0.55f, 0.68f, 1.0f);

    private Environment? _env;
    private int _lastMinuteKey = -1;

    public override void _Ready()
    {
        _env = WorldEnv?.Environment;
        UpdateLighting();
    }

    public override void _Process(double delta)
    {
        var clock = TimeSystem.Instance;
        if (clock is null)
            return;

        int minuteKey = clock.Day * 1440 + clock.Hour * 60 + clock.Minute;
        if (minuteKey != _lastMinuteKey)
        {
            _lastMinuteKey = minuteKey;
            UpdateLighting();
        }
    }

    private void UpdateLighting()
    {
        var clock = TimeSystem.Instance;
        if (clock is null || Sun is null)
            return;

        float h = clock.HourFloat;
        bool isDay = h >= SunriseHour && h <= SunsetHour;
        float dayT = Mathf.Clamp((h - SunriseHour) / (SunsetHour - SunriseHour), 0f, 1f);
        float sunUp = Mathf.Sin(Mathf.Pi * dayT); // 0 at dawn/dusk, 1 at solar noon

        if (isDay)
        {
            float elevation = Mathf.DegToRad(MaxSunElevationDeg) * sunUp + Mathf.DegToRad(6f);
            float azimuth = Mathf.Lerp(Mathf.DegToRad(-75f), Mathf.DegToRad(75f), dayT);
            Sun.Rotation = new Vector3(-elevation, azimuth, 0f);
            Sun.LightEnergy = 0.25f + sunUp;
            Sun.LightColor = DuskColor.Lerp(NoonColor, sunUp);
        }
        else
        {
            // Fixed low "moon" so nights stay readable but unmistakably dark.
            Sun.Rotation = new Vector3(Mathf.DegToRad(-55f), Mathf.DegToRad(30f), 0f);
            Sun.LightEnergy = 0.06f;
            Sun.LightColor = MoonColor;
        }

        if (_env is not null)
        {
            _env.AmbientLightEnergy = isDay ? Mathf.Lerp(0.35f, 1.0f, sunUp) : 0.18f;
            _env.FogDensity = isDay ? Mathf.Lerp(0.020f, 0.012f, sunUp) : 0.030f;
        }
    }
}
