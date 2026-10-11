#!/usr/bin/env bash
#
# lint_theme.sh — Isocline design-system ratchet (element F9)
#
# Counts the legacy look-and-feel patterns the Paper & Instrument transition retires,
# and fails if any count has RISEN above the recorded baseline. Each redesign phase
# ratchets the baseline down; it must never go up.
#
# Spec: docs/design/ISOCLINE_ELEMENT_IMPLEMENTATION.md  (PART 9 · Verification map, F9)
# Plan: docs/planning/implementation/isocline-app-transition.md
#
# Usage:
#   tools/scripts/lint_theme.sh            # check current counts vs baseline (CI gate)
#   tools/scripts/lint_theme.sh --update   # rewrite the baseline to the current counts
#   tools/scripts/lint_theme.sh --show     # print current counts, don't compare
#
# Metrics (each counts matching source LINES under xT/):
#   font_system        .font(.system(…)          — bypasses Theme.Fonts (F2)
#   font_textstyle     .font(.body) etc.          — bare text-style, bypasses the aliases (F2)
#   hex_outside_theme  Color(hex:…) / "#rrggbb"   — colour literals outside Theme/ (F3)
#   glass_effect       .glassEffect(…)            — glass on content is banned (S1, T3)
#   gradients_brand    Gradients.brand            — brand gradient as a ground (F4)
#   color_dot_system   Color(.system…)            — system UIColors instead of the palette (F3)
#
# Exclusions: Theme/ and TimeContentTypes.swift are the sanctioned homes for raw colour
# values (the Time palette is excluded from the baseline per T5).
#
# Written for bash 3.2 (macOS default) — no associative arrays.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/xT"
BASELINE="$ROOT/tools/scripts/theme_lint_baseline.txt"

# Metric keys, in display order.
METRICS=(font_system font_textstyle hex_outside_theme glass_effect gradients_brand color_dot_system)

# count_metric <key> -> prints an integer
count_metric() {
    # grep exits 1 when a pattern has zero matches; `|| true` keeps that from
    # aborting under `set -euo pipefail` once a metric is fully ratcheted to 0.
    case "$1" in
        font_system)
            { grep -rn '\.font(\.system' "$SRC" --include='*.swift' || true; } | wc -l ;;
        font_textstyle)
            { grep -rnE '\.font\(\.(largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)\b' \
                "$SRC" --include='*.swift' || true; } | wc -l ;;
        hex_outside_theme)
            { grep -rnE 'Color\(hex:|"#[0-9A-Fa-f]{6,8}"' "$SRC" --include='*.swift' \
                | grep -vE '/Theme/|TimeContentTypes\.swift' || true; } | wc -l ;;
        glass_effect)
            { grep -rn '\.glassEffect(' "$SRC" --include='*.swift' || true; } | wc -l ;;
        gradients_brand)
            { grep -rn 'Gradients\.brand' "$SRC" --include='*.swift' || true; } | wc -l ;;
        color_dot_system)
            { grep -rn 'Color(\.system' "$SRC" --include='*.swift' || true; } | wc -l ;;
        *)
            echo "0" ;;
    esac
}

# Collect current counts into an indexed array parallel to METRICS.
CURRENT=()
for m in "${METRICS[@]}"; do
    # `wc -l` can emit leading spaces; strip to a bare integer.
    CURRENT+=("$(count_metric "$m" | tr -d '[:space:]')")
done

# baseline_value <key> -> prints the recorded count, or empty if absent.
baseline_value() {
    [[ -f "$BASELINE" ]] || return 0
    grep -E "^$1=" "$BASELINE" | head -n1 | cut -d'=' -f2
}

write_baseline() {
    {
        echo "# Isocline theme-lint baseline (F9). Regenerate: tools/scripts/lint_theme.sh --update"
        echo "# Counts may only go DOWN. Last written: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        local i=0
        for m in "${METRICS[@]}"; do
            echo "${m}=${CURRENT[$i]}"
            i=$((i + 1))
        done
    } > "$BASELINE"
    echo "Wrote baseline → ${BASELINE#"$ROOT"/}"
}

case "${1:-}" in
    --update)
        write_baseline
        exit 0 ;;
    --show)
        printf '%-20s %8s\n' "metric" "current"
        i=0
        for m in "${METRICS[@]}"; do
            printf '%-20s %8s\n' "$m" "${CURRENT[$i]}"
            i=$((i + 1))
        done
        exit 0 ;;
esac

if [[ ! -f "$BASELINE" ]]; then
    echo "No baseline at ${BASELINE#"$ROOT"/}. Creating one from current counts." >&2
    write_baseline
    exit 0
fi

# Compare.
printf '%-20s %8s %10s\n' "metric" "current" "baseline"
printf '%-20s %8s %10s\n' "--------------------" "-------" "--------"
fail=0
i=0
for m in "${METRICS[@]}"; do
    cur="${CURRENT[$i]}"
    base="$(baseline_value "$m")"
    [[ -z "$base" ]] && base=0
    printf '%-20s %8s %10s\n' "$m" "$cur" "$base"
    if (( cur > base )); then
        echo "✗ $m rose: $base → $cur (legacy pattern reintroduced)" >&2
        fail=1
    fi
    i=$((i + 1))
done

if (( fail )); then
    echo "" >&2
    echo "Theme lint failed: a retired pattern count increased. Fix the new call sites," >&2
    echo "or — if you intentionally lowered another metric — run --update to re-baseline." >&2
    exit 1
fi

echo ""
echo "✓ theme lint passed — no retired pattern rose above baseline."
