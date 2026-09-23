using Godot;

namespace TheBraveAndTheCold.Core;

/// <summary>
/// Root game state machine. Autoloaded as "Game".
/// Owns high-level state (menu / playing / paused / dead), tree pause and the
/// mouse-capture policy that follows from it. Everything else subscribes to
/// <see cref="StateChanged"/> instead of polling.
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

    private const double NormalSecondsPerGameMinute = 1.0;
    private const double FastSecondsPerGameMinute = 0.08; // 12.5x — debug fast-forward
    private bool _timeAccelerated;

    public override void _Ready()
    {
        Instance = this;
        ProcessMode = ProcessModeEnum.Always; // must keep receiving input while the tree is paused
        EventBus.PlayerDied += OnPlayerDied;
        // M1: no menus yet — drop straight into the world. M5 replaces this.
        SetState(GameState.Playing);
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("pause"))
        {
            if (State == GameState.Playing)
                SetState(GameState.Paused);
            else if (State == GameState.Paused)
                SetState(GameState.Playing);
        }
        else if (@event.IsActionPressed("debug_time_accel"))
        {
            _timeAccelerated = !_timeAccelerated;
            if (TimeSystem.Instance is not null)
                TimeSystem.Instance.SecondsPerGameMinute =
                    _timeAccelerated ? FastSecondsPerGameMinute : NormalSecondsPerGameMinute;
            GD.Print($"[Game] Time acceleration {(_timeAccelerated ? "ON (12.5x)" : "OFF")}");
        }
    }

    public void SetState(GameState newState)
    {
        if (State == newState)
            return;

        State = newState;
        GetTree().Paused = newState == GameState.Paused;
        Input.MouseMode = newState == GameState.Playing
            ? Input.MouseModeEnum.Captured
            : Input.MouseModeEnum.Visible;

        GD.Print($"[Game] State -> {newState}");
        EmitSignal(SignalName.StateChanged, (int)newState);
    }

    private void OnPlayerDied() => SetState(GameState.Dead);
}
