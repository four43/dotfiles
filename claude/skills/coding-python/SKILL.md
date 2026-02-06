---
name: coding-python
description: Python coding preferences and style guidelines for writing clean, idiomatic code. Use when writing Python code, creating tests, or reviewing Python files.
---

# Python Coding Guidelines

## Style Principles

- Write simple, elegant, pythonic code
- Use built-in features and standard library where possible
- Follow PEP-8 style guidelines
- Use type hints for all function signatures

## Path Handling

Use `pathlib.Path` objects instead of strings:

```python
from pathlib import Path

config_path = Path("config") / "settings.json"
```

## Docstrings

Use numpy-style docstrings for public functions and classes, without types in the docstring (types go in signatures):

```python
def process_data(items: list[dict], threshold: float) -> list[dict]:
    """
    Filter and transform data items based on threshold.

    Parameters
    ----------
    items
        List of data dictionaries to process.
    threshold
        Minimum value for filtering.

    Returns
    -------
    list[dict]
        Filtered and transformed items.
    """
```

## Testing

- Use pytest framework
- Use `pytest.parametrize` for multiple test cases
- Tests go in `tests/` directory, mirroring source structure
- Use asserts directly, avoid if branches in tests

```python
import pytest

@pytest.parametrize("input_val,expected", [
    (1, 2),
    (2, 4),
    (0, 0),
])
def test_double(input_val, expected):
    assert double(input_val) == expected
```

## Environment

- Python environment is already configured
- Output which packages need installation, but don't create requirements.txt or virtual environments

## External Libraries

- Prefer well-known, widely-used libraries
- Look up documentation before using unfamiliar APIs

## Output

- Be concise in summaries
- Don't create extra README files, demo scripts, or documentation unless explicitly asked
