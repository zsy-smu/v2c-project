"""Smoke tests for the scenario runner."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from embodiedbench.policy.dummy_adapter import DummyPolicy
from embodiedbench.scenario.parser import ScenarioConfig
from embodiedbench.scenario.runner import Runner


@pytest.fixture()
def corridor_config() -> ScenarioConfig:
    scenarios_dir = Path(__file__).resolve().parents[1] / "scenarios"
    return ScenarioConfig.from_yaml(scenarios_dir / "corridor_follow.yaml")


def test_config_loads(corridor_config: ScenarioConfig) -> None:
    assert corridor_config.name == "corridor_follow"
    assert corridor_config.steps == 20
    assert corridor_config.dt == pytest.approx(0.05)
    assert corridor_config.seed == 42


def test_runner_produces_log(corridor_config: ScenarioConfig, tmp_path: Path) -> None:
    policy = DummyPolicy()
    runner = Runner(config=corridor_config, policy=policy)
    log_path = runner.run(output_dir=tmp_path)

    assert log_path.exists(), "Log file was not created"
    lines = log_path.read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == corridor_config.steps, "Wrong number of log lines"


def test_log_record_schema(corridor_config: ScenarioConfig, tmp_path: Path) -> None:
    policy = DummyPolicy()
    runner = Runner(config=corridor_config, policy=policy)
    log_path = runner.run(output_dir=tmp_path)

    for raw in log_path.read_text(encoding="utf-8").strip().splitlines():
        record = json.loads(raw)
        assert "step_id" in record
        assert "action" in record
        assert "latency_ms" in record
        assert "timestamp" in record
        assert isinstance(record["latency_ms"], float)
        assert isinstance(record["action"], dict)


def test_dummy_policy_deterministic(corridor_config: ScenarioConfig, tmp_path: Path) -> None:
    """Two runs with the same seed must produce identical actions."""

    def _collect_actions(out_dir: Path) -> list[dict]:
        policy = DummyPolicy()
        runner = Runner(config=corridor_config, policy=policy)
        log_path = runner.run(output_dir=out_dir)
        return [
            json.loads(line)["action"]
            for line in log_path.read_text(encoding="utf-8").strip().splitlines()
        ]

    run1 = _collect_actions(tmp_path / "run1")
    run2 = _collect_actions(tmp_path / "run2")
    assert run1 == run2, "DummyPolicy is not deterministic across runs with the same seed"
