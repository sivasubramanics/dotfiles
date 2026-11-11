# ===================
# Universal Functions
# ===================

# function to count files in a directory tree and display the counts in a tree-like format
countfiles() {
    local max_level=999
    local dirs=()
    local color=1

    # Check if stdout is a terminal; disable color if not
    [ -t 1 ] || color=0

    # ANSI helpers (no-ops when color is off)
    _cf_bold()  { [ $color -eq 1 ] && printf '\033[1m%s\033[0m' "$1" || printf '%s' "$1"; }
    _cf_blue()  { [ $color -eq 1 ] && printf '\033[1;34m%s\033[0m' "$1" || printf '%s' "$1"; }
    _cf_dim()   { [ $color -eq 1 ] && printf '\033[2m%s\033[0m' "$1" || printf '%s' "$1"; }

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
Usage: countfiles [-l LEVEL | --level LEVEL] [--no-color] [DIRECTORY ...]
Count regular files in DIRECTORY formatted as a tree (like the `tree` command).

Options:
  -l, --level NUM    Depth level to expand
      --no-color     Disable color output
  -h, --help         Show this help

Examples:
  countfiles -l 2
  countfiles -l 3 src tests
EOF
                return 0
                ;;
            -l|--level)
                if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
                    max_level="$2"; shift 2
                else
                    printf "countfiles: '%s' requires a positive integer\n" "$1" >&2; return 1
                fi
                ;;
            -l*)  max_level="${1#-l}"; shift ;;
            --no-color) color=0; shift ;;
            --) shift; dirs+=("$@"); break ;;
            -*) printf "countfiles: unknown option '%s'\n" "$1" >&2; return 1 ;;
            *)  dirs+=("$1"); shift ;;
        esac
    done

    [ "${#dirs[@]}" -eq 0 ] && dirs=( */ )

    _countfiles_tree() {
        local dir="$1"
        local current_level="$2"
        local max_lvl="$3"
        local prefix="$4"
        local is_last="$5"

        local total_files
        total_files=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        local dirname
        dirname=$(basename "$dir")

        # Format count as right-aligned tag inside brackets: e.g. [   1234]
        local count_tag
        count_tag=$(printf '[%7s]' "$total_files")

        if [ "$current_level" -eq 1 ]; then
            # Root directory: [count] tag FIRST, then directory name
            printf '%s %s\n' \
                "$(_cf_dim "$count_tag")" \
                "$(_cf_blue "${dirname}/")"
        else
            local branch
            if [ "$is_last" -eq 1 ]; then
                branch="└── "
            else
                branch="├── "
            fi

            # Print tree branch FIRST, then the [count] tag, then directory name
            printf '%s%s%s %s\n' \
                "$(_cf_dim "${prefix}")" \
                "$(_cf_dim "${branch}")" \
                "$(_cf_dim "$count_tag")" \
                "$(_cf_blue "${dirname}/")"
        fi

        if [ "$current_level" -lt "$max_lvl" ]; then
            local subdirs=()
            while IFS= read -r -d '' sdir; do
                subdirs+=("$sdir")
            done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

            local count=${#subdirs[@]}
            for i in "${!subdirs[@]}"; do
                local sdir="${subdirs[$i]}"
                local last=0
                [ "$i" -eq "$((count - 1))" ] && last=1

                # Build the new prefix for subdirectories
                local new_prefix
                if [ "$current_level" -eq 1 ]; then
                    new_prefix=""
                elif [ "$is_last" -eq 1 ]; then
                    new_prefix="${prefix}    "
                else
                    new_prefix="${prefix}│   "
                fi

                _countfiles_tree "$sdir" "$((current_level + 1))" "$max_lvl" "$new_prefix" "$last"
            done
        fi
    }

    for dir in "${dirs[@]}"; do
        dir="${dir%/}"
        [ -d "$dir" ] || { printf "countfiles: '%s' is not a directory\n" "$dir" >&2; continue; }
        _countfiles_tree "$dir" 1 "$max_level" "" 0
        # Separator between multiple root dirs
        # [ "${#dirs[@]}" -gt 1 ] && printf '\n'
    done
}


# Function to switch to a tmux session, creating it if it doesn't exist
goto() {
    local session_name="$1"

    # If no argument is provided, show active sessions
    if [[ -z "$session_name" ]]; then
        printf "Usage: goto <session_name>\n\n" >&2

        # Check if any sessions exist by attempting to list them
        if tmux list-sessions &>/dev/null; then
            printf "Active tmux sessions:\n" >&2
            # Use #{session_name} for tmux formatting
            tmux list-sessions -F "  #{session_name}" >&2
        else
            printf "No active tmux sessions found.\n" >&2
        fi
        return 1
    fi

    # Create session detached if it doesn't already exist
    tmux has-session -t "$session_name" 2>/dev/null || tmux new-session -d -s "$session_name"

    # Attach if outside tmux, switch client if inside tmux
    if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    fi
}

_goto_completions() {
    # Generate completion suggestions from active tmux session names
    local sessions
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

    # COMPREPLY is Bash's internal array for matching completions
    COMPREPLY=( $(compgen -W "$sessions" -- "${COMP_WORDS[COMP_CWORD]}") )
}

# Bind the completion function to your 'goto' command
complete -F _goto_completions goto


# Create a timestamped copy of a file or directory
backup() {
    if [ -z "$1" ]; then
        printf "Usage: backup <file_or_directory>\n" >&2
        return 1
    fi
    local target="${1%/}"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    cp -r "$target" "${target}.bak.${timestamp}" && \
    printf "Backup created: %s_backup_%s\n" "$target" "$timestamp"
}

# Extract archives using ouch if available, falling back to legacy tools
extract() {
    if [ -z "$1" ]; then
        printf "Usage: extract <archive_file>\n" >&2
        return 1
    fi

    if [ ! -f "$1" ]; then
        printf "'%s' is not a valid file\n" "$1" >&2
        return 1
    fi

    # Try using ouch first if installed
    if command -v ouch &>/dev/null; then
        ouch decompress "$1"
        return $?
    fi

    # Fallback legacy extraction
    case "$1" in
        *.tar.bz2|*.tbz2) tar -xvkf "$1" ;;
        *.tar.gz|*.tgz)   tar -xvkf "$1" ;;
        *.tar.xz)         tar -xvkf "$1" ;;
        *.tar)            tar -xvkf "$1" ;;
        *.gz)             gzip -dc "$1" > "${1%.gz}" ;;
        *.bz2)            bzip2 -dc "$1" > "${1%.bz2}" ;;
        *.xz)             xz -dc "$1" > "${1%.xz}" ;;
        *.zip)            unzip -n "$1" ;;
        *.rar)            unrar x -o- "$1" ;;
        *.7z)             7z x -aos "$1" ;;
        *.Z)              uncompress -c "$1" > "${1%.Z}" ;;
        *)                printf "'%s' cannot be extracted via extract()\n" "$1" >&2; return 1 ;;
    esac
}

# Compress files/directories using ouch if available, falling back to legacy tools
compress() {
    if [ -z "$1" ]; then
        printf "Usage: compress <target_file_or_dir> [output_file]\n" >&2
        return 1
    fi

    if [ ! -e "$1" ]; then
        printf "'%s' does not exist\n" "$1" >&2
        return 1
    fi

    local target="$1"
    local output="${2:-}"

    # Try using ouch first if installed
    if command -v ouch &>/dev/null; then
        if [ -n "$output" ]; then
            ouch compress "$target" "$output"
        else
            ouch compress "$target"
        fi
        return $?
    fi

    # Fallback legacy compression for directories
    if [ -d "$target" ]; then
        [ -z "$output" ] && output="${target%/}.tar.gz"

        case "$output" in
            *.tar.gz|*.tgz)   tar -czvf "$output" "$target" ;;
            *.tar.bz2|*.tbz2) tar -cjvf "$output" "$target" ;;
            *.tar.xz)         tar -cJvf "$output" "$target" ;;
            *.tar)            tar -cvf "$output" "$target" ;;
            *.zip)            zip -r "$output" "$target" ;;
            *.7z)             7z a "$output" "$target" ;;
            *.rar)            rar a "$output" "$target" ;;
            *)
                printf "Unsupported output format: '%s'\n" "$output" >&2
                return 1
                ;;
        esac
        return $?
    fi

    # Fallback legacy compression for single files
    if [ -f "$target" ]; then
        if [ -n "$output" ]; then
            case "$output" in
                *.tar.gz|*.tgz)    tar -czvf "$output" "$target" ;;
                *.tar.bz2|*.tbz2) tar -cjvf "$output" "$target" ;;
                *.tar.xz)         tar -cJvf "$output" "$target" ;;
                *.tar)            tar -cvf "$output" "$target" ;;
                *.gz)             gzip -c -- "$target" > "$output" ;;
                *.bz2)            bzip2 -c -- "$target" > "$output" ;;
                *.xz)             xz -c -- "$target" > "$output" ;;
                *.zip)            zip "$output" "$target" ;;
                *.7z)             7z a "$output" "$target" ;;
                *)
                    printf "Unsupported output format: '%s'\n" "$output" >&2
                    return 1
                    ;;
            esac
        else
            printf "No format specified. Defaulting to .gz\n"
            gzip -k -- "$target"
        fi
        return $?
    fi

    printf "'%s' is not a regular file or directory\n" "$target" >&2
    return 1
}


# Pretty-print environment variables
envtable() {
    local plain=0
    local max_width=0
    local color=1
    local regex=""
    local exact=0
    local extended=0

    # Disable color if stdout is not a TTY
    [ -t 1 ] || color=0

    # Parse CLI Arguments
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
Usage: envtable [OPTIONS] [PATTERN]

Pretty-print exported environment variables.

Options:
  -e, --extended   Search PATTERN as regex across variable names and values (case-insensitive)
  -p, --plain      Output as NAME = VALUE
  -w, --width N    Truncate values longer than N characters
      --no-color   Disable colored output
  -h, --help       Show this help

Matching:
  envtable PATH         Exact match: print only the PATH variable
  envtable -e path      Regex match: all variables whose name or value contains 'path'
  envtable -e '^CUDA'   Regex match: all variables whose name or value starts with 'CUDA'

Examples:
  envtable
  envtable PATH
  envtable -e PATH
  envtable -e '^CUDA'
  envtable --plain
  envtable --width 80
EOF
                return 0
                ;;
            -e|--extended)
                extended=1
                shift
                ;;
            -p|--plain)
                plain=1
                shift
                ;;
            -w|--width)
                if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
                    max_width="$2"
                    shift 2
                else
                    printf "envtable: '%s' requires a positive integer\n" "$1" >&2
                    return 1
                fi
                ;;
            -w*)
                max_width="${1#-w}"
                shift
                ;;
            --width=*)
                max_width="${1#*=}"
                shift
                ;;
            --no-color)
                color=0
                shift
                ;;
            --)
                shift
                [ -n "$1" ] && regex="$1"
                break
                ;;
            -*)
                printf "envtable: unknown option '%s'\n" "$1" >&2
                return 1
                ;;
            *)
                if [ -z "$regex" ]; then
                    regex="$1"
                fi
                shift
                ;;
        esac
    done

    # Determine match mode:
    #   no pattern            → show all
    #   bare pattern (no -e)  → exact variable name match
    #   -e pattern            → regex search across name and value
    if [ -z "$regex" ]; then
        exact=0; extended=0   # show all
    elif [ "$extended" -eq 0 ]; then
        exact=1               # bare arg → exact name match
    fi
    # extended=1 is already set by -e; regex search across name+value

    # ANSI Color Formatting
    local c_reset="" c_header="" c_var="" c_border=""
    if [ "$color" -eq 1 ]; then
        c_reset=$'\033[0m'
        c_header=$'\033[1;36m'  # Bold Cyan
        c_var=$'\033[1;33m'     # Bold Yellow
        c_border=$'\033[2m'     # Dim
    fi

    # Store matching environment variables and calculate column width
    local vars=()
    local vals=()
    local max_var_len=8  # Minimum width for "VARIABLE" header

    while IFS='=' read -r var val; do
        [ -z "$var" ] && continue

        # --- Match logic ---
        local match=0
        if [ "$exact" -eq 1 ]; then
            # Exact variable name match (case-sensitive)
            [ "$var" = "$regex" ] && match=1
        elif [ "$extended" -eq 1 ]; then
            # Regex search across name and value (case-insensitive)
            if echo "$var" | grep -E -q -i "$regex" || echo "$val" | grep -E -q -i "$regex"; then
                match=1
            fi
        else
            # No pattern: show all
            match=1
        fi

        if [ "$match" -eq 1 ]; then
            vars+=("$var")
            vals+=("$val")
            [ "${#var}" -gt "$max_var_len" ] && max_var_len="${#var}"
        fi
    done < <(env | sort)

    # Handle exact match miss
    if [ "$exact" -eq 1 ] && [ "${#vars[@]}" -eq 0 ]; then
        printf "envtable: variable '%s' not found\n" "$regex" >&2
        return 1
    fi

    # --------------------------------------------------------------------------
    # Output Mode 1: Plain Formatting (-p / --plain)
    # --------------------------------------------------------------------------
    if [ "$plain" -eq 1 ]; then
        for i in "${!vars[@]}"; do
            local var="${vars[$i]}"
            local val="${vals[$i]}"

            if [ "$max_width" -gt 0 ] && [ "${#val}" -gt "$max_width" ]; then
                val="${val:0:$max_width}..."
            fi

            if [ "$color" -eq 1 ]; then
                printf "${c_var}%s${c_reset} = %s\n" "$var" "$val"
            else
                printf "%s = %s\n" "$var" "$val"
            fi
        done
        return 0
    fi

    # --------------------------------------------------------------------------
    # Output Mode 2: Table Formatting (Default)
    # --------------------------------------------------------------------------
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 100)

    local var_width="$max_var_len"
    [ "$var_width" -gt 35 ] && var_width=35

    local val_width
    if [ "$max_width" -gt 0 ]; then
        val_width="$max_width"
    else
        val_width=$(( term_width - var_width - 7 ))
        [ "$val_width" -lt 20 ] && val_width=20
    fi

    local border_line
    border_line=$(printf '+-%*s-+-%*s-+' "$var_width" "" "$val_width" "" | tr ' ' '-')

    printf "%s%s%s\n" "$c_border" "$border_line" "$c_reset"
    printf "${c_border}|${c_reset} ${c_header}%-${var_width}s${c_reset} ${c_border}|${c_reset} ${c_header}%-${val_width}s${c_reset} ${c_border}|${c_reset}\n" "VARIABLE" "VALUE"
    printf "%s%s%s\n" "$c_border" "$border_line" "$c_reset"

    for i in "${!vars[@]}"; do
        local var="${vars[$i]}"
        local val="${vals[$i]}"

        local display_var="$var"
        if [ "${#display_var}" -gt "$var_width" ]; then
            display_var="${display_var:0:$((var_width - 3))}..."
        fi

        if [ "$max_width" -gt 0 ] && [ "${#val}" -gt "$max_width" ]; then
            val="${val:0:$max_width}..."
        fi

        local formatted_val="$val"
        if [ "$max_width" -eq 0 ]; then
            formatted_val=$(echo "$val" | sed 's/:/:\n/g')
        fi

        local first_line=1
        echo "$formatted_val" | fold -w "$val_width" -s | while IFS= read -r line; do
            if [ "$first_line" -eq 1 ]; then
                printf "${c_border}|${c_reset} ${c_var}%-${var_width}s${c_reset} ${c_border}|${c_reset} %-${val_width}s ${c_border}|${c_reset}\n" "$display_var" "$line"
                first_line=0
            else
                printf "${c_border}|${c_reset} %-${var_width}s ${c_border}|${c_reset} %-${val_width}s ${c_border}|${c_reset}\n" "" "$line"
            fi
        done
    done

    printf "%s%s%s\n" "$c_border" "$border_line" "$c_reset"
}

alias penv='envtable'

# Standalone helper to pull remote updates for a given repo path (or multiple paths)
gitsync() {
    local paths=()

    # Parse CLI arguments
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
Usage: gitsync [DIRECTORY ...]

Safely fetch and fast-forward pull remote updates for one or more Git repository directories.

Examples:
  gitsync                      # Sync current directory
  gitsync /path/to/repo        # Sync specific directory
  gitsync ~/repo1 ~/repo2      # Sync multiple directories
EOF
                return 0
                ;;
            -*)
                printf "gitsync: unknown option '%s'\n" "$1" >&2
                return 1
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done

    # Default to current directory if no path is provided
    [ ${#paths[@]} -eq 0 ] && paths=(".")

    for target_dir in "${paths[@]}"; do
        if [ ! -d "$target_dir" ]; then
            echo -e "\033[0;31m[gitsync]\033[0m Directory '$target_dir' does not exist."
            continue
        fi

        # Verify target is inside a git repo
        if ! git -C "$target_dir" rev-parse --is-inside-work-tree &>/dev/null; then
            echo -e "\033[0;31m[gitsync]\033[0m '$target_dir' is not a git repository."
            continue
        fi

        local repo_name
        repo_name=$(basename "$(git -C "$target_dir" rev-parse --show-toplevel)")

        # Verify tracking branch
        if ! git -C "$target_dir" rev-parse '@{u}' &>/dev/null; then
            echo -e "\033[0;33m[gitsync]\033[0m Repo '$repo_name' has no upstream tracking branch set."
            continue
        fi

        echo -e "\033[0;36m[gitsync]\033[0m Checking '$repo_name' (${target_dir})..."

        # Fetch and compare HEAD with upstream
        if git -C "$target_dir" fetch --quiet 2>/dev/null; then
            local local_commit remote_commit
            local_commit=$(git -C "$target_dir" rev-parse HEAD)
            remote_commit=$(git -C "$target_dir" rev-parse '@{u}')

            if [ "$local_commit" != "$remote_commit" ]; then
                echo -e "\033[0;32m[gitsync]\033[0m Updates found for '$repo_name'! Pulling..."
                if git -C "$target_dir" pull --ff-only; then
                    echo -e "\033[0;32m[gitsync]\033[0m Successfully updated '$repo_name'."
                else
                    echo -e "\033[0;31m[gitsync]\033[0m Fast-forward failed for '$repo_name' (check for uncommitted local changes)."
                fi
            else
                echo -e "\033[0;32m[gitsync]\033[0m '$repo_name' is already up to date."
            fi
        else
            echo -e "\033[0;31m[gitsync]\033[0m Network/auth error checking '$repo_name'."
        fi
    done
}


pathgrep() {
    local filter="${1:-}"

    echo "Current \$PATH directories:"
    echo "──────────────────────────────────────────────"

    # Split PATH by colons and loop through them
    tr ':' '\n' <<< "$PATH" | while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue

        # Apply filter if provided (Fixed: 'fi' instead of '}')
        if [[ -n "$filter" ]] && [[ "$dir" != *"$filter"* ]]; then
            continue
        fi

        if [[ -d "$dir" ]]; then
            printf "  \033[0;32m[exists]\033[0m  %s\n" "$dir"
        else
            printf "  \033[0;31m[missing]\033[0m %s\n" "$dir"
        fi
    done
    echo "──────────────────────────────────────────────"
}


mmscan() {
    (
        local mamba_root="${MAMBA_ROOT_PREFIX:-}"
        if [[ -z "$mamba_root" && -n "${CONDA_PREFIX:-}" ]]; then
            mamba_root="${CONDA_PREFIX%/envs/*}"
        fi
        if [[ -z "$mamba_root" ]] && command -v micromamba &>/dev/null; then
            mamba_root="$(micromamba info --json 2>/dev/null | grep -o '"conda_prefix": *"[^"]*"' | cut -d'"' -f4)"
        fi
        if [[ -z "$mamba_root" && -d "$HOME/micromamba" ]]; then
            mamba_root="$HOME/micromamba"
        fi

        [[ -z "$mamba_root" || ! -d "$mamba_root" ]] && exit 1

        local out_file="$mamba_root/env.tools"
        local out_file_bak="$mamba_root/env.tools.bak"

        local env_paths=("$mamba_root")
        if [[ -d "$mamba_root/envs" ]]; then
            for d in "$mamba_root/envs"/*; do
                [[ -d "$d/conda-meta" ]] && env_paths+=("$d")
            done
        fi

        {
            for env_path in "${env_paths[@]}"; do
                [[ ! -d "$env_path/conda-meta" ]] && continue

                local env_name
                if [[ "$env_path" == "$mamba_root" ]]; then
                    env_name="base"
                else
                    env_name="$(basename "$env_path")"
                fi

                for meta in "$env_path/conda-meta"/*.json; do
                    [[ -f "$meta" ]] || continue
                    local pkg_name pkg_version
                    pkg_name=$(grep -m1 '"name":' "$meta" 2>/dev/null | cut -d'"' -f4)
                    pkg_version=$(grep -m1 '"version":' "$meta" 2>/dev/null | cut -d'"' -f4)
                    if [[ -n "$pkg_name" && -n "$pkg_version" ]]; then
                        printf "%s\t%s\t%s\n" "$env_name" "$pkg_name" "$pkg_version"
                    fi
                done
            done
        } > "$out_file_bak"

        mv "$out_file_bak" "$out_file"
    ) &> /dev/null

    # echo "Micromamba scan triggered in the background. Output will update at: ${MAMBA_ROOT_PREFIX:-$HOME/micromamba}/env.tools"
}


# Search for tools in the Micromamba/Conda environment index table (env.tools) and display results in a pretty table format
mmfind() {
    # Helper function to print to stderr
    echoerr() {
        echo "$@" >&2
    }

    local conda_root_dir=""

    # Parse arguments (checking for --root flag)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --root)
                conda_root_dir="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    # Automatically detect root directory if not passed via --root
    if [[ -z "$conda_root_dir" ]]; then
        conda_root_dir="${CONDA_ROOT_DIR:-${CONDA_ROOT_PREFIX:-${MAMBA_ROOT_PREFIX:-${CONDA_ROOT:-${CONDA_PREFIX:-}}}}}"
    fi

    if [[ -z "$conda_root_dir" && -n "${CONDA_PREFIX:-}" ]]; then
        conda_root_dir="${CONDA_PREFIX%/envs/*}"
    fi

    if [[ -z "$conda_root_dir" ]] && command -v micromamba &>/dev/null; then
        conda_root_dir="$(micromamba info --json 2>/dev/null | grep -o '"conda_prefix": *"[^"]*"' | cut -d'"' -f4)"
    fi

    if [[ -z "$conda_root_dir" && -d "$HOME/micromamba" ]]; then
        conda_root_dir="$HOME/micromamba"
    fi

    if [[ -z "$conda_root_dir" ]]; then
        echoerr "ERROR: Micromamba/Conda root directory not detected."
        echoerr "Please set MAMBA_ROOT_PREFIX in your environment or specify it using the --root flag:"
        echoerr "  Usage: mmfind [--root <conda_root>] <tool1> <tool2> ... <toolN>"
        return 1
    fi

    conda_root_dir="${conda_root_dir%/}"
    local env_file="$conda_root_dir/env.tools"

    # Validate index file existence
    if [[ ! -f "$env_file" || ! -r "$env_file" ]]; then
        echoerr "ERROR: Cannot read environment tools index file: '$env_file'"
        echoerr "HINT: Please run 'mmscan' first to generate this index file."
        return 1
    fi

    # Validate command line arguments (tools list)
    if [[ $# -eq 0 ]]; then
        echoerr "Usage: mmfind [--root <conda_root_dir>] <tool1> <tool2> ... <toolN>"
        return 1
    fi

    # Setup Safe Temporary File Handling
    local tmp_results
    tmp_results=$(mktemp)
    trap 'rm -f "$tmp_results"' RETURN

    # Function to render pretty tab-separated tables with Unicode lines
    pretty_print() {
        local input_file="$1"
        if command -v column &>/dev/null; then
            column -t -s $'\t' "$input_file" | awk '
                NR == 1 {
                    print $0
                    # Create a Unicode horizontal line matching the length of the header
                    len = length($0)
                    line = ""
                    for (i = 0; i < len; i++) line = line "─"
                    print line
                }
                NR > 1 { print $0 }
            '
            echo ""
        else
            cat "$input_file"
        fi
    }

    # Write Table Header
    printf "ENVIRONMENT\tTOOL\tVERSION\n" > "$tmp_results"

    # Track missing queries
    local missing_tools=()

    # Search Index File for Requested Tools (Using approximate/substring case-insensitive matching)
    for tool in "$@"; do
        local matched_count
        matched_count=$(awk -v t="$tool" -v out="$tmp_results" '
            BEGIN {
                # Convert search term to lowercase for case-insensitive partial match
                t_lower = tolower(t)
            }
            {
                # Check if package name ($2) contains the search term t
                pkg_lower = tolower($2)
                if (index(pkg_lower, t_lower) > 0) {
                    print $1 "\t" $2 "\t" $3 >> out
                    count++
                }
            }
            END { print count+0 }
        ' "$env_file")

        if [[ "$matched_count" -eq 0 ]]; then
            missing_tools+=("$tool")
        fi
    done

    # Display Results
    echo "Using index: $env_file (approximate search)"
    echo ""

    pretty_print "$tmp_results"

    # Report Missing Tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "" >&2
        echoerr "--------------------------------------------------"
        for missing in "${missing_tools[@]}"; do
            echoerr "WARNING: No packages matched search pattern '$missing'"
        done
        echoerr "--------------------------------------------------"
    fi
}

# find the executable path of a command and its associated environment (if inside a conda/mamba prefix)
mmwhich() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: mmwhich <command_name>" >&2
        return 1
    fi

    for cmd in "$@"; do
        if command -v "$cmd" &>/dev/null; then
            local bin_path
            bin_path="$(command -v "$cmd")"
            local real_path="$bin_path"

            # Resolve symlinks if it's a symlink
            if [[ -L "$bin_path" ]]; then
                real_path="$(readlink -f "$bin_path" 2>/dev/null || readlink "$bin_path")"
            fi

            printf "\033[1;33m%s\033[00m found:\n" "$cmd"
            printf "  Binary Path : %s\n" "$bin_path"
            [[ "$bin_path" != "$real_path" ]] && printf "  Resolved To : %s\n" "$real_path"

            # Show which environment it belongs to if inside a conda/mamba prefix
            if [[ "$bin_path" == */envs/* || "$bin_path" == *"/mamba"* || "$bin_path" == *"/miniconda"* ]]; then
                local env_name
                env_name=$(echo "$bin_path" | sed -E 's|(.*/envs/([^/]+)/).*|\2|')
                [[ "$env_name" == "$bin_path" ]] && env_name="base (root)"
                printf "  Environment : %s\n" "$env_name"
            fi
            echo ""
        else
            printf "\033[0;31m%s\033[00m: not found in current PATH\n" "$cmd" >&2
        fi
    done
}

# Grep with automatic header preservation (supports all grep flags and multiple files)
hgrep() {
    local -a files=()
    local -a grep_args=()

    # Separate file arguments from grep flags/patterns
    for arg in "$@"; do
        if [[ -f "$arg" ]]; then
            files+=("$arg")
        else
            grep_args+=("$arg")
        fi
    done

    # If no files detected (e.g. reading from stdin), fallback to standard grep
    if [ ${#files[@]} -eq 0 ]; then
        command grep "$@"
        return $?
    fi

    local f
    for f in "${files[@]}"; do
        # 1. Print header(s):
        #    - Prints all lines starting with '#' (metadata/comment headers)
        #    - If no '#' lines exist, prints the very first line (column header)
        awk '
            NR==1 { first=$0 }
            /^#/ { print; has_header=1; next }
            END {
                if (!has_header && first != "") { print first }
            }
        ' "$f"

        # 2. Run standard grep on the file with all user flags and patterns
        command grep "${grep_args[@]}" "$f"
    done
}


# Run commands inside containers with automatic runtime detection (Apptainer, Singularity, Podman, Docker) and path mounting
runin() {
    if [[ $# -lt 2 ]]; then
        cat <<'EOF' >&2
Usage: runin <container_image> <command [args...]>
Examples:
  runin alpine:latest uname -a
  runin stefanos/circos circos -conf circos.conf
  runin python:3.9-alpine python3 --version
EOF
        return 1
    fi

    local image="$1"
    shift

    # 1. Determine container runtime (Prioritize HPC standards first, then local)
    local runtime=""
    if command -v apptainer &>/dev/null; then
        runtime="apptainer"
    elif command -v singularity &>/dev/null; then
        runtime="singularity"
    elif command -v podman &>/dev/null; then
        runtime="podman"
    elif command -v docker &>/dev/null; then
        runtime="docker"
    else
        echo "ERROR: No container runtime found (apptainer, singularity, podman, docker)." >&2
        return 1
    fi

    # 2. Configure runtime-specific arguments and image prefixes
    local -a rt_args=()

    if [[ "$runtime" == "apptainer" || "$runtime" == "singularity" ]]; then
        # Apptainer / Singularity configuration
        # If image is a remote reference (not a local .sif file and lacks transport), prepend docker://
        if [[ "$image" != *.sif && "$image" != *://* ]]; then
            image="docker://$image"
        fi

        rt_args=(exec --bind "$PWD:/work")
        # Apptainer automatically runs as the current user, avoiding root-owned files.
    else
        # Podman / Docker configuration
        rt_args=(run --interactive --tty --rm --volume "$PWD:/work:z" --workdir /work)
        if [[ "$runtime" == "podman" || "$runtime" == "docker" ]]; then
            rt_args+=(--user "$(id -u):$(id -g)")
        fi
    fi

    # 3. Smart path translation for arguments
    local -a mapped_args=()
    for arg in "$@"; do
        if [[ -e "$arg" ]]; then
            local abs_path
            abs_path="$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"
            if [[ "$abs_path" == "$PWD"* ]]; then
                local rel_path="${abs_path#$PWD/}"
                mapped_args+=("/work/$rel_path")
            else
                local ext_dir
                ext_dir="$(dirname "$abs_path")"
                local ext_base
                ext_base="$(basename "$abs_path")"
                if [[ "$runtime" == "apptainer" || "$runtime" == "singularity" ]]; then
                    rt_args+=(--bind "$ext_dir:/mnt/ext_$(basename "$ext_dir")")
                else
                    rt_args+=(--volume "$ext_dir:/mnt/ext_$(basename "$ext_dir"):z")
                fi
                mapped_args+=("/mnt/ext_$(basename "$ext_dir")/$ext_base")
            fi
        else
            mapped_args+=("$arg")
        fi
    done

    # 4. Execute command
    if [[ "$runtime" == "apptainer" || "$runtime" == "singularity" ]]; then
        "$runtime" "${rt_args[@]}" "$image" "${mapped_args[@]}"
    else
        "$runtime" "${rt_args[@]}" "$image" "${mapped_args[@]}"
    fi
}


wttr() {
    local location="${1}"
    local request

    if [ -z "$location" ]; then
        # If no argument is provided, wttr.in automatically detects location via IP
        request="wttr.in/"
    else
        request="wttr.in/${location}"
    fi

    [ "$(tput cols)" -lt 125 ] && request+='?n'
    curl -H "Accept-Language: ${LANG%_*}" --compressed "$request"
}

clock() {
    # If arguments are passed, map friendly names or use them as timezones
    if [ "$#" -gt 0 ]; then
        for city in "$@"; do
            local tz="$city"
            # Map common city names to proper timezones
            case "${city,,}" in
                chennai|mumbai|delhi|bangalore|india) tz="Asia/Kolkata" ;;
                london|uk)                           tz="Europe/London" ;;
                amsterdam|netherlands|holland)       tz="Europe/Amsterdam" ;;
                newyork|ny)                          tz="America/New_York" ;;
                tokyo)                               tz="Asia/Tokyo" ;;
                sydney)                              tz="Australia/Sydney" ;;
            esac

            printf "  ┃ %-22s │ %s\n" "$city" "$(TZ="$tz" date '+%a, %d %b — %H:%M:%S %Z')"
        done
        return
    fi

    # Fixed padding layout for the default world clock
    echo "  ╭────────────────────────────────────────────────────────╮"
    echo "  │                      🌍 WORLD CLOCK                    │"
    echo "  ├────────────────────────────────────────────────────────┤"
    printf "  │  📍 Local (Current)     │  %s  │\n"   "$(date '+%a, %d %b — %H:%M:%S %Z')"
    printf "  │  🇳🇱 Netherlands         │  %s  │\n"   "$(TZ="Europe/Amsterdam" date '+%a, %d %b — %H:%M:%S %Z')"
    printf "  │  🇬🇧 London (UK)         │  %s  │\n"   "$(TZ="Europe/London" date '+%a, %d %b — %H:%M:%S %Z')"
    printf "  │  🇮🇳 India (IST)         │  %s  │\n"   "$(TZ="Asia/Kolkata" date '+%a, %d %b — %H:%M:%S %Z')"
    echo "  ╰────────────────────────────────────────────────────────╯"
}
