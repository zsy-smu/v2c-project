"""Scenario runner: executes steps and writes per-step JSON-Lines logs."""

from __future__ import annotations

import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from embodiedbench.policy.base import Policy
from embodiedbench.runtime.profiler import Profiler
from embodiedbench.scenario.parser import ScenarioConfig

_ARTIFACTS_DIR = Path(__file__).resolve().parents[2] / "artifacts"


class Runner:
    """Drives a :class:`~embodiedbench.policy.base.Policy` through a scenario.

    Per-step records are written to
    ``artifacts/run_<scenario_name>_<timestamp>.jsonl``.

    Each line contains:
    - ``step_id``   – 0-based integer
    - ``action``    – dict returned by the policy
    - ``latency_ms``– wall-clock time for ``policy.act()`` in milliseconds
    - ``timestamp`` – ISO-8601 UTC timestamp
    """

    def __init__(self, config: ScenarioConfig, policy: Policy) -> None:
        self.config = config
        self.policy = policy
        self._profiler = Profiler()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def run(self, output_dir: Path | None = None) -> Path:
        """Execute the scenario and return the path to the log file.

        Args:
            output_dir: Directory for output files.  Defaults to the
                        ``artifacts/`` directory at the repository root.

        Returns:
            Path to the written ``.jsonl`` log file.
        """
        out_dir = output_dir or _ARTIFACTS_DIR
        out_dir.mkdir(parents=True, exist_ok=True)

        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        log_path = out_dir / f"run_{self.config.name}_{ts}.jsonl"

        self.policy.reset(seed=self.config.seed)

        with log_path.open("w", encoding="utf-8") as fh:
            for step_id in range(self.config.steps):
                record = self._step(step_id)
                fh.write(json.dumps(record) + "\n")
                time.sleep(self.config.dt)

        return log_path

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _step(self, step_id: int) -> dict[str, Any]:
        observation = {"step_id": step_id}
        self.policy.observe(observation)

        with self._profiler.measure() as elapsed:
            action = self.policy.act()

        return {
            "step_id": step_id,
            "action": action,
            "latency_ms": round(elapsed.ms, 3),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
