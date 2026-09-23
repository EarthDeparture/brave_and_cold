using Godot;

namespace TheBraveAndTheCold.Core;

/// <summary>
/// Root game state machine. Autoloaded as "Game".
/// Owns high-level state (menu / playing / paused / dead) and nothing else —
/// other systems subscribe to <see cref="StateChanged"/> instead of polling.
/// </summary>
public partial class Game : Node
{
    public enum GameState
    {
        MainMenu,
        Playing,
        Paused,
        Dead,
    }

    public static Game Instance { get; private set; } = null!;

    [Signal]
    public delegate void StateChangedEventHandler(int newState);

    public GameState State { get; private set; } = GameState.MainMenu;

    public override void _Ready()
    {
        Instance = this;
        // M0: no menus yet — drop straight into the world.
        // M5 replaces this with the real main-menu flow.
        SetState(GameState.Playing);
    }

    public void SetState(GameState newState)
    {
        if (State == newState)
            return;

        State = newState;
        GD.Print($"[Game] State -> {newState}");
        EmitSignal(SignalName.StateChanged, (int)newState);
    }
}
