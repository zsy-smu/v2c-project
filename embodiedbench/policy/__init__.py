"""Policy package."""

from embodiedbench.policy.base import Policy
from embodiedbench.policy.dummy_adapter import DummyPolicy

__all__ = ["Policy", "DummyPolicy"]
