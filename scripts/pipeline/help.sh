#!/usr/bin/env bash
# Print the Makefile targets, grouped and coloured by the ##@ section markers.

set -euo pipefail

# shellcheck source=scripts/pipeline/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# One colour per section. Unlisted sections fall back to DEFAULT_COLOR.
SECTION_COLORS="Setup=38;5;220,Deploy=38;5;170,Inspect=38;5;39,Teardown=38;5;196,Help=38;5;80"
DEFAULT_COLOR="38;5;80"
BANNER_COLOR="38;5;141"
HEADER_COLOR="38;5;208"
WARNING_COLOR="38;5;196"

# Sections follow the include order of the Makefile, not the alphabet.
# Includes that do not resolve to a readable file are skipped, so a conditional
# include never breaks the help.
makefiles() {
  printf '%s\n' "${PROJECT_ROOT}/Makefile"
  awk '/^include /{print $2}' "${PROJECT_ROOT}/Makefile" |
    while read -r rel; do
      [[ -f "${PROJECT_ROOT}/${rel}" ]] && printf '%s\n' "${PROJECT_ROOT}/${rel}"
    done
}

# Targets are collected and grouped, not printed as they are read: a section is
# declared in whichever fragment happens to own a target, so the same section
# appears in several files and printing in file order would repeat its header.
# SECTION_COLORS drives both the colour and the display order, so the sections
# read in a deliberate order rather than in the include order of the Makefile.
print_targets() {
  awk -v colors="$SECTION_COLORS" -v fallback="$DEFAULT_COLOR" '
    BEGIN {
      ordered = split(colors, pairs, ",")
      for (i = 1; i <= ordered; i++) {
        split(pairs[i], kv, "=")
        color[kv[1]] = kv[2]
        rank[kv[1]] = i
        listed[i] = kv[1]
      }
      section = "Other"
    }
    /^##@ / {
      section = substr($0, 5)
      if (!(section in seen)) { seen[section] = ++extras; extra[extras] = section }
      next
    }
    /^[a-z][a-z0-9-]*:.*## / {
      split($0, parts, ":.*## ")
      if (!(section in seen)) { seen[section] = ++extras; extra[extras] = section }
      body[section] = body[section] sprintf("  \033[%sm%-16s\033[0m %s\n", \
        (section in color) ? color[section] : fallback, parts[1], parts[2])
    }
    END {
      for (i = 1; i <= ordered; i++) show(listed[i])
      for (i = 1; i <= extras; i++) if (!(extra[i] in rank)) show(extra[i])
    }
    function show(name) {
      if (name == "" || body[name] == "") return
      printf "\n\033[1;%sm%s\033[0m\n", (name in color) ? color[name] : fallback, name
      printf "%s", body[name]
    }
  ' "$@"
}

# Quoted heredoc, so the block art survives untouched.
banner_art() {
  cat <<'BANNER'
⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢈⣾⣿⡇⠀⠀⠀⠀⠀⢀⣼⡇⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⡇⠀⠀⠀⠀⣴⣿⣿⠃⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣇⠀⠀⢀⣾⣿⣿⣿⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢰⡿⠉⠀⡜⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀
⠀⠀⠒⠒⠸⣿⣄⢀⣃⣿⣿⡟⠉⠉⠉⢹⣿⡇⠀⠀⠀⠀⠀
⠀⠀⠚⠉⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠁⠘⠠⠁⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠛⠛⠛⠛⠛⠁⠀⠒⠤⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⠀⠀⠀⠀⠀⠀
BANNER
}

# Every line of the art is exactly this wide. Kept as a constant rather than
# measured, because bash pads `%-*s` by bytes and each braille cell is three of
# them, so a computed width would indent the right column into the art.
BANNER_WIDTH=23
BANNER_GAP=2

# The header beside the art, as colour and text pairs. Wrapped here rather than
# written pre-wrapped, so it still reads on a narrow terminal.
header_lines() {
  local width="$1"
  local -a pairs=(
    "${BANNER_COLOR}|Simplon quiz, deployment control"
    "|"
    "${HEADER_COLOR}|Usage: make <target> [VAR=value]"
    "${HEADER_COLOR}|Nothing here touches Azure: each target dispatches a workflow and follows its run."
    "${HEADER_COLOR}|Override a variable on the command line, not through the environment."
    "${HEADER_COLOR}|Every run appends to ${LOG_FILE:-.logs/pipeline.log}, timestamped and without colours."
  )

  local pair colour text line
  for pair in "${pairs[@]}"; do
    colour="${pair%%|*}"
    text="${pair#*|}"
    if [[ -z "${text}" ]]; then
      printf '\n'
      continue
    fi
    while IFS= read -r line; do
      printf '\033[%sm%s\033[0m\n' "${colour:-0}" "${line}"
    done < <(printf '%s\n' "${text}" | fold -s -w "${width}")
  done
}

# The art on the left, the header on the right, the shorter of the two centred
# against the taller. Falls back to stacking when the terminal cannot hold both,
# rather than wrapping the art into itself.
print_header() {
  local cols; cols=$(tput cols 2>/dev/null || echo 80)
  local avail=$(( cols - BANNER_WIDTH - BANNER_GAP ))

  mapfile -t art < <(banner_art)

  if [[ "${avail}" -lt 32 ]]; then
    printf '\033[1;%sm\n' "${BANNER_COLOR}"
    printf '%s\n' "${art[@]}"
    printf '\033[0m\n'
    header_lines "$(( cols > 32 ? cols : 32 ))"
    return
  fi

  mapfile -t text < <(header_lines "${avail}")

  local rows=$(( ${#art[@]} > ${#text[@]} ? ${#art[@]} : ${#text[@]} ))
  local offset=$(( (${#art[@]} - ${#text[@]}) / 2 ))
  [[ "${offset}" -lt 0 ]] && offset=0

  local i left right pad
  echo
  for (( i = 0; i < rows; i++ )); do
    left="${art[i]:-}"
    right=""
    [[ "${i}" -ge "${offset}" ]] && right="${text[i - offset]:-}"

    pad=$(( BANNER_WIDTH - ${#left} + BANNER_GAP ))
    [[ "${pad}" -lt 1 ]] && pad=1

    printf '\033[1;%sm%s\033[0m%*s%s\n' \
      "${BANNER_COLOR}" "${left}" "${pad}" '' "${right}"
  done
  echo
}

say() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }

main() {
  # Only when a human is watching: clearing breaks a pipe and litters a CI log.
  [[ -t 1 ]] && clear
  print_header
  say "1;$WARNING_COLOR" "⚠️  destroy tears down the whole environment, and nothing is protected any more"
  mapfile -t files < <(makefiles)
  print_targets "${files[@]}"
  echo
}

main "$@"
