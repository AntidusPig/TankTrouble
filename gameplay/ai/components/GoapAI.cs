using System;
using System.Collections.Generic;
using Godot;

namespace TankTrouble.AI;

[GlobalClass]
public partial class GoapAI : TankBrain
{
    [Flags]
    private enum Facts
    {
        None = 0, Safe = 1, Healthy = 2, Armed = 4, Protected = 8,
        FiringPosition = 16, Attacked = 32
    }

    private readonly record struct Action(Maneuver Name, Facts Requires, Facts Adds, Facts Removes, float Cost);
    private sealed record Step(Facts State, Action[] Plan, float Cost);

    public string CurrentPlan { get; private set; } = "";
    public int MultiActionPlans { get; private set; }
    private Maneuver _previous = Maneuver.Hold;

    protected override Option Decide(Situation s)
    {
        Facts facts = Facts.None;
        if (s.Risk < 0.38f && (!s.ClearLane || s.Range > s.CellSize * 0.74f || s.Shielded))
            facts |= Facts.Safe;
        if (s.Self.Hull >= 0.68f)
            facts |= Facts.Healthy;
        if (s.Armed)
            facts |= Facts.Armed;
        if (s.Shielded)
            facts |= Facts.Protected;
        if (s.Shot is { Quality: > 0.29f })
            facts |= Facts.FiringPosition;

        var actions = new List<Action>(8);
        void Add(Maneuver name, Facts requires, Facts adds, Facts removes, float cost)
        {
            var option = s.Find(name);
            if (option.Action == name)
                actions.Add(new(name, requires, adds, removes,
                    Math.Max(0.12f, cost / (0.5f + option.Value) - (name == _previous ? 0.15f : 0f))));
        }

        Add(Maneuver.Dodge, Facts.None, Facts.Safe, Facts.FiringPosition, 0.82f);
        Add(Maneuver.Retreat, Facts.None, Facts.Safe, Facts.FiringPosition, 0.98f);
        Add(Maneuver.Repair, Facts.Safe, Facts.Healthy, Facts.None, 0.78f);
        Add(Maneuver.Shield, Facts.Safe, Facts.Protected | Facts.Safe, Facts.None, 0.79f);
        Add(Maneuver.Rearm, Facts.Safe, Facts.Armed, Facts.FiringPosition, 0.92f);
        Add(Maneuver.Flank, Facts.None, Facts.FiringPosition, Facts.None, 1.7f);
        Add(Maneuver.Chase, Facts.None, Facts.FiringPosition, Facts.Safe, 1.5f);
        if (s.Has(Maneuver.Fire))
            Add(Maneuver.Fire, Facts.FiringPosition, Facts.Attacked, Facts.None, s.ReadyToFire ? 0.42f : 1.24f);
        else
            // A future firing step is legal after a move has produced a lane; this virtual
            // step can only be considered after an executable first action.
            actions.Add(new(Maneuver.Fire, Facts.FiringPosition, Facts.Attacked, Facts.None, 1.05f));

        var goals = new List<Facts>(5);
        if (s.Risk > (s.Shielded ? 0.84f : 0.42f))
            goals.Add(Facts.Safe);
        if (!facts.HasFlag(Facts.Healthy) && s.Find(Maneuver.Repair).Value > 0.38f)
            goals.Add(Facts.Healthy);
        if (!s.Shielded && s.Find(Maneuver.Shield).Value > 0.55f && (!s.ClearLane || s.Self.Hull < 0.7f))
            goals.Add(Facts.Protected);
        if (!s.Armed && s.Find(Maneuver.Rearm).Value > 0.51f && !s.ClearLane)
            goals.Add(Facts.Armed | Facts.Attacked);
        goals.Add(Facts.Attacked);

        foreach (var goal in goals)
        {
            var plan = Search(s, facts, goal, actions);
            if (plan.Length == 0)
                continue;
            CurrentPlan = string.Join(" → ", Array.ConvertAll(plan, action => action.Name.ToString()));
            if (plan.Length > 1)
                MultiActionPlans++;
            _previous = plan[0].Name;
            return s.Find(_previous);
        }

        CurrentPlan = "Chase";
        _previous = Maneuver.Chase;
        return s.Find(_previous);
    }

    private static Action[] Search(Situation s, Facts start, Facts goal, List<Action> actions)
    {
        var queue = new PriorityQueue<Step, (float, int)>();
        var visited = new Dictionary<Facts, float> { [start] = 0 };
        int sequence = 0;
        queue.Enqueue(new(start, Array.Empty<Action>(), 0), (0, sequence++));
        while (queue.TryDequeue(out var next, out _))
        {
            if (next.Plan.Length > 0 && (next.State & goal) == goal)
                return next.Plan;
            if (next.Plan.Length >= 5)
                continue;
            foreach (var action in actions)
            {
                if ((next.State & action.Requires) != action.Requires ||
                    (next.Plan.Length == 0 && !s.Has(action.Name)))
                    continue;
                Facts result = (next.State & ~action.Removes) | action.Adds;
                float cost = next.Cost + action.Cost;
                if (result == next.State || (visited.TryGetValue(result, out var oldCost) && oldCost <= cost))
                    continue;
                visited[result] = cost;
                var plan = new Action[next.Plan.Length + 1];
                Array.Copy(next.Plan, plan, next.Plan.Length);
                plan[^1] = action;
                queue.Enqueue(new(result, plan, cost), (cost, sequence++));
            }
        }
        return Array.Empty<Action>();
    }
}
