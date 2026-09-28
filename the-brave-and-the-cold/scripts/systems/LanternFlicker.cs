using Godot;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// Cheap firelight flicker: three incommensurate sines produce a lively,
/// non-repeating energy curve without any RNG allocations.
/// M3 ties this to actual fire state; for M2 look-dev it is always on.
/// </summary>
public partial class LanternFlicker : OmniLight3D
{
    [Export] public float BaseEnergy { get; set; } = 1.4f;
    [Export] public float FlickerAmount { get; set; } = 0.18f;

    private float _time;

    public override void _Process(double delta)
    {
        _time += (float)delta;
        float flicker = Mathf.Sin(_time * 13.0f) * 0.6f
                      + Mathf.Sin(_time * 31.0f + 1.7f) * 0.3f
                      + Mathf.Sin(_time * 53.0f + 4.2f) * 0.1f;
        LightEnergy = BaseEnergy * (1.0f + flicker * FlickerAmount);
    }
}
