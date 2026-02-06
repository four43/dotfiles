---
name: reviewing-code
description: Code review checklist and process for ensuring quality and security. Use when reviewing code changes, after writing code, or when the user asks for a code review.
---

# Code Review Process

## When Invoked

1. Run `git diff` to see recent changes
2. Focus on modified files
3. Begin review immediately

## Review Checklist

### Readability

- Code is simple and readable
- Functions and variables are well-named
- No duplicated code

### Reliability

- Proper error handling
- Input validation implemented
- Edge cases considered

### Security

- No exposed secrets or API keys
- No hardcoded credentials
- Proper input sanitization

### Quality

- Good test coverage
- Performance considerations addressed
- No unnecessary complexity

## Feedback Format

Organize findings by priority:

### Critical (must fix)

Issues that will cause bugs, security vulnerabilities, or data loss.

### Warnings (should fix)

Issues that may cause problems or make code harder to maintain.

### Suggestions (consider improving)

Opportunities for cleaner code or better patterns.

## Output

- Include specific examples of how to fix issues
- Reference exact file locations and line numbers
- Be concise and actionable
