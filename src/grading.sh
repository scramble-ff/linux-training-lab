# Objective positions are saved in checkpoints. Append new criteria after existing ones.
puzzle_objectives() {
    objectives=()
    case "$1" in
        27) objectives=('Select both approved revisions' 'Preserve both warehouse originals' 'Assemble the exact handoff') ;;
        29) objectives=('Identify missing crates' 'Identify extra crates') ;;
        30) objectives=('Preserve archive integrity' 'Recover the verified note' 'Report dock and pallet count') ;;
        28) objectives=('Identify unresolved EAST tickets' 'List each ticket once in order') ;;
        37) objectives=('Identify qualifying time and ticket pairs' 'Build an ordered, unique timeline') ;;
        39) objectives=('Identify the unapproved mode change' 'Trace the approved change to its ticket') ;;
        40) objectives=('Restore LF line endings' 'Repair IDs and preserve destination records' 'Preserve the rejected manifest') ;;
        38) objectives=('Apply approved access' 'Preserve all other file modes') ;;
    esac
}

packet_sheets() {
    local directory=$1 task=$2 north=03 west=05 route rev index original copy
    if (( variant )); then
        printf -v north '%02d' "$((1 + 16#${seed:0:2} % 6))"
        printf -v west '%02d' "$((1 + 16#${seed:2:2} % 6))"
    fi
    for route in north west; do
        if [[ "$route" == north ]]; then rev=$north; index=0
        else rev=$west; index=1; fi
        original=$(find "$directory/warehouse" -type f -name "route-$route-r$rev.txt" -print -quit)
        copy="$directory/handoff/$route-route.txt"
        if [[ "$task" == originals ]]; then
            [[ -f "$original" ]] && cmp -s -- "$original" <(packet_sheet "$route" "$index" "$((10#$rev))") ||
                fail "Check the original $route sheet in the warehouse."
        else
            [[ -f "$copy" && ! -L "$copy" && ! "$copy" -ef "$original" ]] &&
                cmp -s -- "$copy" <(packet_sheet "$route" "$index" "$((10#$rev))") ||
                fail "Check the revision and contents of $route-route.txt and make an independent copy."
        fi
    done
}

packet_manifest() (
    local handoff="$1/handoff" reference="$1/reference-manifest.txt"
    [[ -d "$handoff" && ! -L "$handoff" ]] || fail 'Create the handoff directory.'
    shopt -s dotglob nullglob
    local -a contents=("$handoff/"*)
    (( ${#contents[@]} == 3 )) && [[ -f "$handoff/north-route.txt" && -f "$handoff/west-route.txt" &&
        -f "$handoff/manifest.txt" && ! -L "$handoff/manifest.txt" && ! "$handoff/manifest.txt" -ef "$reference" ]] ||
        fail 'Include exactly the two named route sheets and a separate manifest.'
    if ! cmp -s -- "$handoff/manifest.txt" <(printf '%s\n' north-route.txt west-route.txt); then
        local line expected number=0
        for expected in north-route.txt west-route.txt; do
            number=$((number+1))
            IFS= read -r line && [[ "$line" == "$expected" ]] ||
                fail "Check line $number of manifest.txt. Expected $expected followed by a newline."
        done < "$handoff/manifest.txt"
        fail 'Remove the extra content after line 2 of manifest.txt.'
    fi
)

archive_integrity() {
    local folder=$1 expected actual
    [[ -f "$folder/.original.sha256" ]] || fail 'This older lesson has no original checksum. Use bn restart to keep your attempt and generate a verified archive.'
    read -r expected _ < "$folder/.original.sha256"
    [[ -f "$folder/recovery.tar.gz" && ! -L "$folder/recovery.tar.gz" ]] || fail 'Restore recovery.tar.gz.'
    actual=$(sha256sum < "$folder/recovery.tar.gz")
    [[ "${actual%% *}" == "$expected" ]] || fail 'The original archive checksum differs.'
}

check_puzzle_objective() {
    local id=$1 index=$2 directory=$3 expected report ticket dock=DOCK-05 pallets=18 variant=0
    if [[ -f "$directory/.seeded-puzzle" ]]; then
        variant=$(puzzle_variant)
        printf -v dock 'DOCK-%02d' "$((1+variant%8))"
        pallets=$((9+variant%29))
    fi
    case "$id.$index" in
        27.1) packet_sheets "$directory" copies ;;
        27.2) packet_sheets "$directory" originals ;;
        27.3) packet_manifest "$directory" ;;
        29.1) check_report "$directory/missing.txt" "$(printf 'CRATE-%03d\n' "$((16+variant))" "$((44+variant))" "$((70+variant))")" 'Check the SOUTH crates missing from intake.' ;;
        29.2) check_report "$directory/extra.txt" "$(printf 'CRATE-%03d\n' "$((86+variant))" "$((90+variant))" "$((94+variant))")" 'Check the SOUTH crates absent from the plan.' ;;
        30.1) archive_integrity "$directory" ;;
        30.2) check_report "$directory/recovery/verified-note.txt" "$(printf 'Batch BATCH-044\nState VERIFIED\nDock %s\nPallets %s' "$dock" "$pallets")" 'Copy the verified BATCH-044 note into recovery/verified-note.txt.' ;;
        30.3) check_report "$directory/recovery/summary.txt" "$dock"$'\n'"$pallets" 'Record the dock then the pallet count in recovery/summary.txt.' ;;
        28.*|37.*)
            if [[ "$id" == 28 ]]; then
                report="$directory/holds.txt"
                expected=$(for (( ticket=12; ticket<=96; ticket+=12 )); do printf 'TICKET-%04d\n' "$((ticket+variant))"; done)
            else
                report="$directory/timeline.txt"
                expected=$(timeline_rows)
            fi
            [[ -s "$report" ]] || fail "Write the report in ${report##*/}."
            if [[ "$index" == 1 ]]; then
                [[ "$(LC_ALL=C sort -u -- "$report")" == "$expected" ]] || fail 'Check the selected records against the logs.'
            else
                LC_ALL=C sort -cu -- "$report" 2>/dev/null || fail 'Sort the report and remove duplicate rows.'
            fi ;;
        38.1) check_access_modes "$directory" approved ;;
        38.2) check_access_modes "$directory" other ;;
        39.*)
            report="$directory/audit.txt"
            [[ -f "$report" && ! -L "$report" ]] || fail 'Write your findings in audit.txt.'
            if [[ "$index" == 1 ]]; then
                cmp -s <(head -n 1 -- "$report") <(printf 'INVESTIGATE|/dispatch/bin/tool-%d|0755|4755\n' "$((1017+variant))") ||
                    fail 'Review the path and both modes in the investigation line.'
            else
                cmp -s <(tail -n +2 -- "$report") <(printf 'APPROVED|/dispatch/bin/tool-%d|T-%d\n' "$((1009+variant))" "$variant") ||
                    fail 'Check the approved path and ticket on line 2, then end the report.'
            fi ;;
        40.1|40.2)
            report="$directory/repaired.txt"
            [[ -f "$report" && ! -L "$report" && ! "$report" -ef "$directory/rejected.txt" ]] || fail 'Create an independent repaired.txt.'
            if [[ "$index" == 1 ]]; then
                [[ -s "$report" ]] && ! LC_ALL=C grep -q $'\r' "$report" && cmp -s <(tail -c 1 -- "$report") <(printf '\n') ||
                    fail 'Check for carriage returns and a final LF.'
            else
                LC_ALL=C awk 'NR==FNR {expected[NR]=$0; count=NR; next}
                    {sub(/\r$/, ""); if (FNR>count || $0!=expected[FNR]) {bad=FNR; exit 1} seen=FNR}
                    END {if (bad || seen<count) {print "Check manifest record " (bad ? bad : seen+1) " (header is record 1)."; exit 1}}' \
                    <(manifest_rows clean) "$report" || return 1
            fi ;;
        40.3)
            report="$directory/rejected.txt"
            [[ -f "$report" && ! -L "$report" ]] && cmp -s -- "$report" <(manifest_rows rejected) ||
                fail 'The rejected manifest must match the original bytes.' ;;
        *) fail 'Unknown puzzle objective.' ;;
    esac
}

grade_puzzle() {
    local -a results=()
    local directory index feedback passed=0 key before=$earned
    directory=$(folder "$current")
    for index in "${!objectives[@]}"; do
        key="$current.$((index+1))"
        if feedback=$(check_puzzle_objective "$current" "$((index+1))" "$directory" 2>&1); then
            results+=("  [x] ${objectives[index]}")
            passed=$((passed + 1))
            if [[ "$earned" != *",$key,"* ]]; then earned+="$key,"; fi
        else
            results+=("  [ ] ${objectives[index]} — $feedback")
        fi
    done
    if [[ "$before" != "$earned" ]]; then save_state; fi
    if [[ ${1:-} == submit ]] && (( passed == ${#objectives[@]} )); then return 0; fi
    printf '%s\n' "${results[@]}"
    printf '%d/%d objectives currently met.\n' "$passed" "${#objectives[@]}"
    (( passed == ${#objectives[@]} ))
}

# Three rows of terminal cells keep the arcade readout readable without a font dependency.
arcade_progress() {
    local solved=$1 limit=$2 percent filled i glyph line row rows cols=0
    local -a top=('┏━┓' '╺┓ ' '╺━┓' '╺━┓' '╻ ╻' '┏━╸' '┏━╸' '╺━┓' '┏━┓' '┏━┓')
    local -a middle=('┃ ┃' ' ┃ ' '┏━┛' '╺━┫' '┗━┫' '┗━┓' '┣━┓' '  ┃' '┣━┫' '┗━┫')
    local -a bottom=('┗━┛' '╺┻╸' '┗━╸' '╺━┛' '  ╹' '╺━┛' '┗━┛' '  ╹' '┗━┛' '╺━┛')
    percent=$(((100 * solved + limit / 2) / limit))
    filled=$(((20 * solved + limit / 2) / limit))
    # Keep the final segment for the submission that actually clears the run.
    if (( solved < limit && filled == 20 )); then filled=19; fi
    if [[ -t 1 && "$star" == '✦' ]]; then
        read -r rows cols < <(stty -F /dev/tty size 2>/dev/null) || cols=0
    fi
    if (( cols >= 44 )); then
        for row in top middle bottom; do
            local -n digits="$row"
            line=''
            for ((i=0; i<${#percent}; i++)); do
                glyph=${percent:i:1}
                line+="${digits[glyph]} "
            done
            printf '%s%s%s' "$sky" "$line" "$reset"
            case "$row" in
                top) printf '  %s' "$heading" ;;
                middle) printf '  %d%%  ·  Solved: %d / %d' "$percent" "$solved" "$limit" ;;
            esac
            printf '\n'
        done
    else
        printf '%s\n%s%d%%%s  Solved: %d / %d\n' "$heading" "$sky" "$percent" "$reset" "$solved" "$limit"
    fi

    local tint
    for ((i=0; i<filled; i++)); do
        if (( i < 6 )); then tint=$sky
        elif (( i < 14 )); then tint=$pink
        else tint=$gold; fi
        printf '%s%s%s' "$tint" "$block" "$reset"
    done
    printf '\n\n'
}

show_stats() {
    local details=$1 position id index key marks status solved limit elapsed heading run=Course
    local independent=0 assisted=0 available=0 verified=0 possible=0 puzzles=0
    local next_label='' next_action='' checklist='' pink='' sky='' gold='' reset=''
    local star='*' arrow='>' block='#' locale_name=${LC_ALL:-${LC_CTYPE:-${LANG:-C}}}
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then
        case "${locale_name^^}" in
            *UTF-8*|*UTF8*) star='✦' arrow='▸' block='▰' ;;
        esac
        if [[ -z ${NO_COLOR:-} ]]; then
            pink=$'\033[1;95m' sky=$'\033[1;96m' gold=$'\033[1;93m' reset=$'\033[0m'
            if [[ "$TERM" == *256color* || ${COLORTERM:-} == truecolor || ${COLORTERM:-} == 24bit ]]; then
                pink=$'\033[1;38;5;213m' sky=$'\033[1;38;5;81m' gold=$'\033[1;38;5;221m'
            fi
        fi
    fi
    local hints='' answers='' entry used badge pick
    local -a review_labels=() review_positions=()
    solved=$(solved_count)
    limit=$((total-first_challenge+1))
    elapsed=$(elapsed_seconds)
    if [[ "$state_dir" != "$root" ]]; then run='Practice session'
    elif (( first_challenge >= section_starts[-2] )); then run='Puzzle run'
    elif (( first_challenge > 1 )); then run='Lesson run'; fi
    heading="$run progress"
    if (( current > total )); then heading="$run cleared!"; fi
    printf '\n%s%s Player Stats %s%s\n\n' "$pink" "$star" "$star" "$reset"
    arcade_progress "$solved" "$limit"

    for ((position=first_challenge; position<=total; position++)); do
        id=${course_order[position-1]}
        badge='' used=''
        if [[ "$reassessed" == *",$id,"* ]]; then badge='  ✓ Replayed independently'; fi
        printf -v entry '%02d  %s%s' "$position" "${lesson_titles[id]}" "$badge"
        if [[ -f "$state_dir/.hint-$id" ]]; then
            hints+="$entry"$'\n'
            used='Hint'
        fi
        if [[ -f "$state_dir/.answer-$id" ]]; then
            answers+="$entry"$'\n'
            used="${used:+$used + }Walkthrough"
        fi
        if [[ -n "$used" ]]; then
            review_labels+=("$entry  ·  $used")
            review_positions+=("$position")
        fi
        puzzle_objectives "$id"
        if (( ${#objectives[@]} == 0 )); then
            available=$((available+1))
            if is_solved "$id"; then
                if [[ -f "$state_dir/.answer-$id" && "$reassessed" != *",$id,"* ]]; then assisted=$((assisted+1))
                else independent=$((independent+1)); fi
            elif [[ "$id" == "$current" ]]; then
                printf -v next_label 'CURRENT LESSON %02d' "$position"
                next_action=${lesson_titles[id]}
            fi
            continue
        fi
        puzzles=$((puzzles+1))
        possible=$((possible+${#objectives[@]}))
        marks=''
        for index in "${!objectives[@]}"; do
            key="$id.$((index+1))"
            if [[ "$earned" == *",$key,"* ]]; then
                verified=$((verified+1))
                marks+=$'\n    '"${sky}[x]${reset} ${objectives[index]}"
            else
                marks+=$'\n    [ ] '"${objectives[index]}"
                if [[ "$id" == "$current" && -z "$next_action" ]]; then
                    printf -v next_label 'NEXT OBJECTIVE  /  PUZZLE %02d' "$position"
                    next_action=${objectives[index]}
                fi
            fi
        done
        if [[ "$id" == "$current" && -z "$next_action" ]]; then
            printf -v next_label 'PUZZLE %02d  /  ALL OBJECTIVES DEMONSTRATED' "$position"
            next_action='Use bn check, then bn submit to clear the puzzle.'
        fi
        if [[ "$id" == "$current" ]] || is_solved "$id"; then
            status=''
            if [[ "$reassessed" == *",$id,"* ]]; then status=' (independent replay)'
            elif [[ -f "$state_dir/.answer-$id" ]]; then status=' (walkthrough)'
            elif is_solved "$id"; then status=' (independent)'; fi
            if is_solved "$id" && [[ "$earned" != *",$id."* ]]; then
                marks=' — completed before objective tracking'
            fi
            printf -v checklist '%s%02d  %s%s%s\n' "$checklist" "$position" "${lesson_titles[id]}" "$status" "$marks"
        fi
    done

    if (( available )); then
        if [[ -t 1 ]]; then
            printf 'Independent guided clears    %s%d%s\nWalkthrough clears           %d\n' "$sky" "$independent" "$reset" "$assisted"
        else
            printf 'Guided lessons: %d independent, %d with walkthrough, %d available\n' "$independent" "$assisted" "$available"
        fi
    fi
    printf 'Puzzle objectives demonstrated: %s%d / %d%s\n\n' "$gold" "$verified" "$possible" "$reset"
    if (( current > total )); then
        if (( puzzles == 1 )); then next_label='PUZZLE CLEARED'
        else printf -v next_label 'ALL %d PUZZLES CLEARED' "$puzzles"; fi
        if (( verified == possible )); then next_action='Every objective demonstrated!'
        else next_action='Completed before full objective tracking.'; fi
        arrow=$star
    fi
    printf '%s%s%s\n%s%s %s%s\n\n' "$pink" "$next_label" "$reset" "$gold" "$arrow" "$next_action" "$reset"
    if [[ ${2:-} != review ]] || (( ! ${#review_labels[@]} )); then
        printf '%sHints used%s\n%s\n' "$sky" "$reset" "${hints:-None recorded.}"
        printf '%sAnswers revealed%s\n%s\n' "$gold" "$reset" "${answers:-None recorded.}"
    fi
    printf 'Elapsed: %dh %02dm %02ds\nIncorrect submissions: %d (free retries)\n' \
        "$((elapsed/3600))" "$((elapsed/60%60))" "$((elapsed%60))" "$mistakes"
    if (( score )); then printf 'Previous scoring system: %d historical points\n' "$score"; fi
    if [[ -f "$state_dir/.answer-$current" ]]; then printf 'Walkthrough opened for the active lesson.\n'; fi
    if [[ -n "$checklist" ]]; then
        if [[ "$details" == --details || ! -t 1 ]]; then printf '\nPuzzle checklist\n%s' "$checklist"
        else printf 'Puzzle checklist: bn stats --details\n'; fi
    fi
    if [[ ${2:-} == review ]]; then
        if (( ${#review_labels[@]} )); then
            menu_style=inline choose_row 'Review a lesson · Enter starts a separate practice attempt' "${review_labels[@]}" Back
            printf '\n'
            if (( pick < ${#review_positions[@]} )); then number=${review_positions[pick]}; fi
        else
            printf '\nPress Enter to return. '
            IFS= read -r || :
        fi
    fi
}

# A separate practice run can certify a walkthrough completion. It never
# advances the main run or changes its active lesson or working files.
record_independent_replay() (
    local id=$1 practice_earned=$earned
    [[ "$state_dir" != "$root" && ! -f "$state_dir/.answer-$id" ]] || return 0
    local source_id
    if [[ -f "$state_dir/.review-source" ]]; then
        read -r source_id < "$state_dir/.review-source"
        if valid_practice "$source_id"; then
            (state_dir="$root/.practice.$source_id"; credit_replay "$id" "$practice_earned")
        fi
    fi
    state_dir=$root
    credit_replay "$id" "$practice_earned"
)

credit_replay() {
    local id=$1 practice_earned=$2 key index
    load_state
    is_solved "$id" || [[ "$current" == "$id" ]] || return 0
    [[ -f "$state_dir/.answer-$id" || -f "$state_dir/.hint-$id" ]] || return 0
    [[ "$reassessed" != *",$id,"* ]] || return 0
    reassessed+="$id,"
    puzzle_objectives "$id"
    for index in "${!objectives[@]}"; do
        key="$id.$((index+1))"
        if [[ "$practice_earned" == *",$key,"* && "$earned" != *",$key,"* ]]; then earned+="$key,"; fi
    done
    save_state
    if [[ "$state_dir" == "$root" ]]; then printf 'Independent replay recorded for the main course.\n'
    else printf 'Independent replay recorded for the practice run.\n'; fi
}
