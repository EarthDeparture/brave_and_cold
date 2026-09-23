using TheBraveAndTheCold.Systems;

// M1 survival-math verification harness — runs the pure POCO simulation
// (no engine) through scripted scenarios so rate tuning never requires
// launching Godot. Exit code 0 only if every scenario passes.
//
//   dotnet run --project tools/sim_check

var failures = new List<string>();

// Scenario A: step outside at 20:00 in midwinter and stay there.
// Expectation: dead from exposure within 6 in-game hours.
{
    var stats = new SurvivalStats();
    const int minutes = 6 * 60;
    int i = 0;
    for (; i < minutes && !stats.IsDead; i++)
    {
        float hourOfDay = (20f + i / 60f) % 24f;
        stats.Tick(TemperatureModel.FeelsLikeC(false, hourOfDay));
    }
    bool pass = stats.IsDead;
    Console.WriteLine($"A night-exposure  : {(pass ? "PASS" : "FAIL")} " +
                      $"(died after {i / 60f:0.0}h, warmth {stats.Warmth:0}, condition {stats.Condition:0})");
    if (!pass) failures.Add("A");
}

// Scenario B: shelter in the cabin 20:00-08:00, roam outside during daylight.
// Expectation: survives a full 24h; condition intact; warmth dips but never bottoms out.
{
    var stats = new SurvivalStats();
    float minWarmth = 100f;
    const int minutes = 24 * 60;
    for (int i = 0; i < minutes && !stats.IsDead; i++)
    {
        float hourOfDay = (8f + i / 60f) % 24f;
        bool indoors = hourOfDay >= 20f || hourOfDay < 8f;
        stats.Tick(TemperatureModel.FeelsLikeC(indoors, hourOfDay));
        minWarmth = Math.Min(minWarmth, stats.Warmth);
    }
    bool pass = !stats.IsDead && stats.Condition >= 100f && minWarmth > 0f;
    Console.WriteLine($"B day/night-cycle : {(pass ? "PASS" : "FAIL")} " +
                      $"(condition {stats.Condition:0}, min warmth {minWarmth:0}, " +
                      $"hunger {stats.Hunger:0}, thirst {stats.Thirst:0}, fatigue {stats.Fatigue:0})");
    if (!pass) failures.Add("B");
}

// Scenario C: sprint constantly all day (activity multiplier sanity check).
// Expectation: fatigue collapses long before dusk (sprint = 4x fatigue drain).
{
    var stats = new SurvivalStats();
    const int minutes = 12 * 60;
    int i = 0;
    for (; i < minutes && stats.Fatigue > 0f; i++)
    {
        float hourOfDay = (8f + i / 60f) % 24f;
        stats.Tick(TemperatureModel.FeelsLikeC(false, hourOfDay), activityMult: 4f);
    }
    bool pass = stats.Fatigue <= 0f && i < 12 * 60;
    Console.WriteLine($"C sprint-fatigue  : {(pass ? "PASS" : "FAIL")} " +
                      $"(fatigue hit 0 after {i / 60f:0.0}h of sprinting)");
    if (!pass) failures.Add("C");
}

Console.WriteLine(failures.Count == 0
    ? "ALL SCENARIOS PASS"
    : $"FAILURES: {string.Join(", ", failures)}");
return failures.Count == 0 ? 0 : 1;
