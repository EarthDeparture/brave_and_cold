using System;

namespace TheBraveAndTheCold.Core;

/// <summary>
/// Static event hub for cross-system messages that shouldn't couple
/// systems to each other's node trees. Keep payloads primitive or POCO.
/// Add events sparingly — a direct node reference is better when the
/// dependency is real; this bus is for genuinely decoupled notifications.
/// </summary>
public static class EventBus
{
    /// <summary>Raised when the player's condition reaches zero.</summary>
    public static event Action? PlayerDied;

    public static void RaisePlayerDied() => PlayerDied?.Invoke();
}
