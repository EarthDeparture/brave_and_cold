namespace TheBraveAndTheCold.Core;

/// <summary>
/// Plain serializable snapshot of a save game. No Godot types —
/// keeps the save format engine-API-independent and unit-testable.
/// IMPORTANT: never remove or retype fields; only add new ones (with defaults)
/// and bump <see cref="CurrentVersion"/> on breaking changes.
/// </summary>
public sealed class SaveData
{
    public const int CurrentVersion = 1;

    public int Version { get; set; } = CurrentVersion;
    public int Day { get; set; } = 1;
    public int Hour { get; set; } = 8;
    public int Minute { get; set; }

    // M1: player position/rotation, survival stats (warmth, hunger, thirst, fatigue, condition)
    // M3: inventory, looted container state, world seed
    // M4: zombie positions/states
}
