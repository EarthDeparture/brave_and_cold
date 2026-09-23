using System;
using System.IO;
using System.Text.Json;
using Godot;

namespace TheBraveAndTheCold.Core;

/// <summary>
/// Versioned JSON save/load. Autoloaded as "SaveSystem".
/// Saves live in user://saves/. Payload format is <see cref="SaveData"/>.
/// </summary>
public partial class SaveSystem : Node
{
    private const string SaveDir = "user://saves";

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static string SlotPath(int slot) => $"{SaveDir}/save_{slot}.json";

    public bool SaveExists(int slot) => Godot.FileAccess.FileExists(SlotPath(slot));

    public void Save(int slot, SaveData data)
    {
        DirAccess.MakeDirRecursiveAbsolute(ProjectSettings.GlobalizePath(SaveDir));
        data.Version = SaveData.CurrentVersion;

        string path = ProjectSettings.GlobalizePath(SlotPath(slot));
        File.WriteAllText(path, JsonSerializer.Serialize(data, JsonOptions));
        GD.Print($"[SaveSystem] Saved slot {slot} (format v{data.Version})");
    }

    public SaveData? Load(int slot)
    {
        string path = ProjectSettings.GlobalizePath(SlotPath(slot));
        if (!File.Exists(path))
            return null;

        try
        {
            var data = JsonSerializer.Deserialize<SaveData>(File.ReadAllText(path));
            if (data is null)
                return null;

            if (data.Version > SaveData.CurrentVersion)
            {
                GD.PushWarning($"[SaveSystem] Slot {slot} is format v{data.Version}, " +
                               $"newer than supported v{SaveData.CurrentVersion}.");
            }
            // Future migrations hook in here when CurrentVersion increases.
            return data;
        }
        catch (Exception e)
        {
            GD.PushError($"[SaveSystem] Failed to load slot {slot}: {e.Message}");
            return null;
        }
    }

    public void Delete(int slot)
    {
        string path = ProjectSettings.GlobalizePath(SlotPath(slot));
        if (File.Exists(path))
            File.Delete(path);
    }
}
