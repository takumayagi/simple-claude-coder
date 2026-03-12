# Singularity Code-Server ML Container

GPU-enabled development container running [code-server](https://github.com/coder/code-server) with ML tools, Claude Code CLI, and OpenAI Codex CLI.

## What's inside

- **Base**: Ubuntu 24.04 + NVIDIA CUDA (12.6 or 12.8)
- **Editor**: code-server (VS Code in browser)
- **AI tools**: Claude Code CLI, OpenAI Codex CLI
- **ML/Dev**: Python 3, uv, Node.js 22.x, ffmpeg, OpenCV, cmake, build-essential
- **Utilities**: ripgrep, fd, tmux, htop, jq, tree, etc.

## Quick start

```bash
# Build the container (requires sudo)
./build-container-portable.sh build

# Start code-server at http://localhost:8080
./build-container-portable.sh run
```

## Configuration

All settings are controlled via environment variables. Set them inline, export them, or put them in a `.env` file next to the script.

| Variable | Default | Description |
|---|---|---|
| `CODER_HOME` | `/ssd/coder_home` | Host directory mounted as `$HOME` in the container |
| `CLAUDE_DIR` | `$HOME/.claude` | Host path to `.claude/` directory (auth credentials) |
| `CLAUDE_JSON` | `$HOME/.claude.json` | Host path to `.claude.json` file |
| `CUDA_VER` | `cu126` | CUDA version: `cu126` or `cu128` |

### Using a .env file

Create a `.env` file in the same directory as the script:

```bash
CODER_HOME=/data/my_workspace
CLAUDE_DIR=/home/alice/.claude
CLAUDE_JSON=/home/alice/.claude.json
```

Then just run:

```bash
./build-container-portable.sh run
```

## Commands

| Command | Description |
|---|---|
| `build` | Build the SIF container image (requires sudo) |
| `run` | Start code-server on `http://localhost:8080` |
| `shell` | Open an interactive shell inside the container |
| `test` | Verify GPU, tools, and mount points |

## Examples

```bash
# Build with CUDA 12.8
CUDA_VER=cu128 ./build-container-portable.sh build

# Run with custom home directory
CODER_HOME=/data/workspace ./build-container-portable.sh run

# Run CUDA 12.8 container with all custom paths
CUDA_VER=cu128 CODER_HOME=/data/ws CLAUDE_DIR=/home/bob/.claude ./build-container-portable.sh run

# Test that everything works
./build-container-portable.sh test
```

## Files

| File | Purpose |
|---|---|
| `build-container-portable.sh` | Main script (configurable, no hard-coded paths) |
| `code-server-ml.def` | Singularity definition for CUDA 12.6 |
| `code-server-ml-cu128.def` | Singularity definition for CUDA 12.8 |
| `.env` | (Optional) Your local configuration overrides |

## Prerequisites

- [Singularity/Apptainer](https://apptainer.org/) installed on the host
- NVIDIA GPU with drivers installed
- sudo access (for building the container only)
