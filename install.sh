#!/usr/bin/env bash
# script        : install.sh
# description   : Sets up dotfiles in-place using the current repository path.
# usage         : ./install.sh --env [wur_mac|tamu_mac|tamu_hprc]
# contact       : c.s.sivasubramani@gmail.com
# version       : 0.0.1
# date          : 2026-11-11

set -euo pipefail

# Get the absolute path of where this repository currently lives
DOTFILES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 --env [wur_mac|tamu_mac|tamu_hprc]"
    echo "  -e, --env    Specify the target environment"
    echo "  -h, --help   Display this help message"
    exit 1
}

# Parse command line arguments
ENV=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown parameter '$1'"
            usage
            ;;
    esac
done

# Validate environment argument
if [[ -z "${ENV:-}" ]]; then
    echo "Error: No environment specified."
    usage
fi

if [[ ! "$ENV" =~ ^(wur_mac|tamu_mac|tamu_hprc)$ ]]; then
    echo "Error: Invalid environment '$ENV'."
    echo "Valid options are: wur_mac, tamu_mac, tamu_hprc"
    exit 1
fi

echo "==> Selected environment: $ENV"
echo "==> Repository path detected at: $DOTFILES_SRC"

# 1. Validate that the environment's bashrc actually exists in the repo
ENV_BASHRC="$DOTFILES_SRC/$ENV/bashrc"
if [[ ! -f "$ENV_BASHRC" ]]; then
    echo "Error: Could not find configuration file at $ENV_BASHRC"
    exit 1
fi

# 3. Handle existing ~/.bashrc with a timestamped backup and clean overwrite
DEST_BASHRC="$HOME/.bashrc"

if [ -f "$DEST_BASHRC" ] || [ -L "$DEST_BASHRC" ]; then
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    BACKUP_BASHRC="${DEST_BASHRC}.bak.${TIMESTAMP}"
    echo "==> Backing up existing $DEST_BASHRC to $BACKUP_BASHRC"
    cp -p "$DEST_BASHRC" "$BACKUP_BASHRC"
fi

# Write the fresh bootstrap block (overwriting ~/.bashrc completely)
echo "==> Writing clean bootstrap configuration to $DEST_BASHRC..."
cat << EOF > "$DEST_BASHRC"
# --- Dotfiles Environment Bootstrap ---
export DOTFILES="$DOTFILES_SRC"
export ENV="$ENV"

# Load the environment-specific bashrc directly from your repository
if [ -f "\$DOTFILES/\$ENV/bashrc" ]; then
    source "\$DOTFILES/\$ENV/bashrc"
fi
EOF


# 4. Handle ~/.bash_profile universally for login shells (SSH/Mac terminals)
DEST_PROFILE="$HOME/.bash_profile"

if [ -f "$DEST_PROFILE" ] && [ ! -L "$DEST_PROFILE" ]; then
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    echo "==> Backing up existing $DEST_PROFILE to ${DEST_PROFILE}.bak.${TIMESTAMP}"
    cp "$DEST_PROFILE" "${DEST_PROFILE}.bak.${TIMESTAMP}"
fi

# Write the universal login bridge
echo "==> Writing universal login shell bridge to $DEST_PROFILE..."
cat << 'EOF' > "$DEST_PROFILE"
# --- Universal Login Shell Bridge ---
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi
EOF


# 5. Handle Starship configuration if starship is installed
if command -v starship &> /dev/null; then
    echo "==> Starship prompt detected. Setting up configuration..."
    mkdir -p "$HOME/.config"

    DEST_STARSHIP="$HOME/.config/starship.toml"
    SRC_STARSHIP="$DOTFILES_SRC/common/starship.toml"

    if [ -f "$SRC_STARSHIP" ]; then
        if [ -f "$DEST_STARSHIP" ] || [ -L "$DEST_STARSHIP" ]; then
            TIMESTAMP=$(date +%Y%m%d%H%M%S)
            echo "==> Backing up existing $DEST_STARSHIP to ${DEST_STARSHIP}.bak.${TIMESTAMP}"
            cp -p "$DEST_STARSHIP" "${DEST_STARSHIP}.bak.${TIMESTAMP}"
        fi

        echo "==> Copying starship.toml to $DEST_STARSHIP..."
        cp -p "$SRC_STARSHIP" "$DEST_STARSHIP"
    else
        echo "Warning: Could not find starship.toml at $SRC_STARSHIP"
    fi
else
    echo "==> Starship not found. Skipping starship configuration."
fi


echo "==> Installation complete!"
echo "==> Your shell is now linked directly to your repository at: $DOTFILES_SRC"
echo "==> Run 'source ~/.bashrc' to apply changes."
