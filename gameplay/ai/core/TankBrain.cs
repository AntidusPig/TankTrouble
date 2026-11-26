using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Godot.Collections;

namespace TankTrouble.AI;

public abstract partial class TankBrain : Node
{
    [Export(PropertyHint.Range, "0.08,0.5,0.01")]
    public double ThinkInterval { get; set; } = 0.14;

    [Export(PropertyHint.Range, "0,2,1")]
    public int Difficulty { get; set; } = 2;

    private float _shotDelay;
    private double DecisionInterval => Difficulty switch
    {
        0 => Math.Max(0.45, ThinkInterval),
        1 => Math.Max(0.25, ThinkInterval),
        _ => Math.Max(0.08, ThinkInterval)
    };

    private const string DriverMetadata = "_active_tank_brain";
    internal const string Tanks = "arena_tank";
    internal const string Pickups = "arena_pickup";
    internal const string Shells = "arena_weapon_effect";

    private CharacterBody2D _tank = null!;
    private Node2D? _maze;
    private Node? _navigation;
    private Situation? _situation;
    private Option _command;
    private Vector2 _waypoint;
    private double _untilThink;
    private ulong _lastPositionId;
    private Vector2 _lastPosition;
    private Vector2 _lastOpponentPosition;
    private Vector2 _progressAnchor;
    private double _stalledTime;
    private double _recoveryTime;
    private Random _patrolRandom = null!;
    private Vector2? _patrolDestination;
    private Vector2 _patrolProgress;
    private double _patrolIdle;

    public string CurrentAction => _situation is null && _command.Action == Maneuver.Chase ? "Patrol" : _command.Action.ToString();
    public int Decisions { get; private set; }
    public int FireDecisions { get; private set; }
    public int BankDecisions { get; private set; }
    public int DodgeDecisions { get; private set; }
    public int PickupDecisions { get; private set; }

    public override void _Ready()
    {
        if (GetParent() is not CharacterBody2D tank || !tank.HasMethod("set_ai_controls"))
        {
            GD.PushError($"{Name} requires a TankBase parent.");
            SetPhysicsProcess(false);
            return;
        }
        if (tank.HasMeta(DriverMetadata))
        {
            GD.PushError($"{tank.Name} can only have one active AI component.");
            SetPhysicsProcess(false);
            return;
        }
        _tank = tank;
        _progressAnchor = tank.GlobalPosition;
        tank.SetMeta(DriverMetadata, true);
        _tank.Call("enable_ai_controls", true);
        _maze = GetTree().GetFirstNodeInGroup("MazeBuilder") as Node2D;
        _navigation = _maze?.GetNodeOrNull("MazeAStar");
        long seed = _maze?.Get("generation_seed").AsInt64() ?? -1;
        _patrolRandom = new Random(seed < 0 ? Random.Shared.Next() :
            unchecked((int)seed ^ (int)_tank.GlobalPosition.X * 31 ^ (int)_tank.GlobalPosition.Y));
        _patrolProgress = tank.GlobalPosition;
        if (Difficulty < 2)
        {
            _command = new(Maneuver.Hold, tank.GlobalPosition, 0f);
            _untilThink = DecisionInterval;
        }
    }

    public override void _ExitTree()
    {
        if (IsInstanceValid(_tank))
        {
            _tank.RemoveMeta(DriverMetadata);
            _tank.Call("enable_ai_controls", false);
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_tank.Get("pending_destroy").AsBool())
            return;
        _shotDelay = Math.Max(0f, _shotDelay - (float)delta);
        _untilThink -= delta;
        if (_untilThink <= 0)
        {
            var interval = DecisionInterval;
            _untilThink += interval;
            _situation = Observe((float)interval);
            if (_situation is not null)
            {
                _command = Decide(_situation);
                _command = RecoverMovement(_situation, _command, interval);
                Decisions++;
                if (_command.Action == Maneuver.Fire)
                {
                    FireDecisions++;
                    if (_situation.Shot is { Bounces: > 0 })
                        BankDecisions++;
                }
                if (_command.Action == Maneuver.Dodge)
                    DodgeDecisions++;
                if (_command.Action is Maneuver.Repair or Maneuver.Rearm or Maneuver.Shield)
                    PickupDecisions++;
                _waypoint = Waypoint(_situation.Self.Position, _situation.CellSize, _command, _situation.Foe.Body);
                _patrolDestination = null;
                _patrolIdle = 0;
            }
            else
            {
                _command = Patrol(interval);
                _waypoint = Waypoint(_tank.GlobalPosition, CellSize(), _command, null);
            }
        }
        Drive((float)delta, _command, _waypoint, _situation?.Shot, _situation?.ReadyToFire == true);
    }

    protected abstract Option Decide(Situation situation);

    private Option RecoverMovement(Situation state, Option command, double interval)
    {
        _recoveryTime = Math.Max(0, _recoveryTime - interval);
        float distance = _progressAnchor.DistanceTo(state.Self.Position);
        if (distance >= state.CellSize * 0.36f || command.Action == Maneuver.Fire)
        {
            _progressAnchor = state.Self.Position;
            _stalledTime = 0;
        }
        else
        {
            _stalledTime += interval;
            if (_stalledTime >= 0.84)
            {
                _recoveryTime = 1.65;
                _stalledTime = 0;
            }
        }
        if (_recoveryTime > 0 && command.Action != Maneuver.Fire &&
            (command.Action != Maneuver.Dodge || state.Risk < 0.45f))
            return state.Find(Maneuver.Chase);
        return command;
    }

    private float CellSize() => _maze is null ? 200f :
        Math.Max(40f, (float)_maze.Get("grid_size").AsDouble() * Math.Abs(_maze.GlobalScale.X));

    private Option Patrol(double interval)
    {
        var self = ReadTank(_tank);
        float cellSize = CellSize();
        if (_patrolProgress.DistanceTo(self.Position) >= cellSize * 0.22f)
        {
            _patrolIdle = 0;
            _patrolProgress = self.Position;
        }
        else
            _patrolIdle += interval;

        var options = new List<Option>();
        bool armed = _tank.Get("loadout").AsGodotObject()?.Get("weapon").AsGodotObject() is not null;
        AddPickupOptions(self, cellSize, armed, _tank.Get("shield_points").AsInt32() > 0, options);
        if (_patrolIdle < 1.4 && options.Count > 0)
        {
            var pickup = options.MaxBy(option => option.Value);
            if (pickup.Value > 0.34f && Path(self.Position, pickup.Destination).Length <= 6)
                return pickup;
        }

        if (_patrolDestination is null || _patrolDestination.Value.DistanceTo(self.Position) < cellSize * 0.20f ||
            _patrolIdle > 1.7)
        {
            _patrolDestination = FindPatrolDestination(self.Position, cellSize);
            _patrolProgress = self.Position;
            _patrolIdle = 0;
        }
        return new(Maneuver.Chase, _patrolDestination.Value, 0f);
    }

    private Vector2 FindPatrolDestination(Vector2 start, float cellSize)
    {
        if (_maze is not null)
        {
            var size = _maze.Get("maze_size").AsVector2I();
            Vector2 alternate = start;
            for (int i = 0; i < 20; i++)
            {
                var cell = new Vector2I(_patrolRandom.Next(size.X), _patrolRandom.Next(size.Y));
                var point = _maze.Call("get_cell_position", cell.X, cell.Y).AsVector2();
                var route = Path(start, point);
                if (route.Length is >= 3 and <= 6)
                    return point;
                if (route.Length >= 2)
                    alternate = route[Math.Min(route.Length - 1, 4)];
            }
            if (alternate != start)
                return alternate;
        }

        var space = _tank.GetWorld2D().DirectSpaceState;
        var exclusions = new Array<Rid> { _tank.GetRid() };
        float angle = (float)_patrolRandom.NextDouble() * Mathf.Tau;
        for (int i = 0; i < 8; i++)
        {
            Vector2 direction = Vector2.FromAngle(angle + i * Mathf.Tau / 8f);
            Vector2 goal = start + direction * cellSize * 0.75f;
            if (HitBody(space, start, goal, exclusions) is null)
                return goal;
        }
        return start;
    }

    private Situation? Observe(float sampleInterval)
    {
        var self = ReadTank(_tank);
        var all = GetTree().GetNodesInGroup(Tanks)
            .OfType<CharacterBody2D>()
            .Where(body => !body.IsQueuedForDeletion() && !body.Get("pending_destroy").AsBool())
            .Select(ReadTank).ToArray();
        var enemies = all.Where(other => other.Body != _tank && (other.Team != self.Team || self.Team == 0))
            .OrderBy(other => other.Position.DistanceSquaredTo(self.Position)).ToArray();
        if (enemies.Length == 0)
            return null;

        var foe = enemies[0];
        float cellSize = CellSize();
        var range = self.Position.DistanceTo(foe.Position);
        var space = _tank.GetWorld2D().DirectSpaceState;
        var exclusions = new Array<Rid> { self.Body.GetRid() };
        var seen = HitBody(space, self.Position, foe.Position, exclusions);
        var clearLane = seen == foe.Body;
        var loadout = (GodotObject?)_tank.Get("loadout").AsGodotObject();
        var weapon = loadout?.Get("weapon").AsGodotObject();
        var stats = weapon?.Get("weapon_stats").AsGodotObject() ?? _tank.Get("shell_stats").AsGodotObject();
        bool ready = _shotDelay <= 0f && _tank.Get("time_since_last_shot").AsDouble() <= 0.10;
        bool shielded = _tank.Get("shield_points").AsInt32() > 0;
        bool foeShielded = foe.Body.Get("shield_points").AsInt32() > 0;
        Vector2 foeVelocity = foe.Body.Velocity.LimitLength(310f);
        if (_lastPositionId == foe.Body.GetInstanceId())
            foeVelocity = foeVelocity.Lerp(((foe.Position - _lastOpponentPosition) / sampleInterval).LimitLength(310f), 0.35f);
        bool blocked = Decisions > 1 && _lastPosition.DistanceSquaredTo(self.Position) < 4f;
        _lastPosition = self.Position;
        _lastOpponentPosition = foe.Position;
        _lastPositionId = foe.Body.GetInstanceId();

        var traces = Difficulty == 0 ? System.Array.Empty<CombatPrediction.Leg>() :
            CombatPrediction.VisibleShells(space, GetTree().GetNodesInGroup(Shells), all, self.Position, cellSize);
        float risk = CombatPrediction.Threat(traces, self.Position, Vector2.Zero, 0.65f);
        var shot = stats is null || (range > cellSize * 5f && stats.Get("laser_range").AsDouble() <= 0) ? null :
            CombatPrediction.BestShot(space, self, foe, foeVelocity * (Difficulty switch { 0 => 0f, 1 => 0.65f, _ => 1f }),
                all, stats, cellSize, Difficulty);
        var options = new List<Option>(9) { new(Maneuver.Hold, self.Position, 0.06f) };
        options.Add(new(Maneuver.Chase, foe.Position, clearLane ? 0.36f : 0.57f));
        if (shot is { } candidate && (Difficulty == 2 || ready))
            options.Add(new(Maneuver.Fire, foe.Position, candidate.Quality * (ready ? 1f : 0.65f)));

        AddLocalOptions(space, self, foe, cellSize, traces, risk, clearLane, blocked, options);
        AddPickupOptions(self, cellSize, weapon is not null, shielded, options);
        return new Situation(self, foe, cellSize, range, risk, clearLane, weapon is not null, shielded,
            foeShielded, ready, shot, options);
    }

    private void AddLocalOptions(PhysicsDirectSpaceState2D space, TankView self, TankView foe, float cellSize,
        IReadOnlyList<CombatPrediction.Leg> traces, float risk, bool clearLane, bool blocked, List<Option> options)
    {
        Vector2 away = (self.Position - foe.Position).Normalized();
        var exclusions = new Array<Rid> { _tank.GetRid() };
        float bestDodge = float.NegativeInfinity, bestRetreat = float.NegativeInfinity, bestFlank = float.NegativeInfinity;
        Vector2 dodge = self.Position, retreat = self.Position, flank = self.Position;
        for (int index = 0; index < 8; index++)
        {
            Vector2 heading = Vector2.FromAngle(index * Mathf.Tau / 8f);
            Vector2 goal = self.Position + heading * (cellSize * 0.62f);
            if (HitBody(space, self.Position, goal + heading * 35f, exclusions) is not null)
                continue;
            float turnAngle = Math.Abs(Mathf.AngleDifference(_tank.Rotation, heading.Angle()));
            float turnCost = Math.Min(turnAngle, Mathf.Pi - turnAngle) / Mathf.Pi;
            float velocity = (float)_tank.Get("move_speed").AsDouble() * Math.Abs(_tank.GlobalScale.X);
            float exposure = CombatPrediction.Threat(traces, self.Position, heading * velocity, 0.55f);
            bool cover = HitBody(space, goal, foe.Position, exclusions) != foe.Body;
            float evade = 1f - exposure - turnCost * 0.42f;
            float escape = heading.Dot(away) * 0.24f + evade * 0.35f + (cover ? 0.31f : 0f);
            float flankValue = (cover ? 0.07f : 0.35f) + evade * 0.24f +
                (1f - Math.Abs(heading.Dot(away))) * 0.14f + (blocked ? 0.16f : 0f);
            if (evade > bestDodge) { bestDodge = evade; dodge = goal; }
            if (escape > bestRetreat) { bestRetreat = escape; retreat = goal; }
            if (flankValue > bestFlank) { bestFlank = flankValue; flank = goal; }
        }
        if (dodge != self.Position && risk > 0.08f)
            options.Add(new(Maneuver.Dodge, dodge, Mathf.Clamp(bestDodge * risk + 0.35f, 0f, 1.25f)));
        if (retreat != self.Position)
            options.Add(new(Maneuver.Retreat, retreat, bestRetreat * (1f - self.Hull * 0.55f)));
        if (flank != self.Position)
            options.Add(new(Maneuver.Flank, flank, bestFlank * (clearLane && !blocked ? 0.68f : 1f)));
    }

    private void AddPickupOptions(TankView self, float cellSize, bool armed, bool shielded, List<Option> options)
    {
        var available = new System.Collections.Generic.Dictionary<Maneuver, Option>();
        foreach (var node in GetTree().GetNodesInGroup(Pickups))
        {
            if (node is not Node2D pickup || pickup.IsQueuedForDeletion() || pickup.Get("collected").AsBool())
                continue;
            var definition = pickup.Get("definition").AsGodotObject();
            if (definition is null)
                continue;
            Maneuver action;
            float benefit;
            if (definition.Get("healing").AsInt32() > 0)
            {
                if (self.Hull >= 1f)
                    continue;
                action = Maneuver.Repair;
                benefit = 0.63f + (1f - self.Hull) * 0.85f;
            }
            else if (definition.Get("shield").AsInt32() > 0)
            {
                if (shielded)
                    continue;
                action = Maneuver.Shield;
                benefit = 0.84f;
            }
            else
            {
                action = Maneuver.Rearm;
                benefit = armed ? 0.44f : 0.88f;
            }
            var path = Path(self.Position, pickup.GlobalPosition);
            float distance = path.Length == 0 ? self.Position.DistanceTo(pickup.GlobalPosition) : 0f;
            for (int i = 1; i < path.Length; i++)
                distance += path[i].DistanceTo(path[i - 1]);
            float value = benefit / (1f + distance / (cellSize * 3.2f));
            if (!available.TryGetValue(action, out var older) || value > older.Value)
                available[action] = new(action, pickup.GlobalPosition, value);
        }
        foreach (var option in available.Values)
            options.Add(option);
    }

    private Vector2 Waypoint(Vector2 start, float cellSize, Option command, CharacterBody2D? foe)
    {
        if (command.Action is Maneuver.Fire or Maneuver.Hold or Maneuver.Dodge or Maneuver.Retreat or Maneuver.Flank)
            return command.Destination;
        var path = Path(start, command.Destination);
        if (path.Length < 2)
            return command.Destination;
        var space = _tank.GetWorld2D().DirectSpaceState;
        var exclusions = new Array<Rid> { _tank.GetRid() };
        if (foe is not null)
            exclusions.Add(foe.GetRid());
        for (int i = Math.Min(path.Length - 1, 2); i > 0; i--)
        {
            var goal = path[i];
            var along = (goal - start).Normalized();
            if (along == Vector2.Zero)
                continue;
            var side = along.Orthogonal() * (42f * Math.Abs(_tank.GlobalScale.X));
            if (HitBody(space, start + side, goal + side, exclusions) is null &&
                HitBody(space, start - side, goal - side, exclusions) is null &&
                HitBody(space, start, goal, exclusions) is null)
                return goal;
        }
        return start.DistanceTo(path[0]) > cellSize * 0.17f ? path[0] : path[1];
    }

    private void Drive(float delta, Option command, Vector2 waypoint, Shot? aimedShot, bool readyToFire)
    {
        if (command.Action == Maneuver.Hold)
        {
            _tank.Call("set_ai_controls", 0.0, 0.0, false);
            return;
        }
        Vector2 displacement = waypoint - _tank.GlobalPosition;
        var shot = command.Action == Maneuver.Fire ? aimedShot : null;
        float angle = shot?.Angle ?? displacement.Angle();
        float turnRate = (float)_tank.Get("rotate_speed").AsDouble();
        float tolerance = Math.Max(0.028f, turnRate * delta * 0.52f);
        float diff = Mathf.AngleDifference(_tank.GlobalRotation, angle);
        float drive = 0f;
        if (shot is null && displacement.LengthSquared() > 300f)
        {
            float direction = 1f;
            if (Math.Abs(diff) > Mathf.Pi * 0.5f)
            {
                diff = Mathf.AngleDifference(_tank.GlobalRotation, angle + Mathf.Pi);
                direction = -1f;
            }
            if (Math.Abs(diff) < (command.Action == Maneuver.Dodge ? 0.9f : 0.52f))
                drive = direction;
        }
        bool fire = shot is not null && Math.Abs(diff) <= tolerance && readyToFire &&
            _shotDelay <= 0f && _tank.Get("time_since_last_shot").AsDouble() <= 0.0;
        if (fire)
            _shotDelay = Difficulty switch { 0 => 1.45f, 1 => 0.72f, _ => 0f };
        drive *= Difficulty switch { 0 => 0.72f, 1 => 0.90f, _ => 1f };
        float turn = Math.Abs(diff) > tolerance ? Math.Sign(diff) : 0f;
        _tank.Call("set_ai_controls", turn, drive, fire);
    }

    private Vector2[] Path(Vector2 start, Vector2 goal) =>
        _navigation?.Call("get_global_enemy_path", start, goal).AsVector2Array() ?? System.Array.Empty<Vector2>();

    private static TankView ReadTank(CharacterBody2D body) => new(body,
        body.Get("team").AsInt32(), (float)body.Get("health").AsDouble(), (float)body.Get("max_health").AsDouble());

    private static GodotObject? HitBody(PhysicsDirectSpaceState2D space, Vector2 start, Vector2 end, Array<Rid> exclusions)
    {
        var query = PhysicsRayQueryParameters2D.Create(start, end);
        query.Exclude = exclusions;
        var hit = space.IntersectRay(query);
        return hit.Count == 0 ? null : hit["collider"].AsGodotObject();
    }
}
