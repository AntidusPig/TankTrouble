using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using Godot;
using Godot.Collections;

namespace TankTrouble.AI;

[GlobalClass]
public partial class SudokuSolverAI : Node
{
    private sealed class ShotClock
    {
        public ulong NextShot;
        public int LastTeam;
    }

    private static readonly ConditionalWeakTable<Node2D, ShotClock> Clocks = new();
    private const int MaxTeams = 8;
    private const string SolverGroup = "sudoku_solver";
    private const string DriverMetadata = "_active_tank_brain";

    [Export(PropertyHint.Range, "1.5,10.0,0.1")]
    public float SecondsBetweenPuzzleShots { get; set; } = 2.4f;

    [Export(PropertyHint.Range, "0,2,1")]
    public int Difficulty { get; set; } = 2;

    private CharacterBody2D _tank = null!;
    private Node2D _maze = null!;
    private Node _navigation = null!;
    private ShotClock _clock = null!;
    private Node2D? _target;
    private Vector2 _direction;
    private Vector2 _stage;
    private Vector2[] _route = System.Array.Empty<Vector2>();
    private int _nextWaypoint;
    private Vector2 _progress;
    private float _stuckTime;
    private float _wait;
    private bool _readyToShoot;
    private int _avoidIndex = -1;
    private int _lastWorkedIndex = -1;
    private int _valueBeforeShot;
    private float _flightLeft;
    private bool _distantTarget;
    private bool _lastShotDistant;
    private int _patrolIndex;
    private Vector2[] _patrolRoute = System.Array.Empty<Vector2>();
    private int _patrolWaypoint;
    private readonly System.Collections.Generic.Dictionary<int, int> _turnAttempts = new();
    public int TargetIndex { get; private set; } = -1;

    public override void _Ready()
    {
        if (GetParent() is not CharacterBody2D tank || !tank.HasMethod("set_ai_controls") ||
            GetTree().GetFirstNodeInGroup("MazeBuilder") is not Node2D maze ||
            !maze.HasMethod("remaining_cells") || tank.HasMeta(DriverMetadata))
        {
            SetPhysicsProcess(false);
            return;
        }
        _tank = tank;
        _maze = maze;
        _navigation = _maze.GetNode("MazeAStar");
        _clock = Clocks.GetValue(maze, _ => new ShotClock { NextShot = Engine.GetPhysicsFrames() + Gap() });
        _progress = tank.GlobalPosition;
        _tank.SetMeta(DriverMetadata, true);
        _tank.Call("enable_ai_controls", true);
        AddToGroup(SolverGroup);
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
        _readyToShoot = false;
        if (_tank.Get("pending_destroy").AsBool() || _maze.Get("solved").AsBool())
        {
            Stop();
            return;
        }

        if (_flightLeft > 0f)
        {
            _flightLeft -= (float)delta;
            if (_flightLeft > 0f && IsInstanceValid(_target) &&
                _target!.Get("current_value").AsInt32() == _valueBeforeShot)
            {
                Stop();
                return;
            }
            _flightLeft = 0f;
            _target = null;
            TargetIndex = -1;
            _wait = 0f;
        }

        if (!TargetNeedsEdit())
        {
            _target = null;
            TargetIndex = -1;
            _wait -= (float)delta;
            if (_wait <= 0f)
            {
                SelectTarget();
                _wait = 0.35f;
            }
            if (_target is null)
            {
                Patrol((float)delta);
                return;
            }
            _patrolRoute = System.Array.Empty<Vector2>();
        }

        float scale = Mathf.Abs(_tank.GlobalScale.X);
        Vector2 location = _tank.GlobalPosition;
        if (location.DistanceTo(_stage) > 8f * scale)
        {
            if (location.DistanceTo(_progress) > 15f * scale)
            {
                _progress = location;
                _stuckTime = 0f;
            }
            else
                _stuckTime += (float)delta;
            if (_stuckTime >= 3.2f)
            {
                AbandonTarget();
                return;
            }
            Steer(Waypoint(location, scale), (float)delta);
            return;
        }

        float diff = Mathf.AngleDifference(_tank.GlobalRotation, _direction.Angle());
        float turnSpeed = (float)_tank.Get("rotate_speed").AsDouble();
        if (Mathf.Abs(diff) > 0.018f)
        {
            _tank.Call("set_ai_controls", Mathf.Clamp(diff / (turnSpeed * (float)delta), -1f, 1f), 0f, false);
            return;
        }

        ulong now = Engine.GetPhysicsFrames();
        if (_tank.Get("time_since_last_shot").AsDouble() > 0.0)
        {
            Stop();
            return;
        }
        if (!MuzzleHitsTarget())
        {
            _stuckTime += (float)delta;
            if (_stuckTime >= 1.35f)
                AbandonTarget();
            else
                Stop();
            return;
        }

        _readyToShoot = true;
        _stuckTime = 0;
        int team = _tank.Get("team").AsInt32();
        if (now < _clock.NextShot || HasEarlierTurn(team))
        {
            Stop();
            return;
        }

        _clock.NextShot = now + Gap();
        _clock.LastTeam = team;
        _readyToShoot = false;
        _lastWorkedIndex = TargetIndex;
        _lastShotDistant = _distantTarget;
        _valueBeforeShot = _target!.Get("current_value").AsInt32();
        float flightDistance = _tank.GetNode<Node2D>("body/head_mount/head/muzzle").GlobalPosition.DistanceTo(_target.GlobalPosition);
        _flightLeft = flightDistance / ShellSpeed() + 0.22f;
        _tank.Call("set_ai_controls", 0f, 0f, true);
    }

    private bool HasEarlierTurn(int team)
    {
        int order = TurnOrder(team);
        foreach (var node in GetTree().GetNodesInGroup(SolverGroup))
            if (node is SudokuSolverAI solver && solver._maze == _maze && solver._readyToShoot &&
                TurnOrder(solver._tank.Get("team").AsInt32()) < order && solver.TargetNeedsEdit())
                return true;
        return false;
    }

    private int TurnOrder(int team) => (team - _clock.LastTeam + MaxTeams - 1) % MaxTeams;

    private ulong Gap() => (ulong)Math.Ceiling(SecondsBetweenPuzzleShots *
        (Difficulty switch { 0 => 2.0, 1 => 1.4, _ => 1.0 }) * Engine.PhysicsTicksPerSecond);

    private bool TargetNeedsEdit()
    {
        if (!IsInstanceValid(_target) || TargetIndex < 0 || _target!.Get("fixed").AsBool())
            return false;
        var answer = _maze.Get("solution").AsInt32Array();
        return TargetIndex < answer.Length && _target.Get("current_value").AsInt32() != answer[TargetIndex];
    }

    private void SelectTarget()
    {
        var claimed = new HashSet<int>();
        foreach (var node in GetTree().GetNodesInGroup(SolverGroup))
            if (node is SudokuSolverAI solver && solver != this && solver._maze == _maze && solver.TargetIndex >= 0)
                claimed.Add(solver.TargetIndex);

        var cells = _maze.Get("sudoku_numbers").AsGodotArray();
        var answers = _maze.Get("solution").AsInt32Array();
        Vector2 location = _tank.GlobalPosition;
        if (!_lastShotDistant && TryDistantTarget(cells, answers, claimed, location))
        {
            _avoidIndex = -1;
            _stuckTime = 0f;
            _progress = location;
            return;
        }

        _distantTarget = false;
        float best = float.PositiveInfinity;
        for (int i = 0; i < answers.Length; i++)
        {
            if (claimed.Contains(i) || i == _avoidIndex || cells[i].AsGodotObject() is not Node2D cell ||
                cell.Get("fixed").AsBool() || cell.Get("current_value").AsInt32() == answers[i])
                continue;
            var route = Path(location, cell.GlobalPosition);
            if (route.Length == 0)
                continue;
            float cost = route.Length + location.DistanceTo(route[0]) / 160f +
                location.DistanceTo(cell.GlobalPosition) / 2400f;
            if (i == _lastWorkedIndex)
                cost += answers.Length;
            if (cost >= best)
                continue;

            best = cost;
            TargetIndex = i;
            _target = cell;
            _route = route;
            _nextWaypoint = 0;
            Vector2 arrival = route.Length > 1 ? cell.GlobalPosition - route[^2] : cell.GlobalPosition - location;
            if (arrival.LengthSquared() < 1f)
                arrival = Vector2.Right;
            _direction = Mathf.Abs(arrival.X) >= Mathf.Abs(arrival.Y)
                ? new Vector2(Mathf.Sign(arrival.X), 0)
                : new Vector2(0, Mathf.Sign(arrival.Y));
            _direction = _direction.Rotated(_turnAttempts.GetValueOrDefault(i) * Mathf.Pi / 2f);
            _stage = cell.GlobalPosition - _direction * 43f * Mathf.Abs(_tank.GlobalScale.X);
        }
        _avoidIndex = -1;
        _stuckTime = 0f;
        _progress = location;
    }

    private bool TryDistantTarget(Godot.Collections.Array cells, int[] answers, HashSet<int> claimed, Vector2 location)
    {
        float scale = Mathf.Abs(_tank.GlobalScale.X);
        float tile = (float)_maze.Get("grid_size").AsDouble() * Mathf.Abs(_maze.GlobalScale.X);
        float muzzleOffset = location.DistanceTo(_tank.GetNode<Node2D>("body/head_mount/head/muzzle").GlobalPosition);
        var stats = _tank.Get("shell_stats").AsGodotObject()!;
        float reach = Mathf.Min(tile * 3.4f, ShellSpeed() * (float)stats.Get("shell_lifetime").AsDouble() * 0.85f);
        float best = float.PositiveInfinity;
        for (int i = 0; i < answers.Length; i++)
        {
            if (claimed.Contains(i) || i == _avoidIndex || i == _lastWorkedIndex ||
                cells[i].AsGodotObject() is not Node2D cell || cell.Get("fixed").AsBool())
                continue;
            int value = cell.Get("current_value").AsInt32();
            int maximum = cell.Get("max_value").AsInt32();
            int edits = (answers[i] - value + maximum) % maximum;
            if (value == 0)
                edits = answers[i];
            if (edits <= 1)
                continue;

            Vector2 offset = cell.GlobalPosition - location;
            float distance = offset.Length();
            if (distance <= tile * 0.92f || distance > reach ||
                Mathf.Min(Mathf.Abs(offset.X), Mathf.Abs(offset.Y)) > 34f * scale)
                continue;
            Vector2 direction = offset / distance;
            Vector2 muzzle = location + direction * muzzleOffset;
            var barrel = PhysicsRayQueryParameters2D.Create(location, muzzle, 1, new Array<Rid> { _tank.GetRid() });
            if (_tank.GetWorld2D().DirectSpaceState.IntersectRay(barrel).Count > 0 ||
                !FirstEditableHitIs(muzzle, cell.GlobalPosition, cell))
                continue;

            float cost = distance + 90f * Mathf.Abs(Mathf.AngleDifference(_tank.GlobalRotation, direction.Angle()));
            if (cost >= best)
                continue;
            best = cost;
            TargetIndex = i;
            _target = cell;
            _direction = direction;
        }

        if (_target is null)
            return false;
        _distantTarget = true;
        _stage = location;
        _route = System.Array.Empty<Vector2>();
        _nextWaypoint = 0;
        return true;
    }

    private float ShellSpeed() => Math.Max(1f, (float)_tank.Get("shell_stats").AsGodotObject()!
        .Get("shell_speed").AsDouble() * Mathf.Abs(_tank.GlobalScale.X));

    private Vector2 Waypoint(Vector2 position, float scale)
    {
        // Finish a corridor at its center before turning through the next opening.
        while (_nextWaypoint < _route.Length && position.DistanceTo(_route[_nextWaypoint]) < 8f * scale)
            _nextWaypoint++;
        return _nextWaypoint < _route.Length ? _route[_nextWaypoint] : _stage;
    }

    private Vector2[] Path(Vector2 start, Vector2 goal) =>
        _navigation.Call("get_global_enemy_path", start, goal).AsVector2Array();

    private void Steer(Vector2 waypoint, float delta)
    {
        Vector2 movement = waypoint - _tank.GlobalPosition;
        if (movement.LengthSquared() < 1f)
        {
            Stop();
            return;
        }
        float angle = Mathf.AngleDifference(_tank.GlobalRotation, movement.Angle());
        float drive = 1f;
        if (Mathf.Abs(angle) > Mathf.Pi / 2f)
        {
            angle = Mathf.AngleDifference(_tank.GlobalRotation, movement.Angle() + Mathf.Pi);
            drive = -1f;
        }
        if (Mathf.Abs(angle) > 0.08f)
            drive = 0f;
        else
        {
            float speed = (float)_tank.Get("move_speed").AsDouble() * Mathf.Abs(_tank.GlobalScale.X);
            drive *= Mathf.Min(1f, movement.Length() / Mathf.Max(1f, speed * delta));
        }
        float turnSpeed = (float)_tank.Get("rotate_speed").AsDouble();
        _tank.Call("set_ai_controls", Mathf.Clamp(angle / (turnSpeed * delta), -1f, 1f), drive, false);
    }

    private bool MuzzleHitsTarget()
    {
        Vector2 start = _tank.GetNode<Node2D>("body/head_mount/head/muzzle").GlobalPosition;
        Vector2 forward = Vector2.FromAngle(_tank.GlobalRotation);
        float distance = _distantTarget ? Math.Max(10f, (_target!.GlobalPosition - start).Dot(forward)) : 10f;
        return FirstEditableHitIs(start, start + forward * distance, _target!);
    }

    private bool FirstEditableHitIs(Vector2 start, Vector2 end, Node2D target)
    {
        var query = PhysicsRayQueryParameters2D.Create(start, end, 1);
        query.CollideWithAreas = true;
        query.HitFromInside = true;
        var exclusions = new Array<Rid> { _tank.GetRid() };
        var space = _tank.GetWorld2D().DirectSpaceState;
        while (true)
        {
            query.Exclude = exclusions;
            var hit = space.IntersectRay(query);
            if (hit.Count == 0 || hit["collider"].AsGodotObject() is not Area2D area)
                return false;
            var cell = area.GetParent();
            if (cell == target)
                return true;
            if (cell is null || !cell.Get("fixed").AsBool())
                return false;
            exclusions.Add(area.GetRid());
        }
    }

    private void AbandonTarget()
    {
        _avoidIndex = TargetIndex;
        _turnAttempts[TargetIndex] = (_turnAttempts.GetValueOrDefault(TargetIndex) + 1) % 4;
        TargetIndex = -1;
        _target = null;
        _wait = 0f;
        Stop();
    }

    private void Patrol(float delta)
    {
        Vector2 location = _tank.GlobalPosition;
        float tolerance = 8f * Mathf.Abs(_tank.GlobalScale.X);
        while (_patrolWaypoint < _patrolRoute.Length &&
               location.DistanceTo(_patrolRoute[_patrolWaypoint]) < tolerance)
            _patrolWaypoint++;

        if (_patrolWaypoint >= _patrolRoute.Length)
        {
            var cells = _maze.Get("sudoku_numbers").AsGodotArray();
            int team = _tank.Get("team").AsInt32();
            _patrolIndex = (_patrolIndex + 5 + team) % cells.Count;
            var goal = (Node2D)cells[_patrolIndex].AsGodotObject();
            _patrolRoute = Path(location, goal.GlobalPosition);
            _patrolWaypoint = 0;
        }

        if (_patrolWaypoint < _patrolRoute.Length)
            Steer(_patrolRoute[_patrolWaypoint], delta);
    }

    private void Stop() => _tank.Call("set_ai_controls", 0f, 0f, false);
}
