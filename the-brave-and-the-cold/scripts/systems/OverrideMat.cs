using Godot;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// Debug/dev helper: applies a material override to every MeshInstance3D under
/// this node (incl. inside instanced .glb scenes, which tscn files can't reach).
/// </summary>
public partial class OverrideMat : Node3D
{
    [Export] public Material? Mat { get; set; }

    public override void _Ready()
    {
        // Attached as a child of an instanced .glb root; operate on the parent's
        // subtree so the instanced MeshInstance3D children are covered.
        Node scope = GetParent() ?? this;
        foreach (var node in scope.FindChildren("*", "MeshInstance3D", true, false))
        {
            if (node is MeshInstance3D meshInstance)
                meshInstance.MaterialOverride = Mat;
        }
    }
}
