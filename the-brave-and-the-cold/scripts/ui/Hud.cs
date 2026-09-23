using Godot;
using TheBraveAndTheCold.Core;
using TheBraveAndTheCold.Entities;

namespace TheBraveAndTheCold.Ui;

/// <summary>
/// M1 debug-grade HUD: survival stat bars, clock, temperature readout,
/// pause and death overlays. Polls the player at ~7 Hz — cheap and robust
/// across scene reloads (no fragile signal wiring to scene-owned nodes).
/// M5 replaces this with the real styled UI.
/// </summary>
public partial class Hud : CanvasLayer
{
    private ProgressBar _conditionBar = null!;
    private ProgressBar _warmthBar = null!;
    private ProgressBar _hungerBar = null!;
    private ProgressBar _thirstBar = null!;
    private ProgressBar _fatigueBar = null!;
    private ProgressBar _staminaBar = null!;
    private Label _clockLabel = null!;
    private Label _envLabel = null!;
    private Label _pausedLabel = null!;
    private Label _deathInfoLabel = null!;
    private Control _deathPanel = null!;

    private Player? _player;
    private double _pollAccumulator;

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always; // HUD must keep working while paused/dead

        _conditionBar = GetNode<ProgressBar>("%ConditionBar");
        _warmthBar = GetNode<ProgressBar>("%WarmthBar");
        _hungerBar = GetNode<ProgressBar>("%HungerBar");
        _thirstBar = GetNode<ProgressBar>("%ThirstBar");
        _fatigueBar = GetNode<ProgressBar>("%FatigueBar");
        _staminaBar = GetNode<ProgressBar>("%StaminaBar");
        _clockLabel = GetNode<Label>("%ClockLabel");
        _envLabel = GetNode<Label>("%EnvLabel");
        _pausedLabel = GetNode<Label>("%PausedLabel");
        _deathInfoLabel = GetNode<Label>("%DeathInfoLabel");
        _deathPanel = GetNode<Control>("%DeathPanel");

        _pausedLabel.Visible = false;
        _deathPanel.Visible = false;

        Game.Instance.StateChanged += OnStateChanged;
    }

    public override void _ExitTree()
    {
        if (Game.Instance is not null)
            Game.Instance.StateChanged -= OnStateChanged;
    }

    public override void _Process(double delta)
    {
        _pollAccumulator += delta;
        if (_pollAccumulator < 0.15)
            return;
        _pollAccumulator = 0;

        _player ??= GetTree().GetFirstNodeInGroup("player") as Player;

        var clock = TimeSystem.Instance;
        if (clock is not null)
            _clockLabel.Text = $"Day {clock.Day}   {clock.TimeText}";

        if (_player is null)
            return;

        var s = _player.Stats;
        _conditionBar.Value = s.Condition;
        _warmthBar.Value = s.Warmth;
        _hungerBar.Value = s.Hunger;
        _thirstBar.Value = s.Thirst;
        _fatigueBar.Value = s.Fatigue;
        _staminaBar.Value = _player.Stamina;
        _envLabel.Text = $"{(_player.IsIndoors ? "Indoors" : "Outdoors")}   feels like {_player.LastFeelsLikeC:0.#} C";
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (Game.Instance.State != Game.GameState.Dead)
            return;

        if (@event.IsActionPressed("restart"))
        {
            GetTree().Paused = false;
            TimeSystem.Instance.Restore(1, 8, 0);
            Game.Instance.SetState(Game.GameState.Playing);
            GetTree().ReloadCurrentScene();
        }
    }

    private void OnStateChanged(int newState)
    {
        var state = (Game.GameState)newState;
        _pausedLabel.Visible = state == Game.GameState.Paused;
        _deathPanel.Visible = state == Game.GameState.Dead;

        if (state == Game.GameState.Dead)
        {
            int days = TimeSystem.Instance?.Day ?? 1;
            _deathInfoLabel.Text = $"You survived {days} day{(days == 1 ? "" : "s")}.";
        }
    }
}
