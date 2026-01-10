---
description: 'Python Agent Mode'
tools: ['vscode', 'execute', 'read', 'agent', 'aws-knowledge-mcp-server/*', 'context7/*', 'pylance-mcp-server/*', 'edit', 'search', 'web', 'todo', 'ms-python.python/getPythonEnvironmentInfo', 'ms-python.python/getPythonExecutableCommand', 'ms-python.python/installPythonPackage', 'ms-python.python/configurePythonEnvironment', 'ms-toolsai.jupyter/configureNotebook', 'ms-toolsai.jupyter/listNotebookPackages', 'ms-toolsai.jupyter/installNotebookPackages', 'github.vscode-pull-request-github/copilotCodingAgent', 'github.vscode-pull-request-github/issue_fetch', 'github.vscode-pull-request-github/suggest-fix', 'github.vscode-pull-request-github/searchSyntax', 'github.vscode-pull-request-github/doSearch', 'github.vscode-pull-request-github/renderIssues', 'github.vscode-pull-request-github/activePullRequest', 'github.vscode-pull-request-github/openPullRequest']
---
Try to write code that is as simple and elegant as possible. Follow pythonic best practices.

Use built-in python features and standard libraries where possible.

Use pathlib Path objects instead of strings for paths when possible.

Follow PEP-8 style guidelines.

Use type hints for all function signatures.

Use the tool Context7 to look up library code. Use the pylance tool to ensure the python code is correct.

Write docstrings for all public functions and classes using the numpy style, without types.

My python environment is already configured properly. Output which packages I may
need to install, but don't create new requirements.txt files or try and create a
virtual environment.

When creating tests, use pytest framework. Use pytest.parameterize when you can
to succinctly express multiple test cases. Tests go in the project's tests/ directory
and typically mirror the structure of the source code. Try not to use if branches,
instead use asserts for what should happen.

When creating a summary of what you did, be concise and to the point. Don't create
extra README files, demo scripts, or documentation unless explicitly asked.

When using an external library, try to use a well-known and widely used library.
Try and resolve-library-id tool to get the library id and get-library-docs tool to get
the documentation for the external library.
