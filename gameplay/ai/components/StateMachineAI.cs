using Godot;

namespace TankTrouble.AI;

[GlobalClass]
public partial class StateMachineAI : TankBrain
{
    private Maneuver _state;

    protected override Option Decide(Situation s)
    {
        if (s.Risk > 0.44f && s.Has(Maneuver.Dodge))
            _state = Maneuver.Dodge;
        else if (s.Self.Hull <= 0.45f && s.Has(Maneuver.Repair))
            _state = Maneuver.Repair;
        else if (s.Shot is { Quality: > 0.34f } && s.ReadyToFire)
            _state = Maneuver.Fire;
        else if (_state == Maneuver.Rearm && !s.Armed && s.Has(Maneuver.Rearm))
            _state = Maneuver.Rearm;
        else if (!s.Armed && s.Find(Maneuver.Rearm).Value > 0.57f)
            _state = Maneuver.Rearm;
        else if (s.Self.Hull < 0.35f && s.Range < s.CellSize * 0.9f && s.Has(Maneuver.Retreat))
            _state = Maneuver.Retreat;
        else
            _state = Maneuver.Chase;
        return s.Find(_state);
    }
}
