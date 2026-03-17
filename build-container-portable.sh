#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Configurable paths (override via env or .env file) ---
# CODER_HOME : directory mounted as $HOME inside the container
# CLAUDE_DIR : host path to .claude/ directory
# CLAUDE_JSON: host path to .claude.json file

# Load .env from the same directory as this script, if present
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
fi

CODER_HOME="${CODER_HOME:-/ssd/coder_home}"
CLAUDE_DIR="${CLAUDE_DIR:-${HOME}/.claude}"
CLAUDE_JSON="${CLAUDE_JSON:-${HOME}/.claude.json}"

# CUDA version selection (default: cu126)
CUDA_VER="${CUDA_VER:-cu126}"

case "${CUDA_VER}" in
    cu126)
        SIF_NAME="${SCRIPT_DIR}/code-server-ml.sif"
        DEF_FILE="${SCRIPT_DIR}/code-server-ml.def"
        ;;
    cu128)
        SIF_NAME="${SCRIPT_DIR}/code-server-ml-cu128.sif"
        DEF_FILE="${SCRIPT_DIR}/code-server-ml-cu128.def"
        ;;
    *)
        echo "Error: Unknown CUDA_VER='${CUDA_VER}'. Use cu126 or cu128."
        exit 1
        ;;
esac

# /tmp on the same volume as CODER_HOME to avoid filling up /
CODER_TMP="${CODER_TMP:-$(dirname "${CODER_HOME}")/coder_tmp}"
mkdir -p "${CODER_TMP}"

# Build bind-mount options for Claude credentials
BIND_OPTS=(--bind "${CODER_TMP}:/tmp")
if [[ -d "${CLAUDE_DIR}" ]]; then
    BIND_OPTS+=(--bind "${CLAUDE_DIR}:${HOME}/.claude")
else
    echo "Warning: ${CLAUDE_DIR} not found, skipping .claude/ bind mount"
fi
if [[ -f "${CLAUDE_JSON}" ]]; then
    BIND_OPTS+=(--bind "${CLAUDE_JSON}:${HOME}/.claude.json")
else
    echo "Warning: ${CLAUDE_JSON} not found, skipping .claude.json bind mount"
fi

# --contain: isolate /home, /tmp from the host
# --home:    mount CODER_HOME as container's $HOME
# --bind:    bring Claude credentials from host
SINGULARITY_OPTS=(
    --nv
    --contain
    --home "${CODER_HOME}"
    "${BIND_OPTS[@]}"
)

case "${1:-help}" in
    build)
        echo "==> Building ${SIF_NAME} from ${DEF_FILE} (${CUDA_VER}) ..."
        sudo singularity build "${SIF_NAME}" "${DEF_FILE}"
        echo "==> Done: ${SIF_NAME}"
        ;;
    run)
        echo "==> Starting code-server [${CUDA_VER}] (http://localhost:8080) ..."
        echo "    CODER_HOME=${CODER_HOME}"
        singularity run "${SINGULARITY_OPTS[@]}" "${SIF_NAME}"
        ;;
    shell)
        echo "==> Opening shell [${CUDA_VER}] ..."
        echo "    CODER_HOME=${CODER_HOME}"
        singularity shell "${SINGULARITY_OPTS[@]}" "${SIF_NAME}"
        ;;
    test)
        echo "==> Testing [${CUDA_VER}]: ${SIF_NAME}"
        echo "    CODER_HOME=${CODER_HOME}"
        echo "    CLAUDE_DIR=${CLAUDE_DIR}"
        echo "    CLAUDE_JSON=${CLAUDE_JSON}"
        echo ""
        echo "==> GPU check (nvidia-smi):"
        singularity exec "${SINGULARITY_OPTS[@]}" "${SIF_NAME}" nvidia-smi
        echo ""
        echo "==> CUDA version in container:"
        singularity exec "${SINGULARITY_OPTS[@]}" "${SIF_NAME}" nvcc --version | tail -1
        echo ""
        echo "==> ffmpeg version:"
        singularity exec "${SINGULARITY_OPTS[@]}" "${SIF_NAME}" ffmpeg -version | head -1
        echo ""
        echo "==> Python version:"
        singularity exec "${SINGULARITY_OPTS[@]}" "${SIF_NAME}" python3 --version
        echo ""
        echo "==> uv version:"
        singularity exec "${SINGULARITY_OPTS[@]}" "${SIF_NAME}" uv --version
        echo ""
        echo "==> HOME directory:"
        singularity exec "${SINGULARITY_OPTS[@]}" "${SIF_NAME}" sh -c 'echo HOME=$HOME && ls -la $HOME'
        echo ""
        echo "==> Claude auth check:"
        singularity exec "${SINGULARITY_OPTS[@]}" "${SIF_NAME}" sh -c 'test -f $HOME/.claude.json && echo "OK: .claude.json found" || echo "NG: .claude.json not found"'
        ;;
    *)
        echo "Usage: [ENV_VARS] $0 {build|run|shell|test}"
        echo ""
        echo "  build  - Build SIF container (sudo required)"
        echo "  run    - Start code-server on http://localhost:8080"
        echo "  shell  - Open interactive shell in container"
        echo "  test   - Verify GPU, tools, and mount points"
        echo ""
        echo "Environment variables (or set in ${SCRIPT_DIR}/.env):"
        echo "  CODER_HOME   - Container home dir   (default: /ssd/coder_home)"
        echo "  CLAUDE_DIR   - .claude/ directory    (default: \$HOME/.claude)"
        echo "  CLAUDE_JSON  - .claude.json file     (default: \$HOME/.claude.json)"
        echo "  CUDA_VER     - cu126 | cu128         (default: cu126)"
        echo ""
        echo "Examples:"
        echo "  $0 build                                    # CUDA 12.6 (default)"
        echo "  CUDA_VER=cu128 $0 build                     # CUDA 12.8"
        echo "  CODER_HOME=/data/mycode $0 run              # Custom home"
        echo "  CUDA_VER=cu128 CODER_HOME=/data/ws $0 run   # Both overrides"
        ;;
esac
