"""Typer-based CLI for EmbodiedBench."""

from __future__ import annotations

from pathlib import Path

import typer

app = typer.Typer(
    name="embodiedbench",
    help="Offline edge-AI benchmarking toolkit – Phase 1.",
    add_completion=False,
)


@app.callback()
def _callback() -> None:
    """EmbodiedBench – offline edge-AI benchmarking toolkit."""


@app.command()
def run(
    scenario: Path = typer.Option(
        ...,
        "--scenario",
        "-s",
        help="Path to the scenario YAML file (e.g. scenarios/corridor_follow.yaml).",
        exists=True,
        file_okay=True,
        dir_okay=False,
        readable=True,
        resolve_path=True,
    ),
    output_dir: Path = typer.Option(
        None,
        "--output-dir",
        "-o",
        help="Directory for output artifacts.  Defaults to artifacts/.",
        writable=True,
        resolve_path=True,
    ),
) -> None:
    """Run a scenario and write per-step metrics to artifacts/."""
    from embodiedbench.policy.dummy_adapter import DummyPolicy
    from embodiedbench.scenario.parser import ScenarioConfig
    from embodiedbench.scenario.runner import Runner

    config = ScenarioConfig.from_yaml(scenario)
    typer.echo(
        f"[embodiedbench] Loaded scenario '{config.name}' "
        f"({config.steps} steps, dt={config.dt}s, seed={config.seed})"
    )

    policy = DummyPolicy()
    runner = Runner(config=config, policy=policy)
    log_path = runner.run(output_dir=output_dir)

    typer.echo(f"[embodiedbench] Run complete → {log_path}")


if __name__ == "__main__":
    app()
