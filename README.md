# debian-opt

Safe, review-first optimization workflow for Debian + AwesomeWM.

## Safety model

1. `tools/inspect_system.sh` performs a read-only inspection without `sudo`.
2. The AI reads `PROMPT.md`, `whitelist.txt`, and `output/baseline_report.txt`.
3. The AI writes a plan plus `output/apply_optimize.sh` and
   `output/restore.sh`, then stops.
4. You review both scripts. Root-level changes happen only when you manually run
   the approved apply script.

The repository ships with inert placeholder apply/restore scripts. They exit
without changing the system until an AI replaces them after inspecting the
target Debian machine.

## Use on the Debian machine

```bash
cd ~/debian-opt
chmod +x tools/inspect_system.sh
./tools/inspect_system.sh
agy
```

Then tell the agent:

> Read PROMPT.md and follow it strictly. Use the existing
> output/baseline_report.txt, produce output/optimization_plan.md,
> output/apply_optimize.sh, and output/restore.sh, then stop for review.

Review generated files before using them:

```bash
less output/optimization_plan.md
less output/apply_optimize.sh
less output/restore.sh
bash -n output/apply_optimize.sh output/restore.sh
```

If a service must be kept, say for example:

> Keep Bluetooth and CUPS. Remove every Bluetooth- and CUPS-related action from
> both generated scripts and regenerate the plan.

Only after review:

```bash
chmod +x output/apply_optimize.sh output/restore.sh
sudo ./output/apply_optimize.sh
```

Rollback, after reviewing that the restore script matches the generated apply
script:

```bash
sudo ./output/restore.sh
```

## Important limitation

Rollback must restore captured pre-change state, not blindly enable every
service. A service that was disabled before optimization must remain disabled
after rollback.
