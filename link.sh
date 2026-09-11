#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

CHECK=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK=1
fi

# Discover groups: top-level dirs (excluding skills/ and dotfiles) that
# contain at least one */SKILL.md one level inside them.
groups=()
for dir in */; do
  dir="${dir%/}"
  [[ "$dir" == .* ]] && continue
  [[ "$dir" == "skills" ]] && continue
  [[ -d "$dir" ]] || continue
  if compgen -G "$dir"/*/SKILL.md > /dev/null; then
    groups+=("$dir")
  fi
done

# Collect <name> -> <group> across all groups (parallel arrays, since this
# must run under bash 3.2 which has no associative arrays), verifying
# frontmatter and checking for namespace collisions.
names=()
name_groups=()
for group in "${groups[@]}"; do
  for skill_md in "$group"/*/SKILL.md; do
    [[ -e "$skill_md" ]] || continue
    name_dir="$(basename "$(dirname "$skill_md")")"
    fm_name="$(awk '
      BEGIN { in_fm = 0 }
      /^---[[:space:]]*$/ {
        if (in_fm == 0) { in_fm = 1; next } else { exit }
      }
      in_fm == 1 && $0 ~ /^name:[[:space:]]*/ {
        sub(/^name:[[:space:]]*/, "");
        gsub(/^["'"'"']|["'"'"']$/, "");
        print;
        exit
      }
    ' "$skill_md")"

    if [[ "$fm_name" != "$name_dir" ]]; then
      echo "error: $skill_md frontmatter name '$fm_name' does not match directory name '$name_dir'" >&2
      exit 1
    fi

    for existing in "${names[@]+"${names[@]}"}"; do
      if [[ "$existing" == "$name_dir" ]]; then
        echo "error: skill name '$name_dir' found in more than one group — namespace collision" >&2
        exit 1
      fi
    done

    names+=("$name_dir")
    name_groups+=("$group")
  done
done

changes=0
created_count=0

if [[ "$CHECK" -eq 0 ]]; then
  mkdir -p skills
fi

for i in "${!names[@]}"; do
  name="${names[$i]}"
  group="${name_groups[$i]}"
  target="../$group/$name"
  link_path="skills/$name"

  if [[ -L "$link_path" ]]; then
    current_target="$(readlink "$link_path")"
    if [[ "$current_target" == "$target" ]]; then
      continue
    fi
    if [[ "$CHECK" -eq 1 ]]; then
      echo "would update: $link_path -> $target (was: $current_target)"
      changes=1
      continue
    fi
    ln -sfn "$target" "$link_path"
    echo "linked: $link_path -> $target"
    created_count=$((created_count + 1))
  elif [[ -e "$link_path" ]]; then
    echo "error: $link_path exists as a real directory (looks tool-installed or foreign) — resolve manually" >&2
    exit 1
  else
    if [[ "$CHECK" -eq 1 ]]; then
      echo "would create: $link_path -> $target"
      changes=1
      continue
    fi
    ln -sfn "$target" "$link_path"
    echo "linked: $link_path -> $target"
    created_count=$((created_count + 1))
  fi
done

# Remove stale symlinks in skills/ whose target no longer exists.
if [[ -d skills ]]; then
  for entry in skills/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    if [[ -L "$entry" && ! -e "$entry" ]]; then
      if [[ "$CHECK" -eq 1 ]]; then
        echo "would remove stale symlink: $entry"
        changes=1
      else
        rm "$entry"
        echo "removed stale symlink: $entry"
      fi
    fi
  done
fi

if [[ "$CHECK" -eq 1 ]]; then
  if [[ "$changes" -eq 1 ]]; then
    exit 1
  else
    echo "no changes needed"
    exit 0
  fi
fi

echo "done: $created_count link(s) created/refreshed"
