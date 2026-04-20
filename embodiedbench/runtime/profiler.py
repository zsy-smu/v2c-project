"""Lightweight context-manager profiler for measuring wall-clock latency."""

from __future__ import annotations

import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from typing import Generator


@dataclass
class _Elapsed:
    """Holds the elapsed time recorded by :class:`Profiler`."""

    ms: float = field(default=0.0)


class Profiler:
    """Measures wall-clock execution time of arbitrary code blocks.

    Usage::

        profiler = Profiler()
        with profiler.measure() as elapsed:
            result = expensive_call()
        print(f"Took {elapsed.ms:.2f} ms")
    """

    @contextmanager
    def measure(self) -> Generator[_Elapsed, None, None]:
        """Context manager that records elapsed time into an :class:`_Elapsed`.

        Yields:
            An :class:`_Elapsed` object whose ``ms`` attribute is populated
            after the block exits.
        """
        elapsed = _Elapsed()
        t0 = time.perf_counter()
        try:
            yield elapsed
        finally:
            elapsed.ms = (time.perf_counter() - t0) * 1_000
