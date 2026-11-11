# ============================================================
# ENVIRONMENT
# ============================================================

export HISTSIZE=-1
export HISTFILESIZE=-1
export HISTCONTROL=ignoreboth:erasedups

export CLICOLOR=1

# User binaries and scripts
export PATH="/Users/Shared/.local/bin:$HOME/git/wpscripts:$HOME/bin:$PATH"

# Clean up duplicate entries in PATH automatically
export PATH=$(echo "$PATH" | awk -v RS=':' -v ORS=':' '{ sub(/\/+$/, "", $1); if ($1 != "" && !seen[$1]++) print $1 }' | sed 's/:$//')

# Locale
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# ============================================================
# INTERACTIVE SHELLS ONLY
# ============================================================

[[ $- != *i* ]] && return

# Append history instead of overwriting it
shopt -s histappend

# ============================================================
# MICROMAMBA
# ============================================================

export MAMBA_EXE="$HOME/bin/micromamba"
export MAMBA_ROOT_PREFIX="$HOME/opt/mamba"

if [[ -x "$MAMBA_EXE" ]]; then
    eval "$("$MAMBA_EXE" shell hook --shell bash)"
fi

# ============================================================
# BASH PRE-EXECUTION HOOKS
# ============================================================

[[ -f "$HOME/.bash-preexec.sh" ]] && source "$HOME/.bash-preexec.sh"

# ============================================================
# CUSTOM ALIASES AND FUNCTIONS
# ============================================================

[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"
[[ -f "$HOME/.bash_functions" ]] && source "$HOME/.bash_functions"
[[ -f "$HOME/.bash_bio" ]] && source "$HOME/.bash_bio"

# ============================================================
# CARGO
# ============================================================

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ============================================================
# ZOXIDE
# ============================================================

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd cd)"
fi

# ============================================================
# FZF
# ============================================================

if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi

# ============================================================
# STARSHIP
# ============================================================

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
