using System;
using Godot;

namespace TankTrouble.AI;

[GlobalClass]
public partial class UtilityAI : TankBrain
{
    private Maneuver _last;

    protected override Option Decide(Situation s)
    {
        var choice = Tactics.Best(s, option =>
        {
            float immediate = Evaluate(s, option);
            var projected = Project(s, option);
            float second = 0f;
            foreach (var follow in s.Options)
            {
                if ((option.Action == follow.Action && follow.Action is Maneuver.Repair or Maneuver.Rearm or Maneuver.Shield) ||
                    (follow.Action == Maneuver.Dodge && projected.Risk < 0.15f))
                    continue;
                second = Math.Max(second, Evaluate(projected, follow));
            }
            return immediate + second * 0.32f + (option.Action == _last ? 0.045f : 0f);
        });
        _last = choice.Action;
        return choice;
    }

    private static float Evaluate(Situation s, Option option)
    {
        float adjustment = option.Action switch
        {
            Maneuver.Chase => (s.ClearLane ? 0.03f : 0.13f) - (1f - s.Self.Hull) * s.Risk * 0.36f,
            Maneuver.Fire => (s.Armed ? 0.14f : 0.10f) - s.Risk * 0.65f - (s.ReadyToFire ? 0f : 0.22f),
            Maneuver.Dodge => (s.Risk - 0.35f) * (s.Shielded ? 0.48f : 0.87f),
            Maneuver.Repair => (1f - s.Self.Hull) * 0.36f - s.Risk * 0.30f,
            Maneuver.Rearm => s.Armed ? -0.16f : (s.ClearLane ? 0.03f : 0.18f),
            Maneuver.Shield => s.Self.Hull < 0.66f ? 0.24f : 0.12f,
            Maneuver.Retreat => (1f - s.Self.Hull) * s.Risk * 0.53f,
            Maneuver.Flank => s.ReadyToFire ? 0.04f : 0.18f,
            _ => 0f
        };
        return option.Value + adjustment;
    }

    private static Situation Project(Situation s, Option option)
    {
        return option.Action switch
        {
            Maneuver.Dodge => s with { Risk = s.Risk * 0.24f, ReadyToFire = true },
            Maneuver.Retreat => s with { Risk = s.Risk * 0.36f, ClearLane = false },
            Maneuver.Fire => s with { ReadyToFire = false, Foe = s.Foe with { Health = Math.Max(0, s.Foe.Health - (s.Shot?.Quality ?? 0)) } },
            Maneuver.Repair => s with { Self = s.Self with { Health = Math.Min(s.Self.Maximum, s.Self.Health + 2f) } },
            Maneuver.Rearm => s with { Armed = true, ReadyToFire = true },
            Maneuver.Shield => s with { Shielded = true },
            Maneuver.Flank => s with { Risk = s.Risk * 0.8f, ReadyToFire = true },
            _ => s
        };
    }
}
