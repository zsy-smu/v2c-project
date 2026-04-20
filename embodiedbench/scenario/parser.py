"""Pydantic schema for scenario YAML files."""

from __future__ import annotations

from pathlib import Path

import yaml
from pydantic import BaseModel, Field, model_validator


class ScenarioConfig(BaseModel):
    """Top-level scenario configuration loaded from a YAML file."""

    name: str = Field(..., description="Human-readable scenario name")
    steps: int = Field(..., ge=1, description="Number of simulation steps to run")
    dt: float = Field(..., gt=0.0, description="Time delta between steps in seconds")
    seed: int = Field(default=42, description="Global random seed")
    description: str = Field(default="", description="Optional free-text description")

    @model_validator(mode="after")
    def _check_reasonable_duration(self) -> "ScenarioConfig":
        duration = self.steps * self.dt
        if duration > 3600:
            raise ValueError(
                f"Scenario duration ({duration:.1f}s) exceeds 1 hour – "
                "are you sure this is intentional?"
            )
        return self

    # ------------------------------------------------------------------
    # Factory
    # ------------------------------------------------------------------

    @classmethod
    def from_yaml(cls, path: Path) -> "ScenarioConfig":
        """Load and validate a scenario from a YAML file.

        Args:
            path: Absolute or relative path to the ``.yaml`` file.

        Returns:
            A validated :class:`ScenarioConfig` instance.
        """
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
        return cls.model_validate(raw)
