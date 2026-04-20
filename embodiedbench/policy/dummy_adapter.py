"""Deterministic dummy policy used for smoke tests and baseline runs."""

from __future__ import annotations

import random
from typing import Any

from embodiedbench.policy.base import Policy


class DummyPolicy(Policy):
    """A fully deterministic policy that returns fixed random actions.

    The action space is a dict with keys ``linear`` (float) and
    ``angular`` (float), both sampled once per step from a seeded RNG.
    """

    def __init__(self) -> None:
        self._rng: random.Random = random.Random()
        self._last_observation: Any = None

    # ------------------------------------------------------------------
    # Policy interface
    # ------------------------------------------------------------------

    def observe(self, observation: Any) -> None:
        self._last_observation = observation

    def act(self) -> dict[str, float]:
        return {
            "linear": round(self._rng.uniform(-1.0, 1.0), 4),
            "angular": round(self._rng.uniform(-1.0, 1.0), 4),
        }

    def reset(self, seed: int | None = None) -> None:
        self._rng.seed(seed)
        self._last_observation = None
