using System;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// Single source of truth for temperature. The player AND (in M4) the zombies
/// sample the same field — that shared simulation is the game's core design pillar.
/// Pure static POCO; no Godot types.
/// </summary>
public static class TemperatureModel
{
    /// <summary>Daily mean outdoor temperature.</summary>
    public const float MeanTempC = -10f;
    /// <summary>Daily swing amplitude around the mean (min 02:00, max 14:00).</summary>
    public const float DailySwingC = 7f;
    public const float HottestHour = 14f;
    /// <summary>Unheated but wind-sheltered interior temperature.</summary>
    public const float IndoorTempC = 12f;
    /// <summary>
    /// Stand-in for the M3 clothing system: assumes the player always wears
    /// basic winter gear worth this many °C of wind/cold protection.
    /// </summary>
    public const float ImplicitClothingBonusC = 6f;

    /// <summary>Sinusoidal daily temperature curve: coldest ~02:00, warmest ~14:00.</summary>
    public static float OutdoorTempC(float hourOfDay) =>
        MeanTempC + DailySwingC * MathF.Cos(MathF.Tau * (hourOfDay - HottestHour) / 24f);

    /// <summary>What a body actually experiences: indoor shelter, or outdoor cold plus clothing.</summary>
    public static float FeelsLikeC(bool indoors, float hourOfDay) =>
        indoors ? IndoorTempC : OutdoorTempC(hourOfDay) + ImplicitClothingBonusC;

    // M6: weather fronts, wind chill, blizzards hook in here.
}
