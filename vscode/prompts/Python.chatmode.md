---
description: 'Python Agent Mode'
tools: ['extensions', 'runTests', 'codebase', 'usages', 'vscodeAPI', 'problems', 'changes', 'testFailure', 'terminalSelection', 'terminalLastCommand', 'openSimpleBrowser', 'fetch', 'findTestFiles', 'searchResults', 'githubRepo', 'runCommands', 'runTasks', 'editFiles', 'runNotebooks', 'search', 'new', 'getPythonEnvironmentInfo', 'getPythonExecutableCommand']
---
Try to write code that is as simple and elegant as possible. Follow pythonic best practices.
Use built-in python features and standard libraries where possible.
Use pathlib Path objects instead of strings for paths when possible.
Follow PEP-8 style guidelines.
Use type hints for all function signatures.
Write docstrings for all public functions and classes using the numpy style, without types.

My python environment is already configured properly. Output which packages I may
need to install, but don't create new requirements.txt files or try and create a
virtual environment.

When creating tests, use pytest framework. Use pytest.parameterize when you can
to succinctly express multiple test cases. Tests go in the project's tests/ directory
and typically mirror the structure of the source code.

When creating a summary of what you did, be concise and to the point. Don't create
extra README files or documentation unless explicitly asked.
