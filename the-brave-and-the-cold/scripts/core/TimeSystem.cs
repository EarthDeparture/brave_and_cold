using Godot;

namespace TheBraveAndTheCold.Core;

/// <summary>
/// Game clock. Autoloaded as "TimeSystem".
/// Advances only while <see cref="Game.State"/> is Playing.
/// Everything time-driven (temperature model, survival stats, zombie activity)
/// hangs off <see cref="MinuteTicked"/> instead of running its own timer.
/// </summary>
public partial class TimeSystem : Node
{
    /// <summary>Real seconds per in-game minute. 1.0 => a full day lasts 24 real minutes.</summary>
    [Export]
    public double SecondsPerGameMinute { get; set; } = 1.0;

    [Export]
    public int StartDay { get; set; } = 1;

    [Export]
    public int StartHour { get; set; } = 8;

    public static TimeSystem Instance { get; private set; } = null!;

    [Signal]
    public delegate void MinuteTickedEventHandler(int day, int hour, int minute);

    public int Day { get; private set; }
    public int Hour { get; private set; }
    public int Minute { get; private set; }

    private double _accumulator;

    public string TimeText => $"{Hour:00}:{Minute:00}";

    public override void _Ready()
    {
        Instance = this;
        Day = StartDay;
        Hour = StartHour;
        Minute = 0;
    }

    public override void _Process(double delta)
    {
        if (Game.Instance is null || Game.Instance.State != Game.GameState.Playing)
            return;

        _accumulator += delta;
        while (_accumulator >= SecondsPerGameMinute)
        {
            _accumulator -= SecondsPerGameMinute;
            TickMinute();
        }
    }

    private void TickMinute()
    {
        Minute++;
        if (Minute >= 60)
        {
            Minute = 0;
            Hour++;
            if (Hour >= 24)
            {
                Hour = 0;
                Day++;
            }
        }
        EmitSignal(SignalName.MinuteTicked, Day, Hour, Minute);
    }

    /// <summary>Restore clock state from a save game.</summary>
    public void Restore(int day, int hour, int minute)
    {
        Day = day;
        Hour = hour;
        Minute = minute;
        _accumulator = 0;
    }
}
