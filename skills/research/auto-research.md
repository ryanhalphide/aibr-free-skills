---
name: auto-research
description: "Karpathy-style autonomous optimization loop — mutate, experiment, measure, keep/discard, repeat. Use when the user says '/auto-research', 'run autoresearch', 'karpathy loop', 'experiment loop', 'optimize this', 'parameter sweep', 'self-improving', 'run experiments overnight', 'find the best config', or wants to systematically improve any measurable metric (profit factor, latency, test coverage, build time, accuracy, loss, etc.) through automated experimentation."
---

> **Credit:** The autonomous optimization loop in this skill is adapted from Andrej Karpathy's [autoresearch](https://github.com/karpathy/autoresearch) project. The core mutate→experiment→measure→keep/discard cycle is Karpathy's. This AIBR implementation extends it beyond ML to general software optimization and integrates it with the Claude Code skill system.

# AutoResearch: The Karpathy Loop

Autonomous optimization through iterative experimentation. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch): modify → run → measure → keep/discard → repeat.

The core insight: give an AI agent a metric to optimize and a knob to turn, then let it run experiments autonomously. You wake up to a log of what worked and what didn't.

## When This Pattern Works

Any situation where you have:
1. **One metric** you can measure (lower latency, higher profit factor, fewer errors, better accuracy)
2. **One thing to change** (config values, code parameters, feature flags, architecture choices)
3. **A way to test** (run a script, execute tests, hit an endpoint, run a benchmark)

Examples: trading strategy params, ML hyperparameters, database query tuning, build optimization, compiler flags, CSS performance, API response times, prompt engineering.

## The Setup Phase

Before running experiments, establish four things with the user:

### 1. The Metric
Ask: "What single number tells you if things got better?"

| Domain | Example Metrics |
|--------|----------------|
| Trading | profit_factor, sharpe_ratio, win_rate |
| ML/AI | val_loss, accuracy, perplexity, bpb |
| Performance | p99_latency_ms, requests_per_second |
| Quality | test_pass_rate, coverage_percent |
| Build | build_time_seconds, bundle_size_kb |

The metric must be:
- A single number (not subjective)
- Extractable from command output (grep-able)
- Directional (know if higher or lower is better)

### 2. The Mutation Target
Ask: "What file or config controls the behavior we're optimizing?"

This could be:
- A config file (YAML, JSON, .env)
- Constructor parameters in code
- Command-line flags
- A specific function's constants

### 3. The Experiment Command
Ask: "What command runs one experiment and outputs the metric?"

Examples:
```bash
python -m pytest tests/ --tb=short        # metric: test pass count
python backtest.py --config params.yaml   # metric: profit_factor from stdout
npm run build 2>&1 | grep "bundle size"   # metric: bundle_size_kb
curl -w "%{time_total}" https://api/...   # metric: response_time_seconds
```

### 4. The Budget
Ask: "How long should each experiment take? How many total?"

Defaults: 5 minutes per experiment, 25 experiments total.

## The Experiment Loop

Once setup is confirmed, run this loop:

```
BASELINE = run experiment with current params
best_metric = BASELINE.metric
best_params = current params

FOR EACH mutation IN generate_mutations():
    1. Apply mutation to params (in memory, don't write to disk yet)
    2. Run experiment command
    3. Extract metric from output
    4. IF metric improved:
         Log as KEEP
         Update best_metric, best_params
         Notify user
       ELSE:
         Log as DISCARD
    5. Append to results.tsv

SAVE best_params to best_params.json
SEND summary to user
```

### Three-Phase Mutation Strategy (V3)

**Phase 1 — Singles**: Sweep each parameter individually to find which ones matter.

**Phase 2 — Structural**: Test architectural/boolean changes (enable/disable features, swap algorithms).

**Phase 3 — Combos**: Combine Phase 1+2 winners. This is where the real gains hide — individual params that each help a little can compound dramatically together.

### Generating Mutations

For each parameter in the mutation target:
- If numeric: try values at 0.5x, 0.75x, 1.5x, 2x of the current value
- If boolean: flip it
- If enum/choice: try each option
- For combos: pair every Phase 1 winner with every Phase 2 winner

### Logging Results

Create `results/autoresearch/results.tsv` in the project:

```
experiment	metric	status	description
1	0.6111	keep	baseline — no changes
2	0.6987	keep	confidence 25 (more signals)
3	0.5320	discard	confidence 35
4	2.1284	keep	exits ON (default stops)
```

Also save the winning params to `results/autoresearch/best_params.json`:

```json
{
  "params": {"use_exit_manager": true, "confidence_threshold": 40},
  "metric_value": 3.44,
  "metric_name": "profit_factor",
  "description": "exits ON + confidence 40",
  "timestamp": "2026-03-21T02:57:09Z",
  "baseline_value": 0.61,
  "improvement_pct": 464
}
```

## Implementation Pattern

The implementation depends on the project. Here's the skeleton:

```python
import time, json
from pathlib import Path

RESULTS_DIR = Path("results/autoresearch")
RESULTS_TSV = RESULTS_DIR / "results.tsv"

class AutoResearchLoop:
    def __init__(self, metric_name, metric_direction, run_command,
                 mutation_target, max_experiments=25):
        self.metric_name = metric_name
        self.higher_is_better = (metric_direction == "higher")
        self.run_command = run_command
        self.mutation_target = mutation_target
        self.max_experiments = max_experiments
        self.experiments = []
        self.baseline = None

    def is_better(self, new_val, old_val):
        return new_val > old_val if self.higher_is_better else new_val < old_val

    def run(self):
        RESULTS_DIR.mkdir(parents=True, exist_ok=True)
        # 1. Establish baseline
        self.baseline = self.run_experiment("baseline", params=None)
        best = self.baseline["metric"]
        # 2. Sweep mutations
        for mutation in self.generate_mutations():
            result = self.run_experiment(mutation["description"], mutation["params"])
            if result and self.is_better(result["metric"], best):
                self.log(result, "keep")
                best = result["metric"]
            else:
                self.log(result, "discard")
        # 3. Save best
        self.save_best_params()
```

## Key Principles

1. **One metric, one file, one command.** Complexity kills autonomous loops. The simpler the setup, the more experiments you can run.

2. **Keep or discard, no middle ground.** Like Karpathy's original: if it's better, keep it. If it's not, throw it away. Don't accumulate maybes.

3. **Cache expensive data.** If experiments need data loading (market data, datasets, build artifacts), cache it on the first run. Every subsequent experiment should be fast.

4. **Never stop.** Once the loop starts, run until the budget is exhausted. Don't pause to ask the user. They might be asleep. Log everything to TSV so they can review later.

5. **Phase 3 is where the gold is.** Individual parameter changes often don't move the needle much. But combining two winners can produce outsized gains.

6. **The metric is law.** Don't second-guess the metric. If the number improved, keep it — even if the change seems counterintuitive. The data speaks.

## Real-World Example: Trading Strategy

Setup:
- **Metric**: profit_factor (higher is better)
- **Mutation target**: BacktestSimulator constructor kwargs
- **Command**: `await simulator.run_async(bars, "BTC/USD", "1Hour")`
- **Budget**: ~5 seconds per experiment, 30 experiments

Results:
```
Phase 1: confidence=40 → PF 0.80 (+31% vs baseline 0.61)
Phase 2: use_exit_manager=True → PF 2.13 (+248%)  ← BREAKTHROUGH
Phase 3: confidence=40 + exits=True → PF 3.44 (+464%)
```

The loop discovered that the exit manager — disabled based on stock-specific testing — was essential for crypto. A human researcher missed this for weeks. The loop found it in 3 minutes.

## After the Loop

Once experiments complete:
1. Show the user the results table (kept vs discarded)
2. Highlight the best params found and the improvement percentage
3. Offer to apply the best params to the live system
4. Save everything to `results/autoresearch/` for future reference
5. Suggest running again with different mutation dimensions or on different data windows
