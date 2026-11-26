# Enemy AI approaches

Evaluate these approaches on the same maze seeds, observations, and legal actions. A bot must use the same movement, weapons, health, and pickup rules as a player. Keep future spawn locations and private opponent inputs outside its observations.

| Approach | What it offers TankTrouble |
| --- | --- |
| Vector math + state machine | A baseline for aiming, dodging, and simple transitions. Adding retreat, positioning, and pickups increases the number of transitions to tune. |
| Behavior tree | Composes reusable actions and makes priorities explicit. Ranking two viable routes or weighing a shot against exposure still needs a scoring rule. [Colledanchise and Ögren](https://arxiv.org/abs/1709.00084) |
| F.E.A.R.-style GOAP | Assembles action sequences from preconditions and effects. Useful when a goal can be reached through several different sequences. [Jeff Orkin’s GDC talk](https://www.gdcvault.com/play/1013394/Three-States-and-a-Plan) |
| Utility scoring + short lookahead | Compares a shot, dodge, reposition, retreat, or pickup using the same projectile and movement model. The current recommendation to benchmark first. [Halo Infinite bot design](https://media.gdcvault.com/GDC%2B2022/Speaker%2BSlides/ThinkingLikePlayersHowHaloInfinitesBotsMakeDecision_ChinDeyerle_Brie.pdf) |
| Neural self-play | Can learn tactical patterns from matches. Compare a small policy that ranks legal actions and an end-to-end policy under the same observation and action limits. [ML-Agents self-play](https://github.com/Unity-Technologies/ml-agents/blob/develop/com.unity.ml-agents/Documentation~/Training-Configuration-File.md) |

Rank bots that pass the fairness checks by win rate on held-out maze seeds. Track bank-shot accuracy, avoidable hits, self-hits, retreat survival, and decision time to explain the results.

## Trying the controllers

Run the project in Godot 4.7.2 .NET with the .NET 8 SDK. To play against a controller, select **New Game → 1 Player · Play against AI**. Target practice keeps the tanks stationary for weapon tests.

To wire a scene in the editor, add exactly one of the component scenes from `gameplay/ai/components` under a `TankBase` entity. Assign a positive team number to group allies. Team zero is free-for-all. The components use the same drive, rotation, cooldown, damage, shield, and pickup code as the player. They observe visible arena entities and make decisions on a timer. The projectile predictor estimates tank movement, checks wall reflections, and gives different options to laser and explosive weapons.

GOAP searches action preconditions and effects. The planner can assemble sequences such as retreat → repair, get a shield → reposition, or rearm → find a firing line → shoot. Replanning uses each new observation. A planned pickup takes effect only if the tank reaches and collects it.

## Benchmark and training

Run these arguments with the **.NET** Godot executable from the project root after building the C# assembly. The lab uses the normal tank, pickup, maze, and shell scenes.

- Deterministic 12×12 tournament `--headless --path . --fixed-fps 60 res://gameplay/ai/lab/ai_lab.tscn -- --seeds 3 --match-seconds 48`
- Bounded self-play smoke run `--headless --path . --fixed-fps 60 res://gameplay/ai/lab/ai_lab.tscn -- --train --episodes 20`
- Train until an absolute time `--headless --path . --fixed-fps 60 res://gameplay/ai/lab/ai_lab.tscn -- --train --until 2026-11-26T08:00:00+08:00`
- Evaluate the saved network against the four deterministic controllers on held-out 12×12 mazes `--headless --path . --fixed-fps 60 res://gameplay/ai/lab/ai_lab.tscn -- --evaluate --seed 99201 --seeds 3`

The lab swaps starting sides for each seed. The five numbers after each controller name are decisions, fire decisions, bank-shot decisions, dodge decisions, and pickup decisions. These count selected actions, including an aim held across multiple decisions. A timeout with both tanks alive counts as a draw. Remaining hull is reported separately.

Self-play updates a small neural network that ranks the shared legal maneuvers. It plays against frozen copies of previous policies in the same game and saves to `user://neural_ai.json` by default. Pass `--checkpoint` with an alternate path to keep a smoke run or experiment independent. Loading a game checkpoint restores the selected controller, while training weights are stored separately.


## Deterministic results

The first tournament used three 12×12 seeds and swapped starting sides for every pairing. All 12 match rows for the repeated seed matched exactly.

| Controller | Wins | Losses | Draws |
| --- | ---: | ---: | ---: |
| State machine | 9 | 8 | 1 |
| Behavior tree | 10 | 8 | 0 |
| GOAP | 10 | 7 | 1 |
| Utility + lookahead | 6 | 12 | 0 |

GOAP selected 1,194 multi-action plans across 18 matches. The count includes replans while pursuing the same goal. This sample is too small to establish a general ranking. All four controllers used the shared weapon and movement rules.


## Overnight self-play results

Training completed at 08:00 Shanghai time on November 26, 2026. The final 553-parameter policy was saved after 75,603 episodes. Evaluation used three held-out 12×12 seeds with both starting sides and the same 48-second limit for both checkpoints.

| Opponent | 12-episode policy W–L–D | Overnight policy W–L–D |
| --- | ---: | ---: |
| State machine | 1–5–0 | 5–0–1 |
| Behavior tree | 2–4–0 | 4–1–1 |
| GOAP | 1–5–0 | 3–1–2 |
| Utility + lookahead | 1–2–3 | 3–2–1 |
| Total | 5–16–3 | 15–4–5 |

The trained policy sometimes repeatedly pursued pickups without firing, leading to side-dependent draws. These results cover three held-out layouts and do not establish a ranking across all maps.
