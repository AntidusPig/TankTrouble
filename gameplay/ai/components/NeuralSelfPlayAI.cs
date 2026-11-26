using System;
using System.Collections.Generic;
using Godot;

namespace TankTrouble.AI;

[GlobalClass]
public partial class NeuralSelfPlayAI : TankBrain
{
    [Export(PropertyHint.File, "*.json")]
    public string Checkpoint { get; set; } = PolicyNetwork.DefaultPath;

    internal PolicyNetwork? Model { get; set; }
    internal bool Training { get; set; }
    internal Random? RandomSource { get; set; }
    internal List<PolicyNetwork.Sample> Samples { get; } = new();
    private float? _selfHull;
    private float? _enemyHull;
    private Maneuver _previous;

    public override void _Ready()
    {
        Model ??= PolicyNetwork.Load(Checkpoint) ?? PolicyNetwork.Load(PolicyNetwork.BundledPath) ?? new PolicyNetwork(7343);
        base._Ready();
    }

    protected override Option Decide(Situation s)
    {
        if (Model is null)
            return s.Find(Maneuver.Chase);
        float priorStrength = Math.Max(0.65f, 2.8f / (1f + Model.Episodes / 180f));
        int count = s.Options.Count;
        var features = new float[count][];
        var priors = new float[count];
        for (int i = 0; i < count; i++)
        {
            var option = s.Options[i];
            features[i] = Tactics.Features(s, option);
            priors[i] = priorStrength * (option.Value + (option.Action == _previous ? 0.14f : 0f));
            if (option.Action == Maneuver.Dodge)
                priors[i] += s.Risk * 0.65f;
        }
        var probabilities = Model.Probabilities(features, priors);

        int choice = 0;
        if (Training && RandomSource is not null)
        {
            double roll = RandomSource.NextDouble();
            for (; choice < count - 1 && roll > probabilities[choice]; choice++)
                roll -= probabilities[choice];
            float delta = (s.Self.Hull - (_selfHull ?? s.Self.Hull)) -
                (s.Foe.Hull - (_enemyHull ?? s.Foe.Hull));
            float signal = delta * 1.8f;
            if (Samples.Count > 0)
                Samples[^1] = Samples[^1] with { Signal = signal };
            Samples.Add(new(features, priors, choice, probabilities, 0f));
        }
        else
        {
            for (int i = 1; i < count; i++)
                if (probabilities[i] > probabilities[choice])
                    choice = i;
        }
        _selfHull = s.Self.Hull;
        _enemyHull = s.Foe.Hull;
        _previous = s.Options[choice].Action;
        return s.Options[choice];
    }
}
