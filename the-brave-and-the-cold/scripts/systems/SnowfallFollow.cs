using Godot;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// Keeps the snowfall emitter centred above the active camera so flakes are
/// always around the player without simulating particles across the whole map.
/// Requires local_coords=false on the particles: already-emitted flakes stay
/// behind naturally in world space as the emitter follows the camera.
/// </summary>
public partial class SnowfallFollow : GpuParticles3D
{
    [Export] public float HeightAboveCamera { get; set; } = 7f;

    public override void _Process(double delta)
    {
        var camera = GetViewport().GetCamera3D();
        if (camera is null)
            return;

        Vector3 pos = camera.GlobalPosition;
        pos.Y += HeightAboveCamera;
        GlobalPosition = pos;
    }
}
