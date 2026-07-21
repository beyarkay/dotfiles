---
name: wandb-report
description: Create W&B reports for experiment reviews. Use when asked to create a report showing recent experiment results. Drafts an outline for approval, then creates the actual report.
---

# W&B Report Generator

Create Weights & Biases reports for weekly mentor reviews and experiment updates.

## Workflow

Follow these 3 phases in order. **Never skip the outline phase.**

### Phase 1: Gather Context

Before drafting anything, gather this information:

1. **Project/Entity**: Ask or detect from context/environment
   - Check for `WANDB_API_KEY` in environment or `.env`
   - Look for wandb config in the project

2. **Runs to Include**: Ask what experiments/runs to include
   - Examples: "last 4 runs", specific run names, runs matching a pattern
   - Query wandb API to get available run names and metrics

3. **Story to Tell**: Ask what the report should communicate
   - What's the main finding or comparison?
   - Example: "FooIntervention works better than BarIntervention"

### Phase 2: Draft Outline (CRITICAL)

**ALWAYS draft a markdown outline BEFORE writing any code.**

Present the outline for user critique. Include `[bracketed descriptions]` of where plots will go.

#### Outline Template

```markdown
# Report: [Title]

## Key Finding
- Main takeaway: [one sentence summary]
- [CalloutBlock: "quote the key result here"]

## Setup
- Brief bullet points describing what was compared
- [No plot - just text]

## Training Curves
- Show how loss evolved over training
- [Full-width LinePlot: train/loss for all runs, x=Step, y=Loss]

## Results Comparison
- Compare final metrics across runs
- [Half-width LinePlot: eval/metric_A] [Half-width LinePlot: eval/metric_B]

## Conclusion
- Brief interpretation
- Next steps (if any)
```

**Wait for user approval.** Iterate on the outline until the user is satisfied with:
- The story structure
- What plots are included
- Chart layouts (full-width vs side-by-side)

### Phase 3: Create Report

Only after outline approval:

1. Generate Python code using `wandb_workspaces` API
2. **Execute the code** to create the actual report
3. Return the report URL to the user

## Layout Rules

| Layout | Width | Use Case |
|--------|-------|----------|
| Full-width | `w=24` | Default for all charts |
| Half-width | `w=12` | Side-by-side comparisons only |
| Never use | `w<12` | Too small to read |

Standard height: `h=8`

## Labeling Guidelines

- **Chart titles**: Descriptive ("Loss Over Training" not "train_loss")
- **Axis labels**: Include units and direction ("Loss (lower is better)")
- **Legends**: Human-readable names (not code variable names)

## Content Guidelines

- Lead with the most important finding
- Max 3-5 colors per chart
- Short sentences, minimal jargon
- Easy to skim: headings, bullets, short paragraphs

## Code Patterns

### Basic Report Structure

```python
import wandb
import wandb_workspaces.reports.v2 as wr

# Initialize API
api = wandb.Api()

# Create report
report = wr.Report(
    project="PROJECT_NAME",
    entity="ENTITY_NAME",
    title="Report Title",
    description="Brief description"
)

# Add blocks
report.blocks = [
    # Sections and panels go here
]

# Save and get URL
report.save()
print(f"Report URL: {report.url}")
```

### Filter Runs by Name

```python
filters = "Metric('displayName') in ['run-1', 'run-2', 'run-3']"
```

### Full-Width Line Plot

```python
wr.PanelGrid(
    panels=[
        wr.LinePlot(
            title="Loss Over Training",
            x="Step",
            y=["train/loss"],
            layout=wr.Layout(x=0, y=0, w=24, h=8)
        )
    ],
    runsets=[
        wr.Runset(project="PROJECT", entity="ENTITY", filters=filters)
    ]
)
```

### Side-by-Side Plots

```python
wr.PanelGrid(
    panels=[
        wr.LinePlot(
            title="Eval Loss",
            x="Step",
            y=["eval/loss"],
            layout=wr.Layout(x=0, y=0, w=12, h=8)
        ),
        wr.LinePlot(
            title="Eval Accuracy",
            x="Step",
            y=["eval/accuracy"],
            layout=wr.Layout(x=12, y=0, w=12, h=8)
        )
    ],
    runsets=[
        wr.Runset(project="PROJECT", entity="ENTITY", filters=filters)
    ]
)
```

### Callout Block

```python
wr.CalloutBlock(text="Key finding: FooIntervention achieves target loss 23% faster")
```

### Text Section with Heading

```python
wr.H1(text="Section Title"),
wr.P(text="Paragraph of explanation here."),
wr.UnorderedList(items=["Point 1", "Point 2", "Point 3"])
```

## Example Outline

```markdown
# Report: FooIntervention vs BarIntervention

## Key Finding
- FooIntervention reduces loss 23% faster than BarIntervention
- [CalloutBlock: "FooIntervention achieves target loss in 3.2k steps vs 4.1k for Baseline"]

## Setup
- 4 runs total: 2x FooIntervention, 2x BarIntervention
- Same model, same data, different interventions
- [No plot]

## Training Curves
- Both interventions converge, but at different rates
- [Full-width LinePlot: train/loss for all 4 runs]

## Eval Metrics
- Final eval loss comparison
- [Half-width: eval/loss] [Half-width: eval/accuracy]

## Next Steps
- Try combining interventions
- Scale up to larger model
```

## Checklist Before Creating Report

- [ ] User approved the outline
- [ ] `WANDB_API_KEY` is available
- [ ] Run names/filters are correct
- [ ] Metric names match what's logged in wandb
- [ ] Chart titles are descriptive
- [ ] Layout widths are 12 or 24 only

## Output

After executing the code, provide the user with:
1. The report URL
2. Brief confirmation of what was created
