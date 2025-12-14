# Tsubame Project

This document is the entry point for developers and automated systems working on this project.

## Document Structure

| Document | Audience | Content |
|----------|----------|---------|
| **PROJECT.md** (this) | Developers, Systems | Project overview, principles, design philosophy |
| README.md | Users | Installation, usage, features |
| ARCHITECTURE.md | Developers, Systems | Technical structure, data flow, design decisions |
| CHANGELOG.md | Everyone | Version history, changes |

## Project Vision

Tsubame is a macOS app that solves window position issues when connecting external displays.

**Problems Solved**:
- Windows lose their positions when external displays are disconnected/reconnected
- macOS does not automatically restore window layouts
- Manual repositioning is inefficient and frustrating

**Design Philosophy**:
- Simple, lightweight menu bar app
- Automation first (minimize user interaction)
- Privacy-focused (no data sent externally)

## Current Status

- **Version**: v1.2.13 (in development)
- **Phase**: #47 Architecture Refactoring complete

## Development Principles

### 1. Incremental Refactoring

Large changes are split into Phases:
- Each Phase can be tested and released independently
- Enables easy rollback if issues arise

### 2. Documentation-Driven

- Design decisions are recorded in Issues
- Clarify approach before implementation
- Include reasoning in commit messages

### 3. System-Assisted Development

(Policy to be documented in future)

## Roadmap

### Completed
- v1.2.11: Emergency fixes (#50, #54, #56 workarounds)
- v1.2.12: Display sleep handling (Phase 1)
- v1.2.13: Architecture refactoring (Phase 2-4)

### Planned
- v1.3.0: Stable release + UI improvements
- Future: Additional features based on user feedback

## For Automated Systems

When working on this project:

1. Read **ARCHITECTURE.md** to understand code structure
2. Check **GitHub Issues** for current tasks and plans
3. Propose large changes in Phase units
4. Include design reasoning in commit messages

## Repository

- GitHub: https://github.com/zembutsu/tsubame
- Issues: https://github.com/zembutsu/tsubame/issues
