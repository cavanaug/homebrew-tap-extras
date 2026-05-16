# tap-extras

Personal Homebrew tap for open source projects that do not currently have their own official tap.

This repository exists for convenience, mainly for my own use and for anyone else who finds these formulae useful. It is not intended to replace an official tap from an upstream project author.

If a project author publishes an official tap and would prefer that a conflicting formula here be removed, open an issue and I will remove it.

The software packaged by these formulae comes from the upstream projects. This repository only maintains the Homebrew tap metadata and related update scripts.

## Install

You can install a formula directly from this tap without adding the tap first:

```bash
brew install cavanaug/tap-extras/mermaid-ascii
```

If you want local access to all formulae in this tap, add it first:

```bash
brew tap cavanaug/tap-extras
```

## Maintained Taps

### `copilot-api`

Very small Homebrew packaging wrapper for a tool that turns GitHub Copilot into an OpenAI/Anthropic-compatible API server.

Upstream project: <https://github.com/caozhiyuan/copilot-api>

```bash
brew install cavanaug/tap-extras/copilot-api
```

See `README.copilot-api.md`.

### `mermaid-ascii`

Homebrew formula for a CLI that renders Mermaid diagrams as ASCII in the terminal.

Upstream project: <https://github.com/AlexanderGrooff/mermaid-ascii>

```bash
brew install cavanaug/tap-extras/mermaid-ascii
```

See `README.mermaid-ascii.md`.

## Notes

- These formulae are maintained independently for packaging convenience.
- Upstream projects remain the source of truth for the software itself.
- Suggestions and improvements are welcome.

## Issues

If you notice a broken formula, version lag, or a conflict with an official upstream distribution method, please open an issue.
