using Godot;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// On ready, generates trimesh static collision for every MeshInstance3D
/// descendant. Attach to an instanced .glb scene root (terrain, buildings).
/// Static level geometry only — never on dynamic or animated meshes.
/// </summary>
public partial class TrimeshCollision : Node3D
{
    public override void _Ready()
    {
        foreach (var node in FindChildren("*", "MeshInstance3D", true, false))
        {
            if (node is MeshInstance3D meshInstance && meshInstance.Mesh is not null)
                meshInstance.CreateTrimeshCollision();
        }
    }
}
