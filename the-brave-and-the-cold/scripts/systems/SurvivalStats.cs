using System;

namespace TheBraveAndTheCold.Systems;

/// <summary>
/// The five core survival meters, 0-100 each. Pure POCO: one <see cref="Tick"/>
/// per in-game minute, driven by the Player via TimeSystem.MinuteTicked.
/// All rates are public constants so the sim_check harness and in-game
/// behaviour can never drift apart. No Godot types on purpose.
/// </summary>
public sealed class SurvivalStats
{
    // --- Warmth ---
    /// <summary>Warmth change per °C the feels-like temp is away from <see cref="ComfortTempC"/>.</summary>
    public const float WarmthRatePerDegC = 0.10f;
    public const float MaxWarmthChangePerMin = 2.5f;
    /// <summary>Feels-like temperature at or above which the body warms up.</summary>
    public const float ComfortTempC = 0f;

    // --- Passive drains (per in-game minute) ---
    public const float HungerDrainPerMin = 0.02f;   // ~3.5 game days full -> starving
    public const float ThirstDrainPerMin = 0.03f;   // ~2.3 game days (M3 rebalances once water exists)
    public const float FatigueDrainPerMin = 0.04f;

    // --- Condition ---
    public const float FreezingConditionDrain = 1.0f;
    public const float DehydrationConditionDrain = 0.2f;
    public const float StarvationConditionDrain = 0.15f;
    public const float ConditionRegenPerMin = 0.15f;

    public float Condition { get; private set; } = 100f;
    public float Warmth { get; private set; } = 100f;
    public float Hunger { get; private set; } = 100f;
    public float Thirst { get; private set; } = 100f;
    public float Fatigue { get; private set; } = 100f;

    public bool IsDead => Condition <= 0f;

    /// <summary>Advance all meters by one in-game minute.</summary>
    /// <param name="feelsLikeC">Effective temperature the player is exposed to right now.</param>
    /// <param name="activityMult">Fatigue drain multiplier (sprinting ≈ 4).</param>
    public void Tick(float feelsLikeC, float activityMult = 1f)
    {
        // Warmth moves toward equilibrium with the environment in both directions.
        float warmthDelta = WarmthRatePerDegC * (feelsLikeC - ComfortTempC);
        warmthDelta = Math.Clamp(warmthDelta, -MaxWarmthChangePerMin, MaxWarmthChangePerMin);
        Warmth = ClampStat(Warmth + warmthDelta);

        Hunger = ClampStat(Hunger - HungerDrainPerMin);
        Thirst = ClampStat(Thirst - ThirstDrainPerMin);
        Fatigue = ClampStat(Fatigue - FatigueDrainPerMin * activityMult);

        float conditionDrain = 0f;
        if (Warmth <= 0f) conditionDrain += FreezingConditionDrain;
        if (Thirst <= 0f) conditionDrain += DehydrationConditionDrain;
        if (Hunger <= 0f) conditionDrain += StarvationConditionDrain;

        if (conditionDrain > 0f)
            Condition = ClampStat(Condition - conditionDrain);
        else if (Warmth > 40f && Hunger > 20f && Thirst > 20f)
            Condition = ClampStat(Condition + ConditionRegenPerMin);
    }

    private static float ClampStat(float value) => Math.Clamp(value, 0f, 100f);
}
