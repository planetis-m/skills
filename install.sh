#!/usr/bin/env bash
# Install / update nim-skills symlinks into one or more agent dirs.
#
# Usage: install.sh [-n] [-q] [TARGET ...]
#
# TARGET is an agent root (e.g. ~/.agents, ~/.claude). Skills are symlinked
# into TARGET/skills/<skill-name>. Defaults to ~/.agents if no targets given.
#
# For each target, the script will:
#   - create TARGET/skills/ if missing
#   - symlink every skill directory in this repo into TARGET/skills/
#   - prune symlinks in TARGET/skills/ that point back into this repo but
#     whose source no longer exists (handles renamed/deleted skills)

set -euo pipefail

DRY_RUN=0
QUIET=0
TARGETS=()

usage() {
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    cat <<EOF

Options:
  -n, --dry-run   Show actions without making changes
  -q, --quiet     Suppress per-action output
  -h, --help      Show this help
EOF
}

log() { [[ $QUIET -eq 1 ]] || echo "$@"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
        *) TARGETS+=("$1"); shift ;;
    esac
done

[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=("$HOME/.agents")

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        log "DRY: $*"
    else
        log "$*"
        "$@"
    fi
}

is_skill_dir() {
    [[ -d "$1" && -f "$1/SKILL.md" ]]
}

install_to() {
    local target="${1/#\~/$HOME}"
    local skills_dir="$target/skills"
    log ""
    log "== $skills_dir =="

    [[ -d "$skills_dir" ]] || run mkdir -p "$skills_dir"

    # Install/update symlinks for skills present in repo.
    local entry name
    for entry in "$REPO_DIR"/*/; do
        is_skill_dir "$entry" || continue
        name="$(basename "$entry")"
        local link="$skills_dir/$name"
        local src="${entry%/}"

        if [[ -L "$link" ]]; then
            local current
            current="$(readlink "$link")"
            if [[ "$current" == "$src" ]]; then
                log "ok    $name"
                continue
            fi
            run ln -sfn "$src" "$link"
        elif [[ -e "$link" ]]; then
            log "skip  $name (exists, not a symlink)"
            continue
        else
            run ln -s "$src" "$link"
        fi
    done

    # Prune stale symlinks pointing into this repo whose source is gone.
    if [[ -d "$skills_dir" ]]; then
        local link target_path
        for link in "$skills_dir"/*; do
            [[ -L "$link" ]] || continue
            target_path="$(readlink "$link")"
            [[ "$target_path" == "$REPO_DIR"/* ]] || continue
            if [[ ! -e "$target_path" ]]; then
                run rm "$link"
                log "prune $(basename "$link")"
            fi
        done
    fi
}

for t in "${TARGETS[@]}"; do
    install_to "$t"
done
