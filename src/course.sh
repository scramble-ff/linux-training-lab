previous_course_order=(1 2 6 19 20 21 22 23 24 25 26 3 4 18 7 8 9 10 12 11 13 14 15 16 17 5 27 28 29 30)
course_order=(1 2 6 19 20 21 22 23 24 31 25 26 3 4 18 7 8 9 10 12 11 13 14 15 16 17 5 32 33 34 35 36 27 29 30 28 37 38 39 40)
total=${#course_order[@]}
version=38
puzzle_start_id=27
lesson_titles=(
    [1]='Find your bearings'
    [2]='Find the hidden note'
    [3]='Follow the ticket'
    [4]='Open the shipment'
    [5]='Reconcile the scans'
    [6]='Read the docs'
    [7]='Unlock the note'
    [8]='Two ways to link'
    [9]='Edit the shift notes'
    [10]='Switch shells'
    [11]='Fingerprint a key'
    [12]='Find your own process'
    [13]='Read the system label'
    [14]='Weigh the parcels'
    [15]='Find the loopback'
    [16]='See what'"'"'s listening'
    [17]='Find the latest dispatch warning'
    [18]='Identify the mystery parcel'
    [19]='Set up the staging area'
    [20]='Copy and rename a manifest'
    [21]='Clear the scratch space'
    [22]='Select the route sheets'
    [23]='Write and append a report'
    [24]='Separate output and errors'
    [25]='Compare the manifests'
    [26]='Find repeated scans'
    [27]='Rebuild the dispatch packet'
    [28]='Audit the unresolved holds'
    [29]='Reconcile the intake'
    [30]='Recover the verified handoff'
    [31]='Print the dispatch labels'
    [32]='Pass arguments to a script'
    [33]='Make a dispatch decision'
    [34]='Loop over the queue'
    [35]='Read from a pipeline'
    [36]='Remember the last status'
    [37]='Build the dispatch timeline'
    [38]='Apply the approved access'
    [39]='Audit the overnight permission changes'
    [40]='The shipment that will not import'
)
sections=('Navigation and file basics' 'Shell output and text processing' 'Searching and inspecting files' 'Permissions, links and shell tools' 'System and network inspection' 'Scan analysis and shell scripting' 'Dispatch puzzles')
section_starts=(1 8 13 16 22 27 33 41)

challenge_position() {
    local position
    for (( position=1; position<=total; position++ )); do
        if [[ "${course_order[position-1]}" == "$1" ]]; then
            printf '%d' "$position"
            return
        fi
    done
    fail "Unknown challenge ID: $1"
}

folder() {
    local previous index
    local -a layout
    printf -v previous '%s/challenges/%02d' "$state_dir" "$1"
    if [[ -d "$previous" ]]; then
        printf '%s' "$previous"
        return
    fi
    read -r -a layout < "$state_dir/.course-layout"
    for index in "${!layout[@]}"; do
        if [[ "${layout[index]}" == "$1" ]]; then
            printf '%s/lessons/%02d' "$state_dir" "$(( index + 1 ))"
            return
        fi
    done
    printf '%s' "$previous"
}

ensure_course_layout() {
    [[ -f "$state_dir/.course-layout" ]] && return 0
    local -a layout=("${course_order[@]}")
    if [[ -d "$state_dir/lessons" ]]; then layout=("${previous_course_order[@]}"); fi
    (IFS=' '; printf '%s\n' "${layout[*]}") > "$state_dir/.course-layout"
}

adjust_start_position() {
    local id position
    for id in "${course_order[@]}"; do
        if [[ "$id" == "$current" ]] || is_solved "$id"; then
            position=$(challenge_position "$id")
            if (( position < first_challenge )); then first_challenge=$position; fi
        fi
    done
}

next_challenge() {
    local position candidate
    for (( position=first_challenge; position<=total; position++ )); do
        candidate=${course_order[position-1]}
        if ! is_solved "$candidate"; then
            printf '%d' "$candidate"
            return
        fi
    done
    printf '%d' "$(( total + 1 ))"
}

migrate_course_order() {
    [[ -z "$finished" ]] || return 0
    local previous
    finished=,
    for (( previous=first_challenge; previous<current; previous++ )); do
        finished+="$previous,"
    done
    first_challenge=1
    if (( current > 18 )) || [[ ! -f "$(folder "$current")/README.txt" ]]; then
        current=$(next_challenge)
        attempts=0
        if (( current <= total )); then prepare "$current"; fi
    fi
    save_state
}

prepare_active_lesson_if_missing() (
    (( current <= total )) || return 0
    local destination staging
    destination=$(folder "$current")
    [[ -d "$destination" ]] && return 0
    mkdir -p -- "${destination%/*}"
    staging=$(mktemp -d -- "${destination%/*}/.prepare.XXXXXX")
    trap 'if (( $? != 0 )); then
              printf "Lesson setup failed. After fixing the error, use bn current or reopen the course to retry.\n" >&2
          fi
          rm -rf -- "$staging"' EXIT
    prepare "$current" "$staging"
    mv -T -- "$staging" "$destination"
)

refresh_search_fixtures() {
    local marker="$state_dir/.expanded-search-fixtures" challenge destination
    [[ -e "$marker" ]] && return 0
    for challenge in 2 3 9 14 17 18 22 25 26; do
        destination=$(folder "$challenge")
        [[ -f "$destination/README.txt" ]] || continue
        case "$challenge" in
            17) write_recent_dispatch "$destination" ;;
            *) expand_search_fixture "$challenge" "$destination" ;;
        esac
        case "$challenge" in
            2|14|17|22) write_intro "$challenge" "$destination" ;;
        esac
    done
    touch -- "$marker"
}

refresh_lesson_prompts() {
    local marker="$state_dir/.lesson-prompts-v31" challenge destination
    [[ -e "$marker" ]] && return 0
    for challenge in 2 6 16 27 28 29 30 32 33 35 36 37 38; do
        destination=$(folder "$challenge")
        [[ -f "$destination/README.txt" ]] || continue
        case "$challenge" in
            6) if [[ ! -e "$destination/dispatch.log" ]]; then write_observation_fixture 6 "$destination"; fi ;;
            16) if [[ ! -e "$destination/sockets.txt" ]]; then write_observation_fixture 16 "$destination"; fi ;;
        esac
        write_intro "$challenge" "$destination"
    done
    touch -- "$marker"
}

restart_lesson() (
    local destination archive fresh
    destination=$(folder "$current")
    printf 'Restart lesson %02d — %s\n  %s\n' "$(challenge_position "$current")" "${lesson_titles[current]}" "$destination"
    if [[ -z "$1" ]]; then
        printf 'Regenerates this folder and keeps its current contents under previous-attempts.\n'
        printf 'Course progress, demonstrated objectives and walkthrough history are kept.\nRun bn restart --confirm %d to continue.\n' "$(challenge_position "$current")"
        return
    fi
    [[ ! -L "$state_dir/previous-attempts" && ! -L "${destination%/*}" ]] ||
        fail 'Restart needs lesson and backup directories inside the lab.'
    mkdir -p -- "$state_dir/previous-attempts" "${destination%/*}"
    archive=$(mktemp -d -- "$state_dir/previous-attempts/${destination##*/}.XXXXXX")
    fresh="$archive/fresh"
    # On a failed swap the previous attempt is restored, or retained at its printed path.
    trap 'if [[ -d "$archive/attempt" && ! -e "$destination" ]]; then mv -T -- "$archive/attempt" "$destination"; fi
          rm -rf -- "$fresh"
          rmdir --ignore-fail-on-non-empty -- "$archive"' EXIT
    mkdir -- "$fresh"
    prepare "$current" "$fresh"
    if [[ -e "$destination" ]]; then
        printf 'Previous attempt: %s/attempt\n' "$archive"
        mv -T -- "$destination" "$archive/attempt"
    fi
    mv -T -- "$fresh" "$destination"
    if in_lesson_terminal; then notify_lesson_terminal restart
    else printf 'Enter the fresh folder with cd %q\n' "$destination"; fi
)

update_challenges() {
    local previous_version=$1 challenge destination
    load_state
    case "$previous_version" in
        ''|2)
            if (( current == 4 )); then
                prepare 4
            fi
            for (( challenge=1; challenge<=3 && challenge<=current; challenge++ )); do
                destination=$(folder "$challenge")
                mkdir -p "$destination"
                write_intro "$challenge" "$destination"
            done
            if [[ -z "$previous_version" ]] && (( current >= 3 )); then
                write_log_challenge "$(folder 3)"
            fi
            ;;
        3)
            if (( current >= 6 )); then
                write_intro 6 "$(folder 6)"
            fi
            ;;
    esac
    if [[ "$previous_version" == 11 ]]; then
        if (( current >= 17 )); then
            prepare 17
        fi
        if (( current >= 18 )); then
            write_intro 18 "$(folder 18)"
        fi
    fi
    migrate_course_order
}
