using System;
using System.Collections.Generic;
using Godot;

namespace TankTrouble.AI;

public enum Maneuver { Chase, Fire, Dodge, Retreat, Repair, Rearm, Shield, Flank, Hold }

public readonly record struct Option(Maneuver Action, Vector2 Destination, float Value);
public readonly record struct Shot(float Angle, float Quality, int Bounces);
public readonly record struct TankView(CharacterBody2D Body, int Team, float Health, float Maximum)
{
    public Vector2 Position => Body.GlobalPosition;
    public float Hull => Health / Math.Max(1f, Maximum);
}

public sealed record Situation(
    TankView Self, TankView Foe, float CellSize, float Range, float Risk, bool ClearLane,
    bool Armed, bool Shielded, bool OpponentShielded, bool ReadyToFire, Shot? Shot,
    IReadOnlyList<Option> Options)
{
    public Option Find(Maneuver action)
    {
        foreach (var option in Options)
            if (option.Action == action)
                return option;
        return FindHold();
    }

    public bool Has(Maneuver action) => Find(action).Action == action;

    private Option FindHold() => new(Maneuver.Hold, Self.Position, 0.05f);
}

public static class Tactics
{
    public static Option Best(Situation state, Func<Option, float> evaluate)
    {
        var result = state.Find(Maneuver.Hold);
        var score = float.NegativeInfinity;
        foreach (var candidate in state.Options)
        {
            var candidateScore = evaluate(candidate);
            if (candidateScore > score)
            {
                score = candidateScore;
                result = candidate;
            }
        }
        return result;
    }

    public static float[] Features(Situation s, Option option)
    {
        var x = new float[PolicyNetwork.FeatureCount];
        x[(int)option.Action] = 1.0f;
        x[9] = s.Self.Hull;
        x[10] = s.Foe.Hull;
        x[11] = Math.Min(1.0f, s.Range / (s.CellSize * 6f));
        x[12] = s.Risk;
        x[13] = s.ClearLane ? 1 : 0;
        x[14] = s.Armed ? 1 : 0;
        x[15] = s.Shielded ? 1 : 0;
        x[16] = s.ReadyToFire ? 1 : 0;
        x[17] = s.Shot?.Quality ?? 0;
        x[18] = option.Value;
        x[19] = Math.Min(1.0f, s.Self.Position.DistanceTo(option.Destination) / (s.CellSize * 6f));
        x[20] = s.OpponentShielded ? 1 : 0;
        return x;
    }
}
