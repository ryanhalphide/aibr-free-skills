# Credits

## Adapted Work

### auto-research pattern

The `/auto-research` skill adapts the autonomous optimization loop pattern from Andrej Karpathy's [autoresearch](https://github.com/karpathy/autoresearch) project. The core idea — mutate, experiment, measure, keep or discard — is Karpathy's. The AIBR implementation extends it beyond ML hyperparameter search to general software optimization (prompt engineering, algorithm selection, config tuning) and integrates it with the Claude Code skill system and agent dispatch model.

## Plugins and Frameworks

### Superpowers Plugin Framework

Several skills in this repo follow conventions established by the [Superpowers Claude Code plugin](https://github.com/superpowers-ai/superpowers). The RIGID/FLEXIBLE skill classification, tool allowlists in frontmatter, and step-by-step process format are patterns we adopted from their excellent framework. Their work on formalizing the skill spec was foundational.

### Official Claude Code Plugins

Some agent definitions in `/agents/` build on patterns established by Anthropic's official Claude Code plugin ecosystem (feature-dev, code-review, and plugin-dev agents). The specialization approach — giving each agent a narrow scope and a specific tool allowlist — is informed by those examples. The model tier assignment logic is AIBR's own extension.

## All Other Content

Everything else in this repository — skills, hooks, patterns, configs, agent definitions, the memory pipeline, the trust gate system, the hive coordination protocol — is original work by AI Boost Realization (AIBR), built from 12 months of production use across real projects.

Free to use under the MIT License.
