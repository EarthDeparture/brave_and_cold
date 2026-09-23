using Godot;
using TheBraveAndTheCold.Core;
using TheBraveAndTheCold.Systems;

namespace TheBraveAndTheCold.Entities;

/// <summary>
/// First-person player controller. Owns the player's <see cref="SurvivalStats"/>
/// and feeds them the feels-like temperature every in-game minute.
/// Walk / sprint (stamina) / crouch / jump; mouse-look with captured cursor.
/// </summary>
public partial class Player : CharacterBody3D
{
    [Export] public float WalkSpeed { get; set; } = 3.0f;
    [Export] public float SprintSpeed { get; set; } = 5.5f;
    [Export] public float CrouchSpeed { get; set; } = 1.5f;
    [Export] public float JumpVelocity { get; set; } = 4.5f;
    [Export] public float MouseSensitivity { get; set; } = 0.0022f;
    [Export] public float StaminaDrainPerSec { get; set; } = 12f;
    [Export] public float StaminaRegenPerSec { get; set; } = 8f;

    private const float StandHeight = 1.8f;
    private const float CrouchHeight = 1.2f;

    public SurvivalStats Stats { get; } = new();
    public bool IsIndoors { get; set; }
    public float Stamina { get; private set; } = 100f;
    public float LastFeelsLikeC { get; private set; }
    public bool IsSprinting { get; private set; }

    private Node3D _head = null!;
    private CollisionShape3D _collision = null!;
    private CapsuleShape3D _capsule = null!;
    private float _standHeadY;
    private float _crouchHeadY;
    private bool _crouched;
    private bool _dead;
    private float _staminaRegenDelay;
    private bool _firstTickLogged;

    public override void _Ready()
    {
        _head = GetNode<Node3D>("Head");
        _collision = GetNode<CollisionShape3D>("Collision");
        _capsule = (CapsuleShape3D)_collision.Shape;
        _standHeadY = _head.Position.Y;
        _crouchHeadY = _standHeadY - 0.45f;

        Input.MouseMode = Input.MouseModeEnum.Captured;
        TimeSystem.Instance.MinuteTicked += OnMinuteTicked;
    }

    public override void _ExitTree()
    {
        if (TimeSystem.Instance is not null)
            TimeSystem.Instance.MinuteTicked -= OnMinuteTicked;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (_dead || Game.Instance.State != Game.GameState.Playing)
            return;

        if (@event is InputEventMouseMotion motion)
        {
            RotateY(-motion.Relative.X * MouseSensitivity);
            Vector3 headRot = _head.Rotation;
            headRot.X = Mathf.Clamp(headRot.X - motion.Relative.Y * MouseSensitivity,
                                    Mathf.DegToRad(-89f), Mathf.DegToRad(89f));
            _head.Rotation = headRot;
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_dead)
            return;

        float dt = (float)delta;
        Vector3 velocity = Velocity;

        if (!IsOnFloor())
            velocity += GetGravity() * dt;

        if (Input.IsActionJustPressed("crouch"))
            SetCrouched(!_crouched);

        if (IsOnFloor() && !_crouched && Input.IsActionJustPressed("jump"))
            velocity.Y = JumpVelocity;

        Vector2 inputDir = Input.GetVector("move_left", "move_right", "move_forward", "move_back");
        Vector3 direction = Transform.Basis * new Vector3(inputDir.X, 0f, inputDir.Y);
        bool moving = direction.LengthSquared() > 0.0001f;
        if (moving)
            direction = direction.Normalized();

        bool wantsSprint = Input.IsActionPressed("sprint") && moving && !_crouched;
        IsSprinting = wantsSprint && Stamina > 1f && Stats.Fatigue > 10f;

        float speed = _crouched ? CrouchSpeed : IsSprinting ? SprintSpeed : WalkSpeed;
        velocity.X = direction.X * speed;
        velocity.Z = direction.Z * speed;

        Velocity = velocity;
        MoveAndSlide();

        // Stamina: sprint drains, standing/walking regenerates after a short delay.
        if (IsSprinting)
        {
            Stamina = Mathf.Max(0f, Stamina - StaminaDrainPerSec * dt);
            _staminaRegenDelay = 0.8f;
        }
        else
        {
            _staminaRegenDelay -= dt;
            if (_staminaRegenDelay <= 0f)
                Stamina = Mathf.Min(100f, Stamina + StaminaRegenPerSec * dt);
        }

        // Smooth crouch camera height.
        float targetHeadY = _crouched ? _crouchHeadY : _standHeadY;
        Vector3 headPos = _head.Position;
        headPos.Y = Mathf.Lerp(headPos.Y, targetHeadY, 12f * dt);
        _head.Position = headPos;
    }

    private void SetCrouched(bool crouched)
    {
        _crouched = crouched;
        _capsule.Height = crouched ? CrouchHeight : StandHeight;
        _collision.Position = new Vector3(0f, _capsule.Height / 2f, 0f);
    }

    private void OnMinuteTicked(int day, int hour, int minute)
    {
        if (_dead)
            return;

        float hourOfDay = hour + minute / 60f;
        LastFeelsLikeC = TemperatureModel.FeelsLikeC(IsIndoors, hourOfDay);
        Stats.Tick(LastFeelsLikeC, IsSprinting ? 4f : 1f);

        if (!_firstTickLogged || minute % 10 == 0)
        {
            _firstTickLogged = true;
            GD.Print($"[Player] D{day} {hour:00}:{minute:00} | " +
                     $"Cond {Stats.Condition:0} Warm {Stats.Warmth:0} Hun {Stats.Hunger:0} " +
                     $"Thi {Stats.Thirst:0} Fat {Stats.Fatigue:0} | " +
                     $"feels {LastFeelsLikeC:0.#}C ({(IsIndoors ? "indoors" : "outdoors")})");
        }

        if (Stats.IsDead)
        {
            _dead = true;
            SetPhysicsProcess(false);
            EventBus.RaisePlayerDied();
        }
    }
}
