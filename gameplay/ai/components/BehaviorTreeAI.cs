using System;
using Godot;

namespace TankTrouble.AI;

[GlobalClass]
public partial class BehaviorTreeAI : TankBrain
{
    private interface INode { Option? Run(Situation situation); }

    private sealed record ActionNode(Maneuver Action) : INode
    {
        public Option? Run(Situation s) => s.Has(Action) ? s.Find(Action) : null;
    }

    private sealed record Condition(Func<Situation, bool> Test, INode Child) : INode
    {
        public Option? Run(Situation s) => Test(s) ? Child.Run(s) : null;
    }

    private sealed class Selector(params INode[] children) : INode
    {
        public Option? Run(Situation s)
        {
            foreach (var child in children)
                if (child.Run(s) is { } output)
                    return output;
            return null;
        }
    }

    private static readonly INode Tree = new Selector(
        new Condition(s => s.Risk > 0.36f, new ActionNode(Maneuver.Dodge)),
        new Condition(s => s.Self.Hull < 0.66f, new Selector(
            new Condition(s => s.Find(Maneuver.Repair).Value > 0.47f, new ActionNode(Maneuver.Repair)),
            new Condition(s => s.Range < s.CellSize && !s.Shielded, new ActionNode(Maneuver.Shield)),
            new Condition(s => s.Risk > 0.25f, new ActionNode(Maneuver.Retreat)))),
        new Condition(s => s.ReadyToFire && s.Shot is { Quality: > 0.27f }, new ActionNode(Maneuver.Fire)),
        new Condition(s => !s.Armed && s.Find(Maneuver.Rearm).Value > 0.48f, new ActionNode(Maneuver.Rearm)),
        new Condition(s => s.ClearLane && !s.ReadyToFire, new ActionNode(Maneuver.Flank)),
        new ActionNode(Maneuver.Chase));

    protected override Option Decide(Situation s) => Tree.Run(s) ?? s.Find(Maneuver.Hold);
}
