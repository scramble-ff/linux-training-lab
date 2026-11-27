
# Keep shell options, traps and exits inside the runner even if it is sourced.
if [ -n "${ZSH_VERSION:-}" ] && [ "${ZSH_EVAL_CONTEXT##*:}" = file ]; then
    bash "${(%):-%x}" "$@"
    return $?
fi
if [[ -n ${BASH_VERSION:-} && ${BASH_SOURCE[0]} != "$0" ]]; then
    bash "${BASH_SOURCE[0]}" "$@"
    return $?
fi

set -euo pipefail
launch_umask=$(umask)
umask 077

root="$HOME/.linux-training-lab"
state_dir="$root"
launch_save="$(pwd -P)/beginnix-progress.txt"
checkpoint_header=BEGINNIX-CHECKPOINT-3
previous_header_v2=BEGINNIX-CHECKPOINT-2
legacy_header=BEGINNIX-CHECKPOINT-1

menu_guide() {
    cat <<'GUIDE'
How to play

Use the Up and Down arrows to move the fish (><>) to an option. Press Enter to open it.
In submenus, Esc returns to the previous screen or cancels a confirmation.

First visit     Choose Start guided training to open lesson 1.
Return visit    Choose Continue course to open your current lesson.
In a lesson     Read the README, then type Linux commands at
                the shell prompt. Type bn current to reread the task.
Found a flag?   Type submit, press Enter, paste the whole flag and press
                Enter again. For a free hint, type bn hint.
Built something? Run bn submit to grade the files, process, or script.
Found a value?  Type submit and enter the requested finding at the prompt.
                Every lesson ends with a How to submit section.
Puzzles         Use bn check for objective feedback and bn submit to finish.
Fresh attempt   Use bn restart to preview a reset of the active lesson.
Next lesson     After a correct submission, choose Move to next challenge,
                Stay and review this challenge, or Always move to next challenge.
                If you stay, bn current shows how to reach the next lesson.
Take a break    Type menu at the lesson prompt to return to the main menu.
                Choose Exit to keep working on this machine later, or
                Save and quit to also export your main course progress.

Table of contents groups lessons by topic.
With an installed course, picking the current lesson resumes it. Picking
another opens separate practice. A [~] marks a walkthrough completion;
[x] includes independent replays. Course options includes restart,
navigation preferences and teardown. Open Player Stats to review
lessons where you used a hint or a walkthrough.
GUIDE
}

usage() {
    printf 'Beginnix — run bash lab.sh to open the main menu.\n\n'
    menu_guide
    cat <<'HELP'

At the lesson prompt
  submit                        Grade your work or prompt for the requested answer.
  bn current   (-c, --current)   Show the active lesson and its folder.
  bn hint      (-H, --hint)      Get a free hint.
  bn answer    (-a, --answer)    Open the walkthrough and mark this attempt as assisted.
  bn submit    (-s, --submit)    Grade the current task. Add the requested answer for a discovery.
  bn stats     (-S, --stats)     Open Player Stats. Add --details for the puzzle checklist.
  bn save      (-w, --save)      Export this run. Optionally give a filename.
  bn check                      Check the active work without advancing.
  bn restart                    Preview the active lesson reset and backup.
  bn move ask | always          Set the after-submission navigation preference.
  bn help      (-h, --help)      Show this guide.
  menu (or bn menu)             Return to the main menu and keep your work.

Hints, checks and retries are free. Guided lessons record independent or
walkthrough completion. Puzzles track named objectives once per skill;
all objectives must still pass together to finish. An independent practice
replay can certify a previously assisted completion in the main course.

Saving and restoring
  Save and quit writes beginnix-progress.txt in the folder where you
  launched Beginnix. Launch from that folder again and choose Load saved
  course. If a course is installed, loading archives it first.
  A checkpoint saves progress and scores. Loading regenerates the active
  lesson files. Use Exit and Continue course to keep unfinished files
  in your installed course. To export practice, use bn save in that shell.
  bn save defaults to ~/beginnix-progress.txt. Save outside the lab so
  the checkpoint survives teardown. Teardown also removes archived labs,
  practice sessions, lesson-shell history, and your navigation preference.

Command-line shortcuts
  bash lab.sh setup             Open the course menu.
  bash lab.sh setup --training  Start at the first training lesson.
  bash lab.sh setup --puzzles   Start at the first puzzle.
  bash lab.sh setup --jump N    Start at lesson number N.
  bash lab.sh setup --resume FILE   Restore into a fresh lab.
  bash lab.sh teardown          Delete the installed lab and practice.

An explicit starting lesson opens separate practice if a course exists.
In the shell, bn, beginnix and lab are interchangeable. Setup also accepts
-i or --setup. Teardown also accepts -t or --teardown. The menu asks for
confirmation before teardown under Course options. The command-line teardown acts immediately.
Set LAB_SHELL=bash or LAB_SHELL=zsh to choose the lesson shell.
HELP
}

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

installed() {
    [[ ! -L "$root" && -d "$root" && -f "$root/.linux-lab-install" &&
       ! -L "$root/.linux-lab-install" ]]
}

load_state() {
    local start_id
    ensure_course_layout
    read -r seed started current score mistakes attempts first_challenge finished start_id earned reassessed < "$state_dir/state"
    earned=${earned:-,} reassessed=${reassessed:-,}
    first_challenge=${first_challenge:-1}
    if [[ -n "$start_id" ]]; then
        first_challenge=$(challenge_position "$start_id")
    elif [[ -n "$finished" ]]; then
        first_challenge=$(challenge_position "${previous_course_order[first_challenge-1]}")
        if (( current > 30 )) || { (( current >= 27 )) && [[ ! -d "$(folder "$current")" ]]; }; then
            current=0
        fi
        adjust_start_position
        if (( current == 0 )); then current=$(next_challenge); fi
    fi
    # Older 40-lesson runs used 41 to mean complete. The new lesson
    # cannot be active in a run starting beyond its playable position.
    if (( current == 41 )) && (( first_challenge > $(challenge_position 41) )); then
        current=$(next_challenge)
    fi
}

is_solved() {
    [[ "$finished" == *",$1,"* ]]
}

solved_count() {
    local separators="${finished//[^,]/}"
    printf '%d' "$(( ${#separators} - 1 ))"
}

save_state() {
    local temporary
    temporary=$(mktemp "$state_dir/.state.XXXXXX")
    printf '%s %s %s %s %s %s %s %s %s %s %s\n' \
        "$seed" "$started" "$current" "$score" "$mistakes" "$attempts" "$first_challenge" "$finished" \
        "${course_order[first_challenge-1]}" "$earned" "$reassessed" > "$temporary"
    mv -f -- "$temporary" "$state_dir/state"
}

init_state() {
    ensure_course_layout
    seed=$(od -An -N16 -tx1 /dev/urandom)
    seed=${seed// /}
    started=$(date +%s)
    first_challenge=$1
    current=${course_order[first_challenge-1]}
    score=0 mistakes=0 attempts=0 finished=, earned=, reassessed=,
    prepare "$current"
    save_state
    touch -- "$state_dir/.expanded-search-fixtures" "$state_dir/.lesson-prompts-v31" "$state_dir/.hidden-note-v45" "$state_dir/.lesson-prompts-v52"
}

lesson_heading() {
    local color='' reset=''
    if [[ -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
        case "${2:-task}" in
            submit) color=$'\033[1;95m' ;;
            success) color=$'\033[1;92m' ;;
            milestone) color=$'\033[1;93m' ;;
            example|task) color=$'\033[1;92m' ;;
            *) color=$'\033[1;96m' ;;
        esac
        reset=$'\033[0m'
    fi
    printf '\n%s━━[ %s ]━━%s\n' "$color" "$1" "$reset"
}

display_lesson() {
    local line title position section white='' reset=''
    position=$(challenge_position "$current")
    section=$(section_index "$position")
    if [[ -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
        white=$'\033[1;97m' reset=$'\033[0m'
    fi
    {
        IFS= read -r title || return 1
        printf '\n Neon Harbor Dispatch / %s\n' "${sections[section]}"
        lesson_heading "$(printf 'Challenge %02d of %d · %s' "$position" "$total" "$title")"
        while IFS= read -r line; do
            case "$line" in
                'Your task'|'Suggested commands'|'Shell tip') lesson_heading "$line" ;;
                'Try this') lesson_heading "$line" example ;;
                'How to submit') lesson_heading "$line" submit ;;
                '  '*) printf '%s%s%s\n' "$white" "$line" "$reset" ;;
                *) printf '%s\n' "$line" ;;
            esac
        done
    } < "$1/README.txt"
}

show_current() {
    local destination
    if [[ "$state_dir" != "$root" ]]; then
        printf '\nPractice session\n'
        if (( current > total )); then
            printf 'Practice run complete. Run beginnix stats for your results.\n'
            return
        fi
    fi
    if (( current > total )); then
        printf 'All %d challenges in this run complete. Run bn stats for your results.\n' "$((total-first_challenge+1))"
        return
    fi
    destination=$(folder "$current")
    if [[ "$PWD" != "$destination" ]]; then
        printf 'To enter the challenge folder, run\n  cd %q\n\n' "$destination"
    fi
    display_lesson "$destination"
}

require_install() {
    installed || fail 'Lab installation not found. Run bash lab.sh and choose Start guided training.'
}

lock_installed() {
    require_install
    exec 9<"$root"
    flock -x 9
    require_install
}

install_runner() {
    local runner
    runner=$(mktemp "$root/bin/.beginnix.XXXXXX")
    cp -- "${BASH_SOURCE[0]}" "$runner"
    chmod u+x "$runner"
    mv -fT -- "$runner" "$root/bin/beginnix"
    ln -sfnT -- beginnix "$root/bin/lab"
    ln -sfnT -- beginnix "$root/bin/bn"
    cat > "$root/commands.sh" <<'COMMANDS'
# Read the active lesson from this run, even when reviewing an older folder.
_bn_update_prompt() {
    local state_file="${BEGINNIX_TERMINAL_DIR%/*}/state" seed started active remaining id position=0 label='Run complete'
    IFS=' ' read -r seed started active remaining < "$state_file" || return
    [[ $active != "${_bn_prompt_id:-}" ]] || return 0
    for id in "${_bn_course_ids[@]}"; do
        position=$((position + 1))
        if [[ $id == "$active" ]]; then
            printf -v label 'Challenge %02d' "$position"
            break
        fi
    done
    PS1=${_bn_prompt_template/CHALLENGE_LABEL/$label}
    _bn_prompt_id=$active
}

# This hook also handles a submission from a child sh when the learner
# returns to the lesson shell. Each open terminal has its own notification.
_bn_after_submit() {
    local previous_status=$? destination choice
    [[ ${BEGINNIX_LESSON_PID:-} == "$$" && -n ${BEGINNIX_TERMINAL_DIR:-} ]] || return "$previous_status"
    if [[ ! -d "$BEGINNIX_TERMINAL_DIR" ]]; then unset HISTFILE; exit 0; fi
    if [[ -f "$BEGINNIX_TERMINAL_DIR/menu" || -f "$BEGINNIX_TERMINAL_DIR/review" ]]; then exit 0; fi
    _bn_update_prompt
    if [[ -f "$BEGINNIX_TERMINAL_DIR/restart" ]]; then
        destination=$(< "$BEGINNIX_TERMINAL_DIR/restart")
        rm -f -- "$BEGINNIX_TERMINAL_DIR/restart" "$BEGINNIX_TERMINAL_DIR/next"
        cd -- "$destination" && command beginnix current
        return
    fi
    [[ -f "$BEGINNIX_TERMINAL_DIR/next" ]] || return "$previous_status"
    destination=$(< "$BEGINNIX_TERMINAL_DIR/next")
    rm -f -- "$BEGINNIX_TERMINAL_DIR/next" || return 1
    if [[ ! -f "$HOME/.linux-training-lab/.auto-move" ]]; then
        choice=$(command beginnix --choose-next) || return 0
        case "$choice" in
            2) printf 'Staying here. Use bn current for the next lesson.\n'; return 0 ;;
            3) touch -- "$HOME/.linux-training-lab/.auto-move" || return 1 ;;
            1) ;;
            *) return 0 ;;
        esac
    fi
    cd -- "$destination" && command beginnix current
}

menu() { command beginnix menu "$@"; }

submit() {
    local response
    if [[ $# == 0 && ! -t 0 ]] && IFS= read -r response && [[ -n "$response" ]]; then
        set -- "$response"
    fi
    command beginnix submit "$@"
}
COMMANDS
    printf '_bn_course_ids=(%s)\n' "${course_order[*]}" >> "$root/commands.sh"
    cat > "$root/.zshrc" <<'ZSHRC'
source "$ZDOTDIR/commands.sh"
precmd_functions+=(_bn_after_submit)
_bn_prompt_template='[BEGINNIX LAB] [CHALLENGE_LABEL] %~
%# '
if [[ -t 2 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
    _bn_prompt_template='%K{magenta}%F{white}%B[BEGINNIX LAB] [CHALLENGE_LABEL]%b%f%k %B%F{cyan}%~%f%b
%# '
fi
unset ZDOTDIR
ZSHRC
    cat > "$root/bashrc" <<'BASHRC'
source "$HOME/.linux-training-lab/commands.sh"
PROMPT_COMMAND+=(_bn_after_submit)
set -o emacs
_bn_prompt_template='[BEGINNIX LAB] [CHALLENGE_LABEL] \w\n\$ '
if [[ -t 2 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
    _bn_prompt_template='\[\e[1;97;45m\][BEGINNIX LAB] [CHALLENGE_LABEL]\[\e[0m\] \[\e[1;96m\]\w\[\e[0m\]\n\$ '
    alias ls='ls --color=auto'
fi
BASHRC
    printf '%s\n' "$version" > "$root/.linux-lab-install"
}

elapsed_seconds() {
    local elapsed=$(( $(date +%s) - started ))
    if (( elapsed < 0 )); then elapsed=0; fi
    printf '%d\n' "$elapsed"
}

save_checkpoint() {
    local path lab_path temporary previous_header start_id saved_current challenge revealed=, hinted=,
    path=$(realpath -m -- "${1:-$HOME/beginnix-progress.txt}")
    lab_path=$(realpath -m -- "$root")
    if [[ "$path" == "$lab_path" || "$path" == "$lab_path/"* ]]; then
        fail 'Choose a checkpoint path outside the lab directory so teardown leaves it in place.'
    fi
    if [[ -e "$path" ]]; then
        if [[ ! -f "$path" ]] || ! IFS= read -r previous_header < "$path" ||
           [[ "$previous_header" != "$checkpoint_header" && "$previous_header" != "$previous_header_v2" && "$previous_header" != "$legacy_header" ]]; then
            fail 'That path already exists. Choose a new checkpoint filename.'
        fi
    fi
    start_id=${course_order[first_challenge-1]}
    saved_current=$current
    if (( current > total )); then saved_current=0; fi
    for challenge in "${course_order[@]}"; do
        if [[ -f "$state_dir/.hint-$challenge" ]]; then hinted+="$challenge,"; fi
        if [[ -f "$state_dir/.answer-$challenge" ]]; then
            revealed+="$challenge,"
        fi
    done

    temporary=$(mktemp -- "${path%/*}/.beginnix-progress.XXXXXX")
    {
        printf '%s\n' "$checkpoint_header"
        printf '%s %s %s %s %s %s %s %s\n' \
            "$seed" "$(elapsed_seconds)" "$saved_current" "$score" "$mistakes" "$attempts" "$start_id" "$finished"
        printf '%s\n' "$revealed" "$earned" "$reassessed" "$hinted"
    } > "$temporary"
    mv -fT -- "$temporary" "$path"
    printf 'Checkpoint saved to %s\n' "$path"
}

read_checkpoint() {
    local path=$1 header elapsed start_id extra extra_line challenge position seen=,
    local number_pattern='^(0|[1-9][0-9]{0,9})$'
    local list_pattern='^,([1-9][0-9]{0,2},)*$'
    local invalid='That file is not a valid Beginnix progress checkpoint.'
    [[ -f "$path" && -r "$path" ]] || fail "Cannot read checkpoint: $path"
    earned=, reassessed=, checkpoint_hinted=,
    if ! {
        IFS= read -r header &&
        read -r seed elapsed current score mistakes attempts start_id finished extra &&
        IFS= read -r checkpoint_revealed &&
        { [[ "$header" == "$legacy_header" ]] || { IFS= read -r earned && IFS= read -r reassessed; }; } &&
        { [[ "$header" != "$checkpoint_header" ]] || IFS= read -r checkpoint_hinted; } &&
        ! IFS= read -r extra_line && [[ -z "$extra_line" ]]
    } < "$path"; then
        fail "$invalid"
    fi
    [[ ( "$header" == "$checkpoint_header" || "$header" == "$previous_header_v2" || "$header" == "$legacy_header" ) && -z "$extra" &&
       "$seed" =~ ^[0-9a-f]{32}$ && "$elapsed" =~ $number_pattern &&
       "$current" =~ $number_pattern && "$score" =~ $number_pattern &&
       "$mistakes" =~ $number_pattern && "$attempts" =~ $number_pattern &&
       "$finished" =~ $list_pattern && "$checkpoint_revealed" =~ $list_pattern && "$checkpoint_hinted" =~ $list_pattern ]] ||
        fail "$invalid"
    first_challenge=$(challenge_position "$start_id" 2>/dev/null) || fail "$invalid"

    local -a completed=() revealed=()
    IFS=, read -r -a completed <<< "${finished#,}"
    for challenge in "${completed[@]}"; do
        position=$(challenge_position "$challenge" 2>/dev/null) || fail "$invalid"
        [[ "$seen" != *",$challenge,"* ]] || fail "$invalid"
        seen+="$challenge,"
    done
    (( score <= 100 * ${#completed[@]} && attempts <= mistakes )) || fail "$invalid"
    if (( current != 0 )); then
        position=$(challenge_position "$current" 2>/dev/null) || fail "$invalid"
        ! is_solved "$current" || fail "$invalid"
    fi
    IFS=, read -r -a revealed <<< "${checkpoint_revealed#,}${checkpoint_hinted#,}"
    for challenge in "${revealed[@]}"; do
        challenge_position "$challenge" >/dev/null || fail "$invalid"
        [[ "$challenge" == "$current" ]] || is_solved "$challenge" || fail "$invalid"
    done
    local key id index
    local -a entries
    [[ "$earned" =~ ^,([1-9][0-9]?[.][1-9][0-9]?,)*$ && "$reassessed" =~ $list_pattern ]] || fail "$invalid"
    IFS=, read -r -a entries <<< "${earned#,}"
    seen=,
    for key in "${entries[@]}"; do
        id=${key%.*} index=${key#*.}
        puzzle_objectives "$id"
        (( index <= ${#objectives[@]} )) && [[ "$seen" != *",$key,"* ]] || fail "$invalid"
        [[ "$id" == "$current" ]] || is_solved "$id" || fail "$invalid"
        seen+="$key,"
    done
    IFS=, read -r -a entries <<< "${reassessed#,}"
    seen=,
    for id in "${entries[@]}"; do
        [[ "$id" == "$current" ]] || is_solved "$id" || fail "$invalid"
        [[ "$seen" != *",$id,"* ]] &&
            [[ "$checkpoint_revealed" == *",$id,"* || "$checkpoint_hinted" == *",$id,"* ]] || fail "$invalid"
        seen+="$id,"
    done
    adjust_start_position
    if (( current == 0 )); then current=$(next_challenge); fi
    started=$(( $(date +%s) - elapsed ))
}

restore_checkpoint() {
    local challenge
    local -a revealed=()
    ensure_course_layout
    if (( current <= total )); then prepare "$current"; fi
    IFS=, read -r -a revealed <<< "${checkpoint_revealed#,}"
    for challenge in "${revealed[@]}"; do
        touch -- "$state_dir/.answer-$challenge"
    done
    IFS=, read -r -a revealed <<< "${checkpoint_hinted#,}"
    for challenge in "${revealed[@]}"; do touch -- "$state_dir/.hint-$challenge"; done
    save_state
    touch -- "$state_dir/.expanded-search-fixtures" "$state_dir/.lesson-prompts-v31" "$state_dir/.hidden-note-v45" "$state_dir/.lesson-prompts-v52"
}

valid_start_position() {
    [[ "$1" =~ ^[1-9][0-9]*$ && ${#1} -le ${#total} ]] && (( $1 <= total ))
}

create_practice() {
    state_dir=$(mktemp -d "$root/.practice.XXXXXX")
    export LINUX_LAB_PRACTICE_ID="${state_dir##*.}"
    init_state "$1"
}

valid_practice() {
    [[ "$1" =~ ^[a-zA-Z0-9]{6}$ && ! -L "$root/.practice.$1" && -f "$root/.practice.$1/state" ]]
}

remember_practice() {
    local temporary
    temporary=$(mktemp -- "$root/.last-practice.XXXXXX")
    printf '%s\n' "${state_dir##*.}" > "$temporary"
    mv -fT -- "$temporary" "$root/.last-practice"
}

select_shell() {
    local login_shell="${SHELL:-bash}"
    selected_shell="${LAB_SHELL:-${login_shell##*/}}"
    case "$selected_shell" in
        bash|zsh) ;;
        *) selected_shell=bash ;;
    esac
    shell_path=$(command -v "$selected_shell") || fail "Shell unavailable: $selected_shell"
}

show_banner() {
    if [[ -t 0 && -t 1 ]] && (( cols >= 69 && rows >= 22 )); then
        banner_rows=12
        cat <<'LOGO'
 /$$$$$$$                      /$$                     /$$
| $$__  $$                    |__/                    |__/
| $$  \ $$  /$$$$$$   /$$$$$$  /$$ /$$$$$$$  /$$$$$$$  /$$ /$$   /$$
| $$$$$$$  /$$__  $$ /$$__  $$| $$| $$__  $$| $$__  $$| $$|  $$ /$$/
| $$__  $$| $$$$$$$$| $$  \ $$| $$| $$  \ $$| $$  \ $$| $$ \  $$$$/
| $$  \ $$| $$_____/| $$  | $$| $$| $$  | $$| $$  | $$| $$  >$$  $$
| $$$$$$$/|  $$$$$$$|  $$$$$$$| $$| $$  | $$| $$  | $$| $$ /$$/\  $$
|_______/  \_______/ \____  $$|__/|__/  |__/|__/  |__/|__/|__/  \__/
                     /$$  \ $$
                    |  $$$$$$/
                     \______/
                                ><>
LOGO
    else
        banner_rows=2
        printf ' BEGINNIX\n   ><>\n'
    fi
}

menu_close() {
    if (( screen )); then
        printf '\033[0m\033[?25h\033[?1049l'
        screen=0
    fi
}

choose_row() {
    local heading=$1
    shift
    local -a options=("$@")
    local key suffix size rows cols i start limit n filled empty width banner_rows
    local highlight='' reset='' label_width label row footer=' Up/Down to move   Enter to select'
    local interactive=0 cursor_menu=0 previous_size='' previous_pick=-1 previous_start=-1
    local full_draw visible offset detail_line option_text padding
    local style=${menu_style:-page} detail=${menu_detail:-} back=-1
    for i in "${!options[@]}"; do
        case "${options[i]}" in Back|Cancel|'Stay and review this challenge') back=$i ;; esac
    done
    if (( back >= 0 )); then footer+='   Esc Back'; fi
    if [[ "$style" == next ]]; then footer=' Choice [1]   ↑/↓ or 1–3   Enter to select'; fi
    if [[ -t 0 && -t 1 ]]; then
        interactive=1
        if [[ ${TERM:-dumb} != dumb ]]; then
            cursor_menu=1
            if [[ -z ${NO_COLOR:-} ]]; then highlight=$'\033[1;97;45m' reset=$'\033[0m'; fi
        fi
    fi
    pick=0
    while :; do
        rows=24 cols=80
        if (( interactive )); then
            size=$(stty size 2>/dev/null) && read -r rows cols <<< "$size"
            if (( rows < 1 || cols < 1 )); then rows=24 cols=80; fi
        fi
        full_draw=0
        if (( ! cursor_menu )) || [[ "$rows $cols" != "$previous_size" ]]; then
            full_draw=1
            previous_size="$rows $cols"
            if [[ "$style" == inline || "$style" == next ]]; then
                printf '\n %.*s\n' "$cols" "$heading"
                limit=$((rows - 5))
            else
                if (( cursor_menu )); then
                    if (( ! screen )); then printf '\033[?1049h\033[?25l'; screen=1; fi
                    printf '\033[H\033[2J'
                fi
                if [[ "$style" == home ]]; then
                    if [[ -n "$highlight" ]]; then printf '\033[1;96m'; fi
                    show_banner
                    printf '%s' "$reset"
                else printf ' BEGINNIX / Neon Harbor Dispatch\n'; banner_rows=1; fi
                width=$total
                if (( cols < 65 )); then width=12; fi
                printf -v filled '%*s' "$((completed * width / run_total))" ''
                printf -v empty '%*s' "$((width - ${#filled}))" ''
                printf ' [%s%s] %d/%d %s completed\n\n %s\n' "${filled// /#}" "${empty// /-}" "$completed" "$run_total" "$run_label" "$heading"
                limit=$((rows - banner_rows - 6))
                if [[ -n "$detail" ]]; then limit=$((limit-1)); fi
            fi
            if (( limit < 1 )); then limit=1; fi
            if (( ! interactive )); then limit=${#options[@]}; fi
        fi
        start=$((pick >= limit ? pick - limit + 1 : 0))
        visible=$((${#options[@]} - start))
        if (( visible > limit )); then visible=$limit; fi
        label_width=$((cols > 7 ? cols-7 : 1))
        for ((i=start; i<start+visible; i++)); do
            if (( ! interactive )); then
                printf ' %2d  %s\n' "$((i+1))" "${options[i]}"
                if [[ -n "$detail" ]] && (( i == 0 )); then printf '     %s\n' "$detail"; fi
                continue
            fi
            if (( ! full_draw && start == previous_start )); then
                if (( pick == previous_pick || (i != pick && i != previous_pick) )); then continue; fi
            fi
            option_text=${options[i]}
            if [[ "$style" == next ]]; then option_text="$((i+1))) $option_text"; fi
            option_text=${option_text:0:label_width}
            if (( i == pick )); then
                printf -v padding '%*s' "$((label_width-${#option_text}))" ''
                label=" ><> $option_text$padding"
                row="$highlight${label:0:cols}$reset"
            else
                label="     $option_text"
                row=${label:0:cols}
            fi
            if (( full_draw )); then
                printf '%s\n' "$row"
            else
                # The saved cursor is on the footer, one blank line below the list.
                offset=$((visible - (i-start) + 1))
                if [[ -n "$detail" ]] && (( i == start )); then offset=$((offset+1)); fi
                printf '\033[%dA\r%s\033[K\0338' "$offset" "$row"
            fi
            if [[ -n "$detail" ]] && (( i == start )); then
                detail_line=''
                if (( start == 0 )); then printf -v detail_line '     %.*s' "$label_width" "$detail"; fi
                if (( full_draw )); then printf '%s\n' "$detail_line"
                elif (( previous_start != start )); then printf '\033[%dA\r%s\033[K\0338' "$((offset-1))" "$detail_line"; fi
            fi
        done
        previous_pick=$pick previous_start=$start
        if (( ! interactive )); then
            printf ' Choice (1-%d): ' "${#options[@]}"
            IFS= read -r n || exit 0
            if [[ "$style" == next && -z "$n" ]]; then return 0; fi
            if [[ "$n" =~ ^[1-9][0-9]?$ ]] && (( n <= ${#options[@]} )); then pick=$((n-1)); return; fi
            continue
        fi
        if (( full_draw )); then
            printf '\n%.*s' "$cols" "$footer"
            if (( cursor_menu )); then printf '\0337'; fi
        fi
        IFS= read -rsn1 key || exit 0
        case "$key" in
            '') return 0 ;;
            [1-3]) if [[ "$style" == next ]]; then pick=$((key-1)); fi ;;
            $'\004') exit 0 ;;
            $'\033')
                if ! IFS= read -rsn1 -t 0.2 suffix; then
                    if (( back >= 0 )); then pick=$back; return 0; fi
                    continue
                fi
                [[ "$suffix" == '[' || "$suffix" == O ]] || continue
                IFS= read -rsn1 -t 0.3 suffix || continue
                case "$suffix" in
                    A) pick=$(((pick+${#options[@]}-1)%${#options[@]})) ;;
                    B) pick=$(((pick+1)%${#options[@]})) ;;
                esac ;;
        esac
    done
}

in_lesson_terminal() {
    [[ -t 1 && ${BEGINNIX_TERMINAL_DIR:-} == "$state_dir"/.terminal.?????? &&
       -d "$BEGINNIX_TERMINAL_DIR" && ! -L "$BEGINNIX_TERMINAL_DIR" ]]
}

notify_lesson_terminal() {
    local temporary
    temporary=$(mktemp -- "$BEGINNIX_TERMINAL_DIR/.notice.XXXXXX")
    folder "$current" > "$temporary"
    mv -fT -- "$temporary" "$BEGINNIX_TERMINAL_DIR/$1"
}

start_review_practice() {
    local position=$1 origin=$state_dir
    lock_installed || return 1
    create_practice "$position" || return 1
    if [[ "$origin" != "$root" ]]; then
        printf '%s\n' "${origin##*.}" > "$state_dir/.review-source"
    fi
    remember_practice
    exec 9<&-
}

start_shell() (
    local position BEGINNIX_TERMINAL_DIR=''
    export PATH="$root/bin:$PATH" HISTFILE="$root/.lesson-history-$selected_shell"
    while :; do
        run_lesson_shell || :
        [[ -n ${BEGINNIX_TERMINAL_DIR:-} && -f "$BEGINNIX_TERMINAL_DIR/review" ]] || break
        read -r position < "$BEGINNIX_TERMINAL_DIR/review"
        valid_start_position "$position" || return 1
        rm -rf -- "$BEGINNIX_TERMINAL_DIR"
        start_review_practice "$position" || return 1
    done
)

run_lesson_shell() {
    if (( current <= total )); then
        cd -- "$(folder "$current")" || return 1
    fi
    if [[ -t 0 && -t 1 ]]; then
        printf '\033[2J\033[H'
        if [[ "$state_dir" != "$root" ]]; then printf 'Practice session\n\n'; fi
    fi
    display_lesson "$PWD" || return 1
    printf '\nbn hint for help, bn check to review work, menu to return to the main menu.\n'
    BEGINNIX_TERMINAL_DIR=$(mktemp -d -- "$state_dir/.terminal.XXXXXX") || return 1
    export BEGINNIX_TERMINAL_DIR
    trap 'rm -rf -- "$BEGINNIX_TERMINAL_DIR"' EXIT
    # Bind prompt actions to this particular interactive shell.
    (
        export BEGINNIX_LESSON_PID=$BASHPID
        if [[ "$selected_shell" == bash ]]; then
            exec "$shell_path" --noprofile --rcfile "$root/bashrc" -i
        else
            export ZDOTDIR="$root"
            exec "$shell_path" -d -i
        fi
    )
}

setup_install() {
    if [[ -n "$checkpoint_file" ]]; then
        if installed; then
            fail 'Restore checkpoints into a fresh lab. Save existing progress before teardown if you want to keep it.'
        fi
        read_checkpoint "$checkpoint_file"
    fi
    new_install=0
    if mkdir -- "$root" 2>/dev/null; then
        new_install=1
    else
        installed || fail "Cannot use $root. Setup requires an unused path or an existing lab installation."
    fi
    exec 9<"$root"
    flock -x 9
    if (( new_install )); then
        trap 'rm -rf -- "$root"' EXIT
        mkdir "$root/bin"
        if [[ -n "$checkpoint_file" ]]; then
            restore_checkpoint
        else
            init_state "$start_position"
        fi
        install_runner
        trap - EXIT
    else
        require_install
        [[ -z "$checkpoint_file" ]] || fail 'A lab is already installed. Restore into a fresh lab.'
        installed_version=$(< "$root/.linux-lab-install")
        if [[ "$installed_version" != "$version" ]]; then
            update_challenges "$installed_version"
            install_runner
        fi
    fi
    load_state
    prepare_active_lesson_if_missing
    refresh_search_fixtures
    refresh_lesson_prompts
    unset LINUX_LAB_PRACTICE_ID
}

import_course() (
    local staged archive='' original=$root
    if ! installed && [[ -e "$original" || -L "$original" ]]; then
        fail "Cannot restore into an unrecognized lab directory: $original"
    fi
    staged=$(mktemp -d -- "$HOME/.beginnix-restore.XXXXXX")
    # Keep the old installation recoverable even if the swap is interrupted.
    trap 'if [[ -n "$archive" && -d "$archive/lab" ]]; then
              if [[ ! -e "$original" ]]; then mv -T -- "$archive/lab" "$original"; fi
          fi
          if [[ -z "$archive" || ! -e "$archive/lab" ]]; then rm -rf -- "$staged"; fi' EXIT
    (
        root="$staged/lab" state_dir="$staged/lab"
        checkpoint_file=$launch_save
        setup_install
    )
    if installed; then
        lock_installed
        archive=$(mktemp -d -- "$staged/lab/.previous.XXXXXX")
        mv -T -- "$original" "$archive/lab"
    fi
    mv -T -- "$staged/lab" "$original"
    if [[ -n "$archive" ]]; then printf 'Previous course kept in %s/%s/lab\n' "$original" "${archive##*/}"; fi
)

teardown_lab() {
    local archive
    if [[ -e "$root" || -L "$root" ]]; then
        lock_installed
        rm -rf -- "$root"
        exec 9<&-
    fi
    # Older releases kept restore backups beside the lab. Remove only their
    # identified lab subtree and leave any unrelated sibling files alone.
    for archive in "$HOME"/.beginnix-previous.??????; do
        [[ -d "$archive" && ! -L "$archive" ]] || continue
        (root="$archive/lab"; installed) || continue
        rm -rf -- "$archive/lab"
        rmdir --ignore-fail-on-non-empty -- "$archive"
    done
    printf 'Lab removed. Exported checkpoints are kept.\n'
}

choose_lesson() {
    local section pos id mark end count size
    local -a labels section_labels
    for section in "${!sections[@]}"; do
        count=0 mark=''
        end=${section_starts[section+1]}
        size=$((end-section_starts[section]))
        for ((pos=section_starts[section]; pos<end; pos++)); do
            id=${course_order[pos-1]}
            if is_solved "$id"; then count=$((count+1)); fi
            if [[ "$id" == "$current" ]]; then mark='  ><> Current'; fi
        done
        if (( count == size )); then mark='  ✓ Complete'; fi
        printf -v 'section_labels[section]' '(%02d–%02d) %s  %d/%d%s' "${section_starts[section]}" \
            "$((end-1))" "${sections[section]}" "$count" "$size" "$mark"
    done
    number=0
    while :; do
        choose_row 'Table of contents — choose a section' "${section_labels[@]}" 'Back'
        section=$pick
        (( section < ${#sections[@]} )) || return 0
        end=${section_starts[section+1]}
        labels=()
        for ((pos=section_starts[section]; pos<end; pos++)); do
            id=${course_order[pos-1]}
            mark=' '
            if is_solved "$id"; then
                mark=x
                if [[ -f "$state_dir/.answer-$id" && "$reassessed" != *",$id,"* ]]; then mark='~'; fi
            fi
            labels+=("$(printf '[%s] %02d  %s' "$mark" "$pos" "${lesson_titles[id]}")")
        done
        choose_row "${section_labels[section]}" "${labels[@]}" 'Back'
        if (( pick < ${#labels[@]} )); then number=$((section_starts[section]+pick)); return; fi
    done
}

lab_menu() {
    local run_total=$total run_label=lessons
    local enter_first=$1 practice_dir='' screen=0 pick number completed=0
    local choice notice='' mode home_detail
    local -a options
    local -A practices=()
    if [[ "$state_dir" != "$root" ]]; then
        practice_dir=$state_dir
        practices[$first_challenge]=$state_dir
    fi
    exec 9<&-
    trap 'menu_close' EXIT
    trap 'menu_close; exit 130' INT
    trap 'menu_close; exit 143' TERM HUP
    while :; do
        if (( enter_first )) && installed; then
            menu_close
            lock_installed
            load_state
            prepare_active_lesson_if_missing
            refresh_lesson_prompts
            if [[ "$state_dir" != "$root" ]]; then remember_practice; fi
            exec 9<&-
            if (( current <= total )); then
                start_shell || :
                installed || break
            else notice='All lessons in this run are complete.'; fi
        fi
        enter_first=0
        state_dir=$root
        unset LINUX_LAB_PRACTICE_ID
        options=() home_detail=''
        completed=0 finished=, current=0 run_total=$total run_label=lessons
        if installed; then
            lock_installed
            load_state
            practice_dir=''
            if [[ -f "$root/.last-practice" ]]; then
                local last_id
                last_id=$(< "$root/.last-practice")
                if valid_practice "$last_id"; then practice_dir="$root/.practice.$last_id"; fi
            fi
            exec 9<&-
            completed=$(solved_count)
            run_total=$((total-first_challenge+1))
            if (( first_challenge >= section_starts[-2] )); then run_label=puzzles; fi
            if (( current <= total )); then
                options+=('Continue course')
                printf -v home_detail 'Challenge %02d · %s' "$(challenge_position "$current")" "${lesson_titles[current]}"
            fi
        else
            practice_dir=''
            practices=()
            options+=('Start guided training')
        fi
        options+=('Table of contents')
        if installed; then
            options+=('Player Stats' 'Practice a challenge')
            if [[ -n "$practice_dir" ]]; then options+=('Resume last practice'); fi
        else options+=('More starting options'); fi
        if [[ -f "$launch_save" ]]; then options+=('Load saved course'); fi
        if installed; then options+=('Course options' 'Save and quit'); fi
        options+=('How to play' 'Exit')
        menu_style=home menu_detail="$home_detail" choose_row "Main menu${notice:+ — $notice}" "${options[@]}"
        notice=''
        choice=${options[pick]}
        if [[ "$choice" == 'Course options' ]]; then
            options=()
            if (( current <= total )); then options+=('Restart main course lesson'); fi
            if [[ -f "$root/.auto-move" ]]; then options+=('Navigation — Always move to next challenge')
            else options+=('Navigation — Ask after submission'); fi
            options+=('Teardown' 'Back')
            choose_row 'Course options' "${options[@]}"
            choice=${options[pick]}
        fi
        case "$choice" in
            Back) continue ;;
            'Player Stats')
                menu_close
                number=0
                lock_installed
                load_state
                exec 9<&-
                show_stats '' review
                if (( number )); then
                    start_review_practice "$number"
                    enter_first=1
                fi ;;
            'Restart main course lesson')
                choose_row "Restart ${lesson_titles[current]}? Keep your files in previous-attempts and retain progress." 'Cancel' 'Keep attempt and restart'
                if (( pick == 1 )); then
                    if notice=$("$root/bin/beginnix" restart --confirm "$(challenge_position "$current")" 2>&1); then enter_first=1; notice=''; fi
                fi ;;
            Exit) break ;;
            'Navigation — '*)
                choose_row 'After a successful submission' 'Ask again' 'Always move to next challenge' 'Back'
                if (( pick == 0 )); then bash "${BASH_SOURCE[0]}" move ask
                elif (( pick == 1 )); then bash "${BASH_SOURCE[0]}" move always; fi ;;
            'How to play')
                menu_close
                menu_guide
                printf '\nPress Enter to return to the main menu. '
                IFS= read -r || break
                ;;
            'Save and quit')
                if notice=$("$root/bin/beginnix" save "$launch_save" 2>&1); then
                    menu_close
                    printf '%s\n' "$notice"
                    break
                fi ;;
            'Load saved course')
                if installed; then
                    choose_row 'Load checkpoint and archive the current lab?' 'Cancel' 'Load saved course'
                    (( pick == 1 )) || continue
                fi
                if notice=$(bash "${BASH_SOURCE[0]}" --import-launch-save 2>&1); then
                    practice_dir=''
                    practices=()
                    enter_first=1
                    if [[ -n "$notice" ]]; then menu_close; printf '%s\n' "$notice"; fi
                    notice=''
                fi ;;
            Teardown)
                choose_row 'Delete the lab, practice sessions and archived labs? Exported checkpoints are kept.' 'Cancel' 'Delete lab'
                if (( pick == 1 )); then
                    teardown_lab
                    break
                fi
                ;;
            'Continue course'*) enter_first=1 ;;
            'Resume last practice')
                state_dir=$practice_dir
                export LINUX_LAB_PRACTICE_ID="${state_dir##*.}"
                enter_first=1 ;;
            'Start guided training'|'More starting options'|'Practice a challenge'|'Table of contents')
                checkpoint_file=''
                if [[ "$choice" == 'Start guided training' ]]; then number=1
                elif [[ "$choice" == 'More starting options' ]]; then
                    options=('Guided training' 'Puzzles' 'Choose a lesson')
                    mode='Choose a starting point'
                    options+=('Restore checkpoint')
                    choose_row "$mode" "${options[@]}" 'Back'
                    (( pick < ${#options[@]} )) || continue
                    case "${options[pick]}" in
                        'Guided training') number=1 ;;
                        Puzzles) number=$(challenge_position "$puzzle_start_id") ;;
                        'Choose a lesson') choose_lesson ;;
                        'Restore checkpoint')
                            menu_close
                            read -r -p 'Checkpoint path [~/beginnix-progress.txt]: ' checkpoint_file || break
                            checkpoint_file=${checkpoint_file:-$HOME/beginnix-progress.txt}
                            if [[ "$checkpoint_file" == '~/'* ]]; then checkpoint_file="$HOME/${checkpoint_file:2}"; fi
                            if ! notice=$( (read_checkpoint "$checkpoint_file") 2>&1 ); then continue; fi
                            number=1 ;;
                    esac
                else
                    choose_lesson
                fi
                (( number )) || continue
                if ! installed; then
                    start_position=$number
                    menu_close
                    setup_install
                    trap 'menu_close' EXIT
                    exec 9<&-
                elif [[ "$choice" == 'Table of contents' && ${course_order[number-1]} == "$current" ]]; then
                    :
                else
                    lock_installed
                    if [[ -z ${practices[$number]:-} ]] ||
                        (state_dir=${practices[$number]}; load_state; is_solved "${course_order[number-1]}"); then
                        create_practice "$number"
                        practices[$number]=$state_dir
                    fi
                    exec 9<&-
                    practice_dir=${practices[$number]}
                    state_dir=$practice_dir
                    export LINUX_LAB_PRACTICE_ID="${state_dir##*.}"
                fi
                enter_first=1 ;;
        esac
    done
    menu_close
    trap - EXIT INT TERM HUP
}

show_completion() {
    local id=$1 position section member objective
    position=$(challenge_position "$id")
    section=$(section_index "$position")
    lesson_heading "$(printf '✓ Challenge %02d complete · %s' "$position" "${lesson_titles[id]}")" success
    if [[ -f "$state_dir/.answer-$id" ]]; then printf 'Completed with walkthrough. '
    else printf 'Completed independently. '; fi
    printf 'Progress saved.\n'
    if (( ${#objectives[@]} )); then
        for objective in "${objectives[@]}"; do printf '  ✓ %s\n' "$objective"; done
    else
        printf '  ✓ %s\n' "${guided_receipts[id]}"
    fi
    lesson_heading 'What you practiced'
    lesson_text "$id" debrief
    for ((member=section_starts[section]; member<section_starts[section+1]; member++)); do
        is_solved "${course_order[member-1]}" || return 0
    done
    lesson_heading "Section complete · ${sections[section]}" milestone
    printf 'You can now %s\n' "${section_skills[section],}"
}

show_hint() {
    if (( current > total )); then
        printf 'All challenges are complete.\n'
    else
        touch -- "$state_dir/.hint-$current"
        lesson_text "$current" hint
    fi
}

show_answer() {
    printf 'Walkthrough opened. This completion will be recorded as assisted.\n'
    printf '\nStart in the challenge folder\n  cd %q\n\n' "$(folder "$current")"
    lesson_text "$current" answer
    local prompt
    prompt=$(answer_prompt "$current")
    case "$prompt" in
        'Paste flag') printf "\nSubmit the recovered flag with bn submit '%s'\n" "$(flag "$current")" ;;
        '') printf '\nUse bn check to review your work, then bn submit to finish.\n' ;;
        *) printf '\nSubmit the finding with bn submit %s\n' "$(finding_answer "$current")" ;;
    esac
}

main() {
    if (( $# == 0 )) && [[ ! -t 0 || ! -t 1 ]]; then usage; return; fi
    case "${1:-setup}" in
        menu)
            [[ $# == 1 ]] || fail 'Usage: bn menu'
            if [[ -n ${LINUX_LAB_PRACTICE_ID:-} ]] && valid_practice "$LINUX_LAB_PRACTICE_ID"; then
                state_dir="$root/.practice.$LINUX_LAB_PRACTICE_ID"
            fi
            if in_lesson_terminal; then
                touch -- "$BEGINNIX_TERMINAL_DIR/menu"
                return
            fi
            set -- setup
            action=setup ;;
        --choose-next)
            local pick
            menu_style=next choose_row 'Next challenge' 'Move to next challenge' 'Stay and review this challenge' 'Always move to next challenge' >&2
            printf '\n' >&2
            printf '%d\n' "$((pick+1))"
            return ;;
        --import-launch-save) import_course; return ;;
        help|-h|--help) action=help ;;
        setup|-i|--setup) action=setup ;;
        teardown|-t|--teardown) action=teardown ;;
        current|-c|--current) action=current ;;
        hint|-H|--hint) action=hint ;;
        answer|-a|--answer) action=answer ;;
        submit|-s|--submit) action=submit ;;
        stats|-S|--stats) action=stats ;;
        check|restart|move) action=$1 ;;
        save|-w|--save) action=save ;;
        *) usage >&2; exit 1 ;;
    esac

    case "$action" in
        help)
            usage
            ;;
        setup)
            start_position=1 checkpoint_file='' explicit_start=0
            case "${2:-}" in
                '') [[ $# -le 1 ]] || fail 'Usage: beginnix setup [OPTION]' ;;
                -h|--help) usage; exit 0 ;;
                --training|--puzzles)
                    [[ $# -eq 2 ]] || fail 'Choose one setup option.'
                    explicit_start=1
                    if [[ "$2" == --puzzles ]]; then start_position=$(challenge_position "$puzzle_start_id"); fi
                    ;;
                --jump)
                    [[ $# -eq 3 ]] && valid_start_position "$3" ||
                        fail "Choose a challenge number from 1 to $total."
                    explicit_start=1
                    start_position=$3
                    ;;
                --resume)
                    [[ $# -eq 3 && -n "$3" ]] || fail 'Usage: beginnix setup --resume FILE'
                    checkpoint_file=$3
                    ;;
                *) fail 'Unknown setup option. Run beginnix setup --help for choices.' ;;
            esac
            select_shell
            for dependency in flock sha256sum od; do
                command -v "$dependency" >/dev/null || fail "Required command unavailable: $dependency"
            done
            if installed || (( explicit_start )) || [[ -n "$checkpoint_file" || ! -t 0 ]]; then
                setup_install
            fi
            if (( explicit_start && ! new_install )); then
                create_practice "$start_position"
            fi
            lab_menu "$explicit_start"
            # A terminal can run the launcher itself as its session leader.
            # In that case there is no previous shell to receive control.
            if [[ -t 0 && -t 1 ]] && (( $$ == $(ps -o sid= -p "$$") )); then
                local login_shell=${SHELL:-/bin/bash}
                [[ -x "$login_shell" && -f "$login_shell" ]] || login_shell=/bin/bash
                umask "$launch_umask"
                unset LINUX_LAB_PRACTICE_ID
                if [[ ! -d "$PWD" ]]; then cd -- "$HOME"; fi
                exec "$login_shell" -i
            fi
            ;;
        teardown|current|hint|answer|stats|submit|save|check|restart|move)
            if [[ "$action" == teardown ]]; then
                teardown_lab
                return
            fi
            lock_installed
            if [[ -n "${LINUX_LAB_PRACTICE_ID:-}" ]]; then
                valid_practice "$LINUX_LAB_PRACTICE_ID" || fail 'Practice session not found.'
                state_dir="$root/.practice.$LINUX_LAB_PRACTICE_ID"
            fi
            load_state
            migrate_course_order
            if [[ "$action" != save && "$action" != stats && "$action" != move && "$action" != restart ]]; then
                prepare_active_lesson_if_missing
                refresh_search_fixtures
                refresh_lesson_prompts
            fi
            case "$action" in
                current) show_current ;;
                hint) show_hint ;;
                answer)
                    [[ $# -eq 1 ]] || fail 'Usage: beginnix answer'
                    (( current <= total )) || fail 'All challenges are already complete.'
                    touch -- "$state_dir/.answer-$current"
                    show_answer
                    ;;
                stats)
                    [[ $# == 1 || ( $# == 2 && "$2" == --details ) ]] || fail 'Usage: bn stats [--details]'
                    if [[ -t 0 ]] && in_lesson_terminal; then
                        local number=0
                        exec 9<&-
                        show_stats "${2:-}" review
                        if (( number )); then
                            local request
                            request=$(mktemp -- "$BEGINNIX_TERMINAL_DIR/.review.XXXXXX")
                            printf '%d\n' "$number" > "$request"
                            mv -fT -- "$request" "$BEGINNIX_TERMINAL_DIR/review"
                        fi
                    else show_stats "${2:-}"; fi ;;
                move)
                    [[ $# == 2 ]] || fail 'Usage: bn move ask | always'
                    case "$2" in
                        ask) rm -f -- "$root/.auto-move" ;;
                        always) touch -- "$root/.auto-move" ;;
                        *) fail 'Usage: bn move ask | always' ;;
                    esac
                    printf 'After submission: %s\n' "$2" ;;
                restart)
                    (( current <= total )) || fail 'This run is complete. Choose a lesson for practice.'
                    [[ $# == 1 || ( $# -le 3 && "$2" == --confirm ) ]] || fail 'Usage: bn restart [--confirm [lesson]]'
                    if [[ $# == 3 && "$3" != "$(challenge_position "$current")" ]]; then
                        fail 'The active lesson changed. Run bn restart to preview the current lesson.'
                    fi
                    restart_lesson "${2:-}" ;;
                check)
                    [[ $# == 1 ]] || fail 'Usage: bn check'
                    (( current <= total )) || fail 'All challenges in this run are complete.'
                    puzzle_objectives "$current"
                    if (( ${#objectives[@]} )); then
                        grade_puzzle || return 1
                        printf 'Ready. Use bn submit to finish.\n'
                    else
                        case "$current" in
                            1|2|3|4|5|6|16) submission_instructions "$current" ;;
                            *)
                                check_practice "$current"
                                printf 'Work checks passed.\n'
                                submission_instructions "$current" ;;
                        esac
                    fi ;;
                save)
                    [[ $# -le 2 ]] || fail 'Usage: beginnix save [FILE]'
                    save_checkpoint "${2:-}"
                    ;;
                submit)
                    puzzle_objectives "$current"
                    (( current <= total )) || fail 'All challenges are already complete.'
                    local prompt answer expected
                    prompt=$(answer_prompt "$current")
                    shift
                    if [[ $# == 1 && "$1" == --prompt ]]; then shift; fi
                    if (( $# == 0 )) && [[ -n "$prompt" ]]; then
                        exec 9<&-
                        if [[ -t 0 ]]; then printf '%s (Enter to cancel): ' "$prompt" >&2; fi
                        IFS= read -r answer || return 1
                        [[ -n "$answer" ]] || return 0
                        exec bash "${BASH_SOURCE[0]}" submit "$answer"
                    fi
                    answer="$*"
                    if [[ "$answer" == FLAG\{* ]]; then
                        # Older installs supplied a flag even for graded work.
                        expected=$(flag "$current")
                        if [[ "$answer" != "$expected" ]]; then
                            for previous in "${course_order[@]}"; do
                                if is_solved "$previous" && [[ "$answer" == "$(flag "$previous")" ]]; then
                                    fail 'That flag was already accepted.'
                                fi
                            done
                        fi
                    elif [[ "$prompt" == 'Paste flag' ]]; then
                        expected=$(flag "$current")
                    elif [[ -n "$prompt" ]]; then
                        expected=$(finding_answer "$current")
                    else
                        (( $# == 0 )) || fail 'For this task, run bn submit with no arguments.'
                        expected=''
                    fi
                    if [[ "$answer" != "$expected" ]]; then
                        mistakes=$(( mistakes + 1 ))
                        attempts=$(( attempts + 1 ))
                        save_state
                        fail 'Incorrect answer. Try again or use bn hint. Retries are free.'
                    fi
                    if (( ${#objectives[@]} )); then grade_puzzle submit || return 1
                    elif [[ "$current" != 16 || "$answer" == FLAG\{* ]]; then check_practice "$current"; fi
                    solved=$current
                    finished+="$solved,"
                    current=$(next_challenge)
                    attempts=0
                    save_state
                    show_completion "$solved"
                    record_independent_replay "$solved"
                    prepare_active_lesson_if_missing
                    if (( current > total )); then
                        show_current
                        printf '\nType menu to return to the main menu.\n'
                    elif in_lesson_terminal; then
                        printf '\nUp next · %02d  %s\n' "$(challenge_position "$current")" "${lesson_titles[current]}"
                        notify_lesson_terminal next
                    else
                        show_current
                    fi
                    ;;
            esac
            ;;
        *) usage >&2; exit 1 ;;
    esac
}
