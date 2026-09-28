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

    // Screenshot mode (look-dev tooling): --screenshot=<frames> --screenshot-path=<abs path>
    // runs the game that many frames, captures the viewport, writes a PNG and quits.
    // --hour=<0-23> offsets the start time for lighting-variant captures.
    private int _screenshotFrames = -1;
    private string _screenshotPath = "";
    private int _startHour = -1; // deferred: TimeSystem may not be ready in _Ready (autoload order)

    public override void _Ready()
    {
        Instance = this;
        ProcessMode = ProcessModeEnum.Always; // must keep receiving input while the tree is paused
        EventBus.PlayerDied += OnPlayerDied;
        ParseCommandLineArgs();
        // M1: no menus yet — drop straight into the world. M5 replaces this.
        SetState(GameState.Playing);
    }

    private void ParseCommandLineArgs()
    {
        foreach (string arg in OS.GetCmdlineArgs())
        {
            if (arg.StartsWith("--screenshot="))
                int.TryParse(arg["--screenshot=".Length..], out _screenshotFrames);
            else if (arg.StartsWith("--screenshot-path="))
                _screenshotPath = ProjectSettings.GlobalizePath(arg["--screenshot-path=".Length..]);
            else if (arg.StartsWith("--hour="))
                int.TryParse(arg["--hour=".Length..], out _startHour);
        }
    }

    public override void _Process(double delta)
    {
        if (_startHour >= 0 && TimeSystem.Instance is not null)
        {
            TimeSystem.Instance.Restore(1, _startHour, 0);
            _startHour = -1;
        }

        if (_screenshotFrames > 0)
        {
            _screenshotFrames--;
            if (_screenshotFrames == 0)
                CaptureScreenshotAsync();
        }
    }

    private async void CaptureScreenshotAsync()
    {
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        var image = GetViewport().GetTexture().GetImage();
        string path = string.IsNullOrEmpty(_screenshotPath)
            ? ProjectSettings.GlobalizePath("user://screenshot.png")
            : _screenshotPath;
        DirAccess.MakeDirRecursiveAbsolute(path.GetBaseDir());
        image.SavePng(path);
        GD.Print($"[Game] Screenshot -> {path}");
        GetTree().Quit();
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
        else if (@event is InputEventKey { Pressed: true, Echo: false, Keycode: Key.F12 })
        {
            string dir = ProjectSettings.GlobalizePath("res://../screenshots");
            string stamp = Time.GetDatetimeStringFromSystem().Replace(":", "-");
            _screenshotPath = System.IO.Path.Combine(dir, $"shot_{stamp}.png");
            _screenshotFrames = 2;
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
