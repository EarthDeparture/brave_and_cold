using Godot;
using TheBraveAndTheCold.Entities;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// Volume that marks the player as indoors while they stand inside it.
/// M1: a single box inside the greybox cabin. Later: per-building volumes;
/// the temperature model only ever sees the resulting IsIndoors flag.
/// </summary>
public partial class IndoorZone : Area3D
{
    public override void _Ready()
    {
        BodyEntered += OnBodyEntered;
        BodyExited += OnBodyExited;
    }

    private static void OnBodyEntered(Node3D body)
    {
        if (body is Player player)
            player.IsIndoors = true;
    }

    private static void OnBodyExited(Node3D body)
    {
        if (body is Player player)
            player.IsIndoors = false;
    }
}
