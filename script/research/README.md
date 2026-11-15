# Indicator turning-point study

Reproduces `docs/research/indicator-turning-points-2020-2026.md`. Prices go to
`$STUDY_DIR` (default `tmp/research`), not the app's database.

```bash
mkdir -p tmp/research
bin/rails runner script/research/fetch_history.rb   # ~15 min; re-run to resume
bin/rails runner script/research/turn_study.rb      # writes tmp/research/turn_study.json
bin/rails runner script/research/turn_baseline.rb   # baselines and breakdowns
```

Change the date range in `fetch_history.rb` and `SWING` / `WIN` / `LOSS` / `HORIZON` in the
study scripts to test other definitions.
