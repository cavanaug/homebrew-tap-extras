# homebrew-mermaid-ascii

Homebrew tap formula for [mermaid-ascii](https://github.com/AlexanderGrooff/mermaid-ascii) — render Mermaid diagrams as ASCII in your terminal.

---

## Install

```bash
brew tap cavanaug/tap-extras
brew install mermaid-ascii
```

This formula is a thin wrapper around the upstream GitHub release assets and installs the prebuilt binary for your platform.

---

## Usage

Render a Mermaid file:

```bash
mermaid-ascii --file diagram.mmd
```

Render from stdin:

```bash
cat diagram.mmd | mermaid-ascii
```

Show help:

```bash
mermaid-ascii --help
```

---

## Notes

- The installed release archive also includes the upstream `README.md` and `LICENSE` as Homebrew docs.
- Supported binaries come directly from the upstream GitHub releases for macOS and Linux.

---

## Updating

```bash
brew update && brew upgrade mermaid-ascii
```

From the tap repo, maintainers can refresh the formula against the latest upstream GitHub release:

```bash
./scripts/update.mermaid-ascii.sh
```

---

## License

MIT — see the upstream project at <https://github.com/AlexanderGrooff/mermaid-ascii>.
