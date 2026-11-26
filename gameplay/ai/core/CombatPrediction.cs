using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Godot.Collections;

namespace TankTrouble.AI;

public static class CombatPrediction
{
    public readonly record struct Leg(Vector2 Start, Vector2 End, float At, float EndAt, float Radius, bool Blast);

    public static Shot? BestShot(PhysicsDirectSpaceState2D space, TankView self, TankView foe,
        Vector2 foeVelocity, IReadOnlyList<TankView> tanks, GodotObject stats, float cellSize, int bounceLimit = 2)
    {
        float scale = Math.Abs(self.Body.GlobalScale.X);
        float speed = Math.Max(1f, Read(stats, "shell_speed") * scale);
        float laser = Read(stats, "laser_range");
        if (laser > 0f)
            return LaserShot(self, foe, foeVelocity, tanks, laser, Read(stats, "laser_charge_time"));
        float blast = Read(stats, "blast_radius") * scale;
        float lifetime = Math.Min(Read(stats, "shell_lifetime"), 2.7f);
        float currentAngle = self.Body.GlobalRotation;
        float muzzle = self.Position.DistanceTo(
            self.Body.GetNode<Node2D>("body/head_mount/head/muzzle").GlobalPosition);
        var exclusions = new Array<Rid>(tanks.Select(tank => tank.Body.GetRid()));
        Vector2 toFoe = foe.Position - self.Position;
        float baseAngle = toFoe.Angle();
        float turnDelay = Math.Abs(Mathf.AngleDifference(currentAngle, baseAngle)) /
            Math.Max(1f, (float)self.Body.Get("rotate_speed").AsDouble());
        float lead = turnDelay + Math.Max(0f, toFoe.Length() - muzzle) / speed;
        Vector2 visibleVelocity = foeVelocity * 0.72f;
        float aim = (toFoe + visibleVelocity * Math.Min(1.0f, lead)).Angle();
        Shot? best = null;
        float bestScore = 0.15f;

        void Check(float angle)
        {
            Vector2 direction = Vector2.FromAngle(angle);
            Vector2 origin = self.Position + direction * muzzle;
            var barrel = Wall(space, self.Position, origin, exclusions);
            if (barrel.Count != 0)
                return;
            float windup = Math.Abs(Mathf.AngleDifference(currentAngle, angle)) /
                Math.Max(1f, (float)self.Body.Get("rotate_speed").AsDouble());
            float span = Math.Min(speed * lifetime, cellSize * 7f);
            Vector2 point = origin;
            float elapsed = 0f;
            int maxBounces = blast > 0f ? 0 : bounceLimit;
            for (int bounces = 0; bounces <= maxBounces && span > 2f; bounces++)
            {
                var hit = Wall(space, point, point + direction * span, exclusions);
                var end = hit.Count > 0 ? hit["position"].AsVector2() : point + direction * span;
                float legDistance = point.DistanceTo(end);
                float legTime = legDistance / speed;
                Vector2 predicted = foe.Position + visibleVelocity * Math.Min(1.05f, windup + elapsed + legTime * 0.5f);
                // Stop the aim estimate at the first wall so it does not lead the target through a corner.
                var motionHit = Wall(space, foe.Position, predicted, exclusions);
                if (motionHit.Count != 0)
                    predicted = motionHit["position"].AsVector2();
                float clearance = DistanceOnSegment(predicted, point, end);
                float hullRadius = 39f * Math.Abs(foe.Body.GlobalScale.X);
                bool splash = blast > 0f && hit.Count > 0 &&
                    predicted.DistanceTo(end) < blast * 0.87f &&
                    Wall(space, end + hit["normal"].AsVector2() * 3f, predicted, exclusions).Count == 0;
                bool friendlyBlocked = tanks.Any(tank => tank.Body != foe.Body &&
                    (tank.Body == self.Body ? bounces > 0 : self.Team > 0 && tank.Team == self.Team) &&
                    DistanceOnSegment(tank.Position, point, end) < hullRadius);
                bool selfBlast = splash && end.DistanceTo(self.Position) < blast;
                if (!friendlyBlocked && !selfBlast && (clearance <= hullRadius || splash))
                {
                    float confidence = splash ? 0.64f : 1f - clearance / (hullRadius * 2.2f);
                    float quality = confidence / (1f + windup * 0.64f + (elapsed + legTime) * 0.22f + bounces * 0.19f);
                    if (quality > bestScore)
                    {
                        bestScore = quality;
                        best = new Shot(angle, quality, bounces);
                    }
                }
                if (hit.Count == 0)
                    break;
                Vector2 normal = hit["normal"].AsVector2();
                if (normal == Vector2.Zero)
                    break;
                span -= legDistance;
                elapsed += legTime;
                point = end + normal * 2f;
                direction = direction.Bounce(normal);
            }
        }

        Check(aim);
        Check(baseAngle);
        Check(aim - 0.085f);
        Check(aim + 0.085f);
        if (bestScore < 0.52f && blast == 0f)
            for (int i = 0; i < 16; i++)
                Check(baseAngle + (i + 0.5f) * Mathf.Tau / 16f);
        return best;
    }

    private static Shot? LaserShot(TankView self, TankView foe, Vector2 velocity,
        IReadOnlyList<TankView> tanks, float range, float charge)
    {
        Vector2 toFoe = foe.Position - self.Position;
        if (toFoe.Length() > range)
            return null;

        float turn = Math.Abs(Mathf.AngleDifference(self.Body.GlobalRotation, toFoe.Angle()));
        float delay = charge + turn / Math.Max(1f, Read(self.Body, "rotate_speed"));
        var aim = toFoe + velocity * Math.Min(1.3f, delay) * 0.55f;
        var direction = aim.Normalized();
        var end = self.Position + direction * range;
        bool blockedByAlly = self.Team > 0 && tanks.Any(tank => tank.Body != self.Body && tank.Team == self.Team &&
            DistanceOnSegment(tank.Position, self.Position, end) < 42f * Math.Abs(tank.Body.GlobalScale.X));
        return blockedByAlly ? null : new Shot(direction.Angle(), 1f / (1f + turn * 0.28f), 0);
    }

    public static IReadOnlyList<Leg> VisibleShells(PhysicsDirectSpaceState2D space, Array<Node> nodes,
        IReadOnlyList<TankView> tanks, Vector2 observer, float cellSize)
    {
        var legs = new List<Leg>();
        foreach (var tank in tanks)
        {
            if (tank.Position.IsEqualApprox(observer) ||
                tank.Body.Get("laser_beam").AsGodotObject() is not Node2D beam ||
                !GodotObject.IsInstanceValid(beam) || beam.IsQueuedForDeletion())
                continue;
            float at = Read(beam, "charge_left");
            legs.Add(new(beam.GlobalPosition, beam.ToGlobal(beam.Get("endpoint").AsVector2()), at, at, 52f, false));
        }
        if (nodes.Count == 0)
            return legs;
        var exclusions = new Array<Rid>(tanks.Select(tank => tank.Body.GetRid()));
        foreach (var node in nodes)
        {
            if (node is not Node2D shell || shell.IsQueuedForDeletion() || !shell.HasMethod("enable_spawner_collision")
                || shell.Get("pending_destroy").AsBool() || shell.GlobalPosition.DistanceSquaredTo(observer) > 16f * cellSize * cellSize)
                continue;
            var stats = shell.Get("stats").AsGodotObject();
            if (stats is null)
                continue;
            float scale = Math.Abs(shell.GlobalScale.X);
            float speed = Read(stats, "shell_speed") * scale;
            float blast = Read(stats, "blast_radius") * scale;
            Vector2 direction = shell.Get("shell_direction").AsVector2();
            Vector2 start = shell.GlobalPosition;
            float clock = 0f;
            for (int bounce = 0; bounce < 3 && clock < 0.75f && speed > 0; bounce++)
            {
                Vector2 end = start + direction * speed * (0.75f - clock);
                var hit = Wall(space, start, end, exclusions);
                if (hit.Count != 0)
                    end = hit["position"].AsVector2();
                float at = clock + start.DistanceTo(end) / speed;
                legs.Add(new(start, end, clock, at, 38f, false));
                if (hit.Count == 0)
                    break;
                if (blast > 0f)
                {
                    legs.Add(new(end, end, at, at, blast, true));
                    break;
                }
                Vector2 normal = hit["normal"].AsVector2();
                if (normal == Vector2.Zero)
                    break;
                start = end + normal * 2f;
                direction = direction.Bounce(normal);
                clock = at;
            }
        }
        return legs;
    }

    public static float Threat(IReadOnlyList<Leg> legs, Vector2 position, Vector2 velocity, float horizon)
    {
        float risk = 0f;
        foreach (var leg in legs)
        {
            if (leg.At > horizon)
                continue;
            float last = Math.Min(horizon, leg.EndAt);
            float fraction = leg.EndAt > leg.At ? (last - leg.At) / (leg.EndAt - leg.At) : 1;
            var from = leg.Start - (position + velocity * leg.At);
            var to = leg.Start.Lerp(leg.End, fraction) - (position + velocity * last);
            float distance = DistanceOnSegment(Vector2.Zero, from, to);
            float severity = 1f - distance / leg.Radius;
            risk = Math.Max(risk, Mathf.Clamp(severity + 0.12f, 0f, 1f) * (1f - leg.At * 0.55f));
        }
        return risk;
    }

    private static float DistanceOnSegment(Vector2 point, Vector2 start, Vector2 end)
    {
        Vector2 segment = end - start;
        float length = segment.LengthSquared();
        float part = length == 0f ? 0f : Mathf.Clamp((point - start).Dot(segment) / length, 0f, 1f);
        return point.DistanceTo(start + part * segment);
    }

    private static Godot.Collections.Dictionary Wall(PhysicsDirectSpaceState2D space, Vector2 from, Vector2 to, Array<Rid> exclude)
    {
        if (from.IsEqualApprox(to))
            return new Godot.Collections.Dictionary();
        var query = PhysicsRayQueryParameters2D.Create(from, to);
        query.Exclude = exclude;
        query.HitFromInside = true;
        return space.IntersectRay(query);
    }

    private static float Read(GodotObject stats, string key) => (float)stats.Get(key).AsDouble();
}
