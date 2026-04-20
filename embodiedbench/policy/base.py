"""Abstract base class for all policy adapters."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class Policy(ABC):
    """Abstract policy interface that every adapter must implement."""

    @abstractmethod
    def observe(self, observation: Any) -> None:
        """Receive an observation from the environment.

        Args:
            observation: Sensor / state data for the current step.
        """

    @abstractmethod
    def act(self) -> Any:
        """Compute and return an action based on the last observation."""

    @abstractmethod
    def reset(self, seed: int | None = None) -> None:
        """Reset the policy to its initial state.

        Args:
            seed: Optional random seed for reproducibility.
        """
