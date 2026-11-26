using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Godot;

namespace TankTrouble.AI;

public sealed class PolicyNetwork
{
    public const int FeatureCount = 21;
    private const int Hidden = 24;
    private const int WeightCount = Hidden * (FeatureCount + 2) + 1;
    public const string DefaultPath = "user://neural_ai.json";
    public const string BundledPath = "res://gameplay/ai/learning/trained_policy.json";

    public sealed record Checkpoint(int Version, long Episodes, int Seed, float[] Weights);
    public sealed record Sample(float[][] Features, float[] Priors, int Choice, float[] Probabilities, float Signal);

    private readonly float[] _weights;
    public long Episodes { get; private set; }
    public int Seed { get; }
    public int Parameters => _weights.Length;

    public PolicyNetwork(int seed)
    {
        Seed = seed;
        _weights = new float[WeightCount];
        var rng = new Random(seed);
        for (int i = 0; i < _weights.Length; i++)
            _weights[i] = (float)(rng.NextDouble() * 2.0 - 1.0) * 0.13f;
    }

    private PolicyNetwork(Checkpoint checkpoint)
    {
        Seed = checkpoint.Seed;
        Episodes = checkpoint.Episodes;
        _weights = checkpoint.Weights;
    }

    public PolicyNetwork Clone() => new(new Checkpoint(1, Episodes, Seed, (float[])_weights.Clone()));

    public static PolicyNetwork? Load(string path)
    {
        try
        {
            string json;
            if (path.StartsWith("res://", StringComparison.Ordinal))
            {
                if (!Godot.FileAccess.FileExists(path))
                    return null;
                json = Godot.FileAccess.GetFileAsString(path);
            }
            else
            {
                string file = Resolve(path);
                if (!File.Exists(file))
                    return null;
                json = File.ReadAllText(file);
            }
            var data = JsonSerializer.Deserialize<Checkpoint>(json);
            return data is { Version: 1, Episodes: >= 0, Weights.Length: WeightCount } &&
                data.Weights.All(float.IsFinite) ? new PolicyNetwork(data) : null;
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException or JsonException)
        {
            GD.PushWarning($"Could not load policy '{path}': {exception.Message}");
            return null;
        }
    }

    public void Save(string path)
    {
        string file = Resolve(path);
        string temp = file + ".tmp";
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        File.WriteAllText(temp, JsonSerializer.Serialize(new Checkpoint(1, Episodes, Seed, _weights)));
        File.Move(temp, file, true);
    }

    public float Score(float[] features)
    {
        float sum = _weights[^1];
        for (int h = 0; h < Hidden; h++)
            sum += Activate(features, h) * _weights[Hidden * (FeatureCount + 1) + h];
        return sum;
    }

    public float[] Probabilities(float[][] options, float[] priors)
    {
        var scores = new float[options.Length];
        for (int i = 0; i < scores.Length; i++)
            scores[i] = Score(options[i]) + priors[i];
        float peak = scores.Max();
        float total = 0;
        for (int i = 0; i < scores.Length; i++)
        {
            scores[i] = MathF.Exp(Math.Clamp(scores[i] - peak, -35f, 0f));
            total += scores[i];
        }
        for (int i = 0; i < scores.Length; i++)
            scores[i] /= total;
        return scores;
    }

    public void Learn(IReadOnlyList<Sample> samples, float outcome)
    {
        Episodes++;
        if (samples.Count == 0)
            return;
        float[] update = new float[WeightCount];
        float credit = outcome;
        for (int i = samples.Count - 1; i >= 0; i--)
        {
            var sample = samples[i];
            credit = Math.Clamp(credit * 0.985f + sample.Signal, -2f, 2f);
            for (int action = 0; action < sample.Features.Length; action++)
            {
                float policyGradient = (action == sample.Choice ? 1f : 0f) - sample.Probabilities[action];
                Accumulate(sample.Features[action], credit * policyGradient, update);
            }
        }
        float rate = 0.065f / MathF.Sqrt(Math.Max(1, samples.Count));
        for (int i = 0; i < _weights.Length; i++)
            _weights[i] = Math.Clamp(_weights[i] * 0.99996f + Math.Clamp(update[i] * rate, -0.16f, 0.16f), -4f, 4f);
    }

    private float Activate(float[] features, int neuron)
    {
        int offset = neuron * (FeatureCount + 1);
        float sum = _weights[offset + FeatureCount];
        for (int f = 0; f < FeatureCount; f++)
            sum += _weights[offset + f] * features[f];
        return MathF.Tanh(sum);
    }

    private void Accumulate(float[] features, float gradient, float[] update)
    {
        int output = Hidden * (FeatureCount + 1);
        for (int h = 0; h < Hidden; h++)
        {
            float active = Activate(features, h);
            update[output + h] += gradient * active;
            float hidden = gradient * _weights[output + h] * (1f - active * active);
            int offset = h * (FeatureCount + 1);
            for (int f = 0; f < FeatureCount; f++)
                update[offset + f] += hidden * features[f];
            update[offset + FeatureCount] += hidden;
        }
        update[^1] += gradient;
    }

    private static string Resolve(string path) =>
        path.StartsWith("user://", StringComparison.Ordinal) || path.StartsWith("res://", StringComparison.Ordinal)
            ? ProjectSettings.GlobalizePath(path) : Path.GetFullPath(path);
}
