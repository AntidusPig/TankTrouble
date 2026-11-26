using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Godot;

namespace TankTrouble.AI;

public partial class AiLab : Node2D
{
    private sealed record Match(int First, int Second, int MapSeed, int Size, bool Swap);
    private const int Methods = 4;
    private const int MaxFps = 60;
    private const int PickupTicks = 220;
    private const int PickupLifetime = 1080;
    private static readonly string[] Names = { "StateMachine", "BehaviorTree", "GOAP", "Utility", "Neural" };
    private static readonly string[] Catalog =
    {
        "repair_kit", "shield_cell", "needle_capsule", "fork_capsule",
        "breaker_capsule", "laser_capsule", "blast_capsule"
    };

    private readonly Queue<Match> _tests = new();
    private readonly List<PolicyNetwork> _opponents = new();
    private readonly List<(Area2D Pickup, int Expiry)> _pickups = new();
    private PackedScene _mazeScene = null!;
    private PackedScene _tankScene = null!;
    private PackedScene _pickupScene = null!;
    private Resource[] _catalog = null!;
    private Node2D _field = null!;
    private Node2D _maze = null!;
    private CharacterBody2D _first = null!, _second = null!;
    private TankBrain _firstBrain = null!, _secondBrain = null!;
    private PolicyNetwork _learner = null!;
    private PolicyNetwork? _fixedEvaluation;
    private Match _match = null!;
    private Random _mapRandom = null!;
    private DateTimeOffset _deadline = DateTimeOffset.MaxValue;
    private bool _training, _running, _evaluate;
    private string _checkpoint = PolicyNetwork.DefaultPath;
    private int _tick, _episodeLimit, _startSeed, _seconds, _started, _wins, _losses, _draws, _matchesRun;
    private int _reportEvery, _saveEvery;
    private long _initialEpisodes;
    private int _side;

    public override void _Ready()
    {
        var arguments = OS.GetCmdlineUserArgs();
        _training = arguments.Contains("--train");
        _evaluate = arguments.Contains("--evaluate");
        _checkpoint = Flag(arguments, "--checkpoint", PolicyNetwork.DefaultPath);
        _episodeLimit = Number(arguments, "--episodes", _training ? int.MaxValue : 0, 1, int.MaxValue);
        _startSeed = Number(arguments, "--seed", 12873, 1, 1000000000);
        _seconds = Number(arguments, "--match-seconds", _training ? 32 : 48, 8, 180);
        _reportEvery = Number(arguments, "--report-every", 25, 1, 100000);
        _saveEvery = Number(arguments, "--save-every", 10, 1, 100000);
        string until = Flag(arguments, "--until", "");
        if (until.Length > 0 && !DateTimeOffset.TryParse(until, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _deadline))
        {
            Fail("Use an ISO timestamp with a time zone for --until.");
            return;
        }
        if (_training && _episodeLimit == int.MaxValue && _deadline == DateTimeOffset.MaxValue)
        {
            Fail("Training requires --until or --episodes.");
            return;
        }
        _mazeScene = GD.Load<PackedScene>("res://maze/maze_builder.tscn");
        _tankScene = GD.Load<PackedScene>("res://tank/tank_base.tscn");
        _pickupScene = GD.Load<PackedScene>("res://gameplay/pickups/arena_pickup.tscn");
        _catalog = Catalog.Select(name => GD.Load<Resource>($"res://gameplay/pickups/catalog/{name}.tres")).ToArray();

        if (_training)
        {
            _learner = PolicyNetwork.Load(_checkpoint) ?? new PolicyNetwork(_startSeed);
            _initialEpisodes = _learner.Episodes;
            _opponents.Add(_learner.Clone());
            GD.Print($"TRAIN start checkpoint={_checkpoint} initial={_initialEpisodes} seed={_learner.Seed} deadline={_deadline:O} parameters={_learner.Parameters}");
        }
        else
        {
            int seeds = Number(arguments, "--seeds", 3, 1, 100);
            if (_evaluate)
            {
                _fixedEvaluation = PolicyNetwork.Load(_checkpoint);
                if (_fixedEvaluation is null)
                {
                    Fail($"No trained policy at {_checkpoint}.");
                    return;
                }
            }
            for (int map = 0; map < seeds; map++)
            {
                for (int first = 0; first < Methods; first++)
                    for (int second = first + 1; second < Methods; second++)
                    {
                        if (_evaluate)
                            continue;
                        _tests.Enqueue(new(first, second, _startSeed + map, 12, false));
                        _tests.Enqueue(new(first, second, _startSeed + map, 12, true));
                    }
                if (_evaluate)
                    for (int opponent = 0; opponent < Methods; opponent++)
                    {
                        _tests.Enqueue(new(4, opponent, _startSeed + map, 12, false));
                        _tests.Enqueue(new(4, opponent, _startSeed + map, 12, true));
                    }
            }
            GD.Print($"BENCH start matches={_tests.Count} board=12x12 start_seed={_startSeed} seconds={_seconds}");
        }
        CallDeferred(nameof(StartMatch));
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!_running)
            return;
        _tick++;
        if ((_tick & 63) == 0 && DateTimeOffset.UtcNow >= _deadline)
        {
            _running = false;
            CallDeferred(nameof(Finish));
            return;
        }
        foreach (var entry in _pickups)
            if (IsInstanceValid(entry.Pickup) && _tick >= entry.Expiry)
                entry.Pickup.QueueFree();
        _pickups.RemoveAll(entry => !IsInstanceValid(entry.Pickup) || entry.Pickup.IsQueuedForDeletion());
        if (_tick % PickupTicks == 0 && _pickups.Count < (_match.Size >= 10 ? 5 : 4))
            SpawnPickup();

        float first = Hull(_first);
        float second = Hull(_second);
        if (first > 0f && second > 0f && _tick < MaxFps * _seconds)
            return;
        _running = false;
        if (!_training)
            GD.Print($"MATCH seed={_match.MapSeed} swapped={_match.Swap} a={Summary(_firstBrain)} b={Summary(_secondBrain)} " +
                $"hp={first.ToString(CultureInfo.InvariantCulture)}:{second.ToString(CultureInfo.InvariantCulture)} frames={_tick}");
        Record(first, second);
        CallDeferred(nameof(StartMatch));
    }

    private void StartMatch()
    {
        if (DateTimeOffset.UtcNow >= _deadline || (_training && _started >= _episodeLimit) || (!_training && _tests.Count == 0))
        {
            Finish();
            return;
        }

        if (IsInstanceValid(_field))
        {
            RemoveChild(_field);
            _field.QueueFree();
        }
        _pickups.Clear();
        _tick = 0;
        if (_training)
        {
            long index = _learner.Episodes;
            int seed = (int)((_learner.Seed + index * 7919L) % 1000000000);
            int size = index % 9 == 8 ? 12 : index % 3 == 2 ? 8 : 6;
            _match = new Match(4, 4, seed, size, index % 2 == 1);
        }
        else
            _match = _tests.Dequeue();

        _mapRandom = new Random(_match.MapSeed ^ 9047);
        _field = new Node2D();
        AddChild(_field);
        _maze = _mazeScene.Instantiate<Node2D>();
        _maze.Set("maze_size", new Vector2I(_match.Size, _match.Size));
        _maze.Set("generation_seed", _match.MapSeed);
        if (_training)
            _maze.Set("footprint", (int)(_learner.Episodes / 3 % 4));
        _field.AddChild(_maze);
        var camera = new Camera2D { Zoom = Vector2.One * (3.8f / _match.Size) };
        _field.AddChild(camera);

        int corner = _match.Size >= 10 ? 3 : 1;
        var near = new Vector2I(corner, corner);
        var distant = new Vector2I(_match.Size - corner - 1, _match.Size - corner - 1);
        _side = _match.Swap ? 2 : 1;
        _first = SpawnTank(_match.Swap ? distant : near, _side, Colors.LightSkyBlue);
        _second = SpawnTank(_match.Swap ? near : distant, 3 - _side, Colors.LightSalmon);

        if (_training)
        {
            var learning = new NeuralSelfPlayAI
            {
                Model = _learner, Training = true, RandomSource = new Random(_match.MapSeed ^ 60991)
            };
            _firstBrain = learning;
            var historical = _opponents[_mapRandom.Next(_opponents.Count)];
            _secondBrain = new NeuralSelfPlayAI
            {
                Model = historical, Training = _learner.Episodes < 25,
                RandomSource = new Random(_match.MapSeed ^ 25127)
            };
        }
        else
        {
            _firstBrain = NewBrain(_match.First);
            _secondBrain = NewBrain(_match.Second);
        }
        _first.AddChild(_firstBrain);
        _second.AddChild(_secondBrain);
        for (int i = 0; i < 4; i++)
            SpawnPickup();
        _running = true;
        _started++;
    }

    private TankBrain NewBrain(int selection) => selection switch
    {
        0 => new StateMachineAI(),
        1 => new BehaviorTreeAI(),
        2 => new GoapAI(),
        3 => new UtilityAI(),
        _ => new NeuralSelfPlayAI { Model = _fixedEvaluation }
    };

    private CharacterBody2D SpawnTank(Vector2I cell, int team, Color color)
    {
        var tank = _tankScene.Instantiate<CharacterBody2D>();
        tank.Set("team", team);
        tank.Set("silent", true);
        tank.Set("weapon_effect_parent", _field);
        tank.Position = PositionOf(cell);
        tank.Rotation = team == 1 ? 0f : Mathf.Pi;
        tank.GetNode<Sprite2D>("body").Modulate = color;
        _field.AddChild(tank);
        return tank;
    }

    private void SpawnPickup()
    {
        for (int attempt = 0; attempt < 16; attempt++)
        {
            var cell = new Vector2I(_mapRandom.Next(_match.Size), _mapRandom.Next(_match.Size));
            if (!_maze.Call("valid_index", cell.X, cell.Y).AsBool())
                continue;
            var point = PositionOf(cell);
            if (point.DistanceSquaredTo(_first.GlobalPosition) < 15000f || point.DistanceSquaredTo(_second.GlobalPosition) < 15000f ||
                _pickups.Any(entry => IsInstanceValid(entry.Pickup) && entry.Pickup.GlobalPosition.IsEqualApprox(point)))
                continue;
            var pickup = _pickupScene.Instantiate<Area2D>();
            pickup.Position = point;
            pickup.Set("cell", cell);
            // Open each match with guaranteed repair and shield options.
            int item = _tick == 0 && _pickups.Count < 2 ? _pickups.Count : _mapRandom.Next(_catalog.Length);
            pickup.Set("definition", _catalog[item]);
            _field.AddChild(pickup);
            _pickups.Add((pickup, _tick + PickupLifetime));
            return;
        }
    }

    private Vector2 PositionOf(Vector2I cell) => _maze.Call("get_cell_position", cell.X, cell.Y).AsVector2();
    private static float Hull(CharacterBody2D tank) => IsInstanceValid(tank) ? (float)tank.Get("health").AsDouble() : 0f;

    private string Summary(TankBrain brain) =>
        $"{Names[brain switch { StateMachineAI => 0, BehaviorTreeAI => 1, GoapAI => 2, UtilityAI => 3, _ => 4 }]}:" +
        $"{brain.Decisions},{brain.FireDecisions},{brain.BankDecisions},{brain.DodgeDecisions},{brain.PickupDecisions}" +
        (brain is GoapAI goap ? $",plans={goap.MultiActionPlans}" : "");

    private void Record(float a, float b)
    {
        _matchesRun++;
        int result = (a > 0f).CompareTo(b > 0f);
        if (result > 0) _wins++;
        else if (result < 0) _losses++;
        else _draws++;

        if (!_training)
            return;
        var policy = (NeuralSelfPlayAI)_firstBrain;
        float reward = result * 0.96f + (a - b) * 0.09f;
        _learner.Learn(policy.Samples, reward);
        if (_learner.Episodes % 30 == 0)
        {
            _opponents.Add(_learner.Clone());
            if (_opponents.Count > 10)
                _opponents.RemoveAt(1);
        }
        if (_learner.Episodes % _saveEvery == 0)
            _learner.Save(_checkpoint);
        if (_learner.Episodes % _reportEvery == 0)
        {
            GD.Print($"TRAIN episodes={_learner.Episodes} run={_matchesRun} W/L/D={_wins}/{_losses}/{_draws} " +
                $"pool={_opponents.Count} at={DateTimeOffset.UtcNow:O}");
        }
    }

    private void Finish()
    {
        if (_training)
        {
            _learner.Save(_checkpoint);
            GD.Print($"TRAIN finished episodes={_learner.Episodes} added={_learner.Episodes - _initialEpisodes} " +
                $"W/L/D={_wins}/{_losses}/{_draws} at={DateTimeOffset.UtcNow:O}");
        }
        else
            GD.Print($"BENCH finished matches={_matchesRun} first_wins={_wins} first_losses={_losses} draws={_draws}");
        GetTree().Quit();
    }

    private void Fail(string message)
    {
        GD.PushError(message);
        GetTree().Quit(2);
    }

    private static string Flag(string[] args, string name, string fallback)
    {
        int index = Array.IndexOf(args, name);
        return index >= 0 && index + 1 < args.Length ? args[index + 1] : fallback;
    }

    private static int Number(string[] args, string name, int fallback, int minimum, int maximum) =>
        int.TryParse(Flag(args, name, ""), out int value) ? Math.Clamp(value, minimum, maximum) : fallback;
}
