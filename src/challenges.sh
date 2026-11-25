ready_parcels=12
latest_dispatch_warning=TICKET-2165
route_samples=64

write_intro() {
    lesson_text "$1" intro > "$2/README.txt"
}

expand_search_fixture() {
    local destination=$2
    case "$1" in
        2) add_hidden_note_samples "$destination" ;;
        3) add_ticket_search_samples "$destination" ;;
        9) add_bay_search_samples "$destination" ;;
        14) add_storage_samples "$destination" ;;
        18) add_mystery_samples "$destination" ;;
        22) add_route_samples "$destination" ;;
        25) write_manifest_comparison "$destination" ;;
        26) write_repeat_scans "$destination" ;;
    esac
}

prepare() {
    local id=$1 destination=${2:-$(folder "$1")} variant=0
    case "$id" in
        27|28|29|30|37|38|39|40)
            mkdir -p -- "$destination"
            variant=$(puzzle_variant)
            touch -- "$destination/.seeded-puzzle" ;;
    esac
    case "$id" in
        1)
            mkdir -p "$destination/supplies"
            printf '%s\n' "$(flag 1)" > "$destination/supplies/note.txt"
            ;;
        2)
            mkdir -p "$destination/.dispatch"
            printf '%s\n' "$(flag 2)" > "$destination/.dispatch/morning-dispatch-for-the-training-crew.txt"
            ;;
        3) write_log_challenge "$destination" ;;
        4) write_archive_challenge "$destination" ;;
        5) write_scan_challenge "$destination" ;;
        6|16) write_observation_fixture "$id" "$destination" ;;
        7)
            mkdir -p "$destination"
            printf '%s\n' "$(flag 7)" > "$destination/delivery-note.txt"
            chmod 200 "$destination/delivery-note.txt"
            ;;
        8)
            mkdir -p "$destination"
            printf '%s\n' "$(flag 8)" > "$destination/source.txt"
            ;;
        9) write_shift_notes "$destination" ;;
        14)
            write_dispatch_card "$id" "$destination"
            write_parcels "$destination"
            ;;
        17) write_recent_dispatch "$destination" ;;
        18) write_mystery_parcels "$destination" ;;
        20)
            write_dispatch_card "$id" "$destination"
            printf 'Morning manifest\n' > "$destination/manifest.txt"
            printf 'Afternoon manifest\n' > "$destination/draft.txt"
            ;;
        21)
            write_dispatch_card "$id" "$destination"
            mkdir -p "$destination/scratch"
            touch "$destination/scratch/old-a.txt" "$destination/scratch/old-b.txt"
            printf 'Keep this receipt\n' > "$destination/keep.txt"
            ;;
        22)
            write_dispatch_card "$id" "$destination"
            mkdir -p "$destination/delivery batch" "$destination/selected"
            printf 'East route sheets\n' > "$destination/delivery batch/route east.txt"
            printf 'West route sheets\n' > "$destination/delivery batch/route west.txt"
            printf 'North route log\n' > "$destination/delivery batch/route north.log"
            printf 'Departure schedule\n' > "$destination/delivery batch/schedule.txt"
            ;;
        24)
            write_dispatch_card "$id" "$destination"
            cat > "$destination/check-in.sh" <<'CHECK'
#!/usr/bin/env bash
printf 'Station online\n'
printf 'Parcel label missing\n' >&2
CHECK
            ;;
        27) write_dispatch_packet "$destination" ;;
        28)
            write_dispatch_card "$id" "$destination"
            write_hold_audit "$destination"
            ;;
        29)
            write_dispatch_card "$id" "$destination"
            write_intake_audit "$destination"
            ;;
        30)
            write_dispatch_card "$id" "$destination"
            write_handoff_archive "$destination"
            ;;
        35)
            write_dispatch_card "$id" "$destination"
            local row dock status
            for (( row=1; row<=64; row++ )); do
                case $(( row % 4 )) in
                    0) dock=EAST status=READY ;;
                    1) dock=EAST-ANNEX status=READY ;;
                    2) dock=EAST status=NOT_READY ;;
                    3) dock=WEST status=READY ;;
                esac
                printf '%s|%s|BOX-%03d\n' "$dock" "$status" "$row"
            done > "$destination/incoming.txt"
            ;;
        36)
            write_dispatch_card "$id" "$destination"
            local row status
            for (( row=1; row<=64; row++ )); do
                status=WAIT
                if (( row > 32 && row % 3 == 0 )); then status=READY; fi
                printf 'BOX-%03d|%s\n' "$(( (row-1) % 32 + 1 ))" "$status"
            done > "$destination/updates.txt"
            ;;
        37)
            write_dispatch_card "$id" "$destination"
            write_timeline_challenge "$destination"
            ;;
        38)
            write_dispatch_card "$id" "$destination"
            write_access_challenge "$destination"
            ;;
        39) write_mode_inventory "$destination" ;;
        40)
            manifest_rows rejected > "$destination/rejected.txt"
            printf 'parcel|destination\nPK-0000|East Gate\n' > "$destination/example.txt"
            printf 'Intake failed: unexpected byte at end of header. Import stopped before row validation.\n' > "$destination/import.log"
            ;;
        *) write_dispatch_card "$id" "$destination" ;;
    esac
    expand_search_fixture "$id" "$destination"
    write_intro "$id" "$destination"
}

check_practice() {
    local destination
    destination=$(folder "$1")
    case "$1" in
        7)
            local mode
            mode=$(stat -c %a -- "$destination/delivery-note.txt")
            [[ "$mode" == 600 ]] ||
                fail 'Give the owner read and write access only, then submit again.'
            ;;
        8)
            [[ -L "$destination/shortcut" && "$destination/shortcut" -ef "$destination/source.txt" ]] ||
                fail 'Create shortcut as a symbolic link to source.txt.'
            [[ -f "$destination/mirror" && ! -L "$destination/mirror" &&
               "$destination/mirror" -ef "$destination/source.txt" ]] ||
                fail 'Create mirror as a hard link to source.txt.'
            ;;
        9)
            local bay_entry
            bay_entry=$(grep -Fx -A 1 -- 'BAY-07' "$destination/shift-notes.txt") ||
                fail 'Save the BAY-07 entry in shift-notes.txt.'
            [[ "$bay_entry" == $'BAY-07\nstatus=ready' ]] ||
                fail 'Save the updated status for BAY-07, then submit again.'
            ;;
        10)
            local shell_name
            shell_name=$(ps -p "$PPID" -o comm=) || fail 'Submit it from sh.'
            [[ "$shell_name" == sh ]] || fail 'Submit it from sh.'
            ;;
        11) check_key_practice "$destination" ;;
        12) check_process_practice "$destination" ;;
        13)
            check_report "$destination/system-report.txt" "$(uname -r)"$'\n'"$(uname -m)" \
                'Record the kernel release and hardware architecture, in that order, one per line.'
            ;;
        14) check_storage_report "$destination" ;;
        15) check_network_report "$destination" ;;
        16) check_report "$destination/listener.txt" 9100 'Record the port of the loopback-only listener in sockets.txt.' ;;
        17)
            check_report "$destination/latest-ticket.txt" "$latest_dispatch_warning" \
                'Write just the newest dispatch warning’s ticket ID in latest-ticket.txt.'
            ;;
        18)
            check_report "$destination/parcel-name.txt" parcel-b.dat \
                'Write just the gzip parcel’s filename in parcel-name.txt.'
            ;;
        19)
            [[ -d "$destination/staging" && -f "$destination/staging/arrival.txt" &&
               ! -s "$destination/staging/arrival.txt" ]] ||
                fail 'Create staging and put an empty arrival.txt inside it.'
            ;;
        20)
            check_report "$destination/manifest.txt" 'Morning manifest' 'Keep the original manifest.txt in place.'
            if [[ ! -f "$destination/backup.txt" || "$destination/backup.txt" -ef "$destination/manifest.txt" ]] ||
               ! cmp -s -- "$destination/manifest.txt" "$destination/backup.txt"; then
                fail 'Make a separate copy of manifest.txt named backup.txt.'
            fi
            check_report "$destination/ready.txt" 'Afternoon manifest' 'Rename draft.txt to ready.txt.'
            [[ ! -e "$destination/draft.txt" && ! -L "$destination/draft.txt" ]] ||
                fail 'The draft should have its new name only.'
            ;;
        21)
            [[ ! -e "$destination/scratch" && ! -L "$destination/scratch" ]] ||
                fail 'Remove the practice files and their empty scratch directory.'
            check_report "$destination/keep.txt" 'Keep this receipt' 'Leave keep.txt in place.'
            ;;
        22)
            local route copy
            local -a originals=("$destination/delivery batch/"*)
            local -a matches=("$destination/delivery batch/"/route*.txt)
            local -a selected=("$destination/selected/"*)
            (( ${#originals[@]} == route_samples + 4 && ${#matches[@]} == route_samples / 4 + 2 )) ||
                fail 'Keep the original files in the delivery batch.'
            (( ${#selected[@]} == ${#matches[@]} )) ||
                fail 'Put only the matching route sheets in selected.'
            for route in "${matches[@]}"; do
                copy="$destination/selected/${route##*/}"
                if [[ ! -f "$copy" || "$copy" -ef "$route" ]] || ! cmp -s -- "$route" "$copy"; then
                    fail 'Keep the originals and copy all matching sheets into selected.'
                fi
            done
            ;;
        23)
            check_report "$destination/shift-report.txt" $'Shift opened\nParcel received' \
                'Write both report lines in the requested order.'
            ;;
        24)
            check_report "$destination/reception.txt" 'Station online' 'Save the normal output in reception.txt.'
            check_report "$destination/problems.txt" 'Parcel label missing' 'Save the error output in problems.txt.'
            ;;
        25) check_report "$destination/changed-parcel.txt" BOX-208 'Record just the ID of the changed parcel.' ;;
        26)
            check_report "$destination/duplicate-ids.txt" $'BOX-105\nBOX-410' \
                'Record one ID per adjacent group of repeats, in order.'
            ;;
        31)
            check_report "$destination/labels.txt" $'north-route.txt\nwest-route.txt\nsummary.txt' \
                'Put one filename per line in labels.txt, in the requested order.'
            check_report "$destination/boxes.txt" $'BOX-007\nBOX-024\nBOX-105' \
                'Put all three zero-padded IDs in boxes.txt.'
            ;;
        32) check_label_script "$destination" ;;
        33)
            check_bash_output "$destination/decision.sh" REVIEW HOLD 0 < /dev/null
            check_bash_output "$destination/decision.sh" LOAD READY 10 < /dev/null
            check_bash_output "$destination/decision.sh" LOAD READY 17 < /dev/null
            check_bash_output "$destination/decision.sh" WAIT READY 9 < /dev/null
            check_bash_output "$destination/decision.sh" WAIT NOT_READY 20 < /dev/null
            ;;
        34)
            check_bash_output "$destination/queue.sh" $'Queued: east\nQueued: west gate' east 'west gate' < /dev/null
            check_bash_output "$destination/queue.sh" $'Queued: north\nQueued: handoff desk\nQueued: south' \
                north 'handoff desk' south < /dev/null
            check_bash_output "$destination/queue.sh" '' < /dev/null
            ;;
        35) check_ready_script "$destination" ;;
        36)
            local output exit_code=0 input expected
            [[ -f "$destination/states.awk" ]] || fail 'Create states.awk in this challenge folder.'
            input=$'BOX-070|WAIT\nBOX-010|READY\nBOX-070|READY\nBOX-010|HOLD\nBOX-030|WAIT'
            expected=$'BOX-010|HOLD\nBOX-030|WAIT'
            output=$(run_lesson_command "$destination" awk -F '|' -f states.awk <<< "$input" | LC_ALL=C sort) || exit_code=$?
            if (( exit_code )) || [[ "$output" != "$expected" ]]; then
                script_failure "awk -F '|' -f states.awk | LC_ALL=C sort" "$input" 'sorted output' "$expected" "$output" "$exit_code"
            fi
            ;;
    esac
}

write_dispatch_card() {
    local id=$1 destination=$2
    mkdir -p "$destination"
    printf '%s\n' "$(flag "$id")" > "$destination/dispatch.txt"
}

digest_for() {
    local digest
    digest=$(printf '%s:%s' "$seed" "$1" | sha256sum)
    printf '%s' "${digest:0:12}"
}

flag() {
    case "$1" in
        5) printf 'FLAG{BOX-%04d_%d}' "$(first_ready_parcel)" "$ready_parcels" ;;
        6) printf 'FLAG{r-c-3}' ;;
        *) printf 'FLAG{%s}' "$(digest_for "$1")" ;;
    esac
}

write_dispatch_log() {
    local logfile=$1 first_ticket=$2 flagged_ticket=$3 flag_key=$4
    local offset ticket event
    local -a events=(
        'INFO intake opened'
        'INFO scheduler assigned'
        'WARN dispatch retrying'
        'INFO courier closed'
    )

    for (( offset=0; offset<64; offset++ )); do
        ticket=$(( first_ticket + offset ))
        event=${events[offset % ${#events[@]}]}
        if (( ticket == flagged_ticket )); then
            event="INFO dispatch closed $(flag "$flag_key")"
        fi
        printf '2026-01-15T%02d:%02d:00Z TICKET-%04d %s\n' \
            "$(( 8 + offset / 60 ))" "$(( offset % 60 ))" "$ticket" "$event"
    done > "$logfile"
}

check_report() {
    local report=$1 expected=$2 reminder=$3
    [[ -f "$report" && $(< "$report") == "$expected" ]] || fail "$reminder"
}

run_lesson_command() (
    local directory=$1
    shift
    cd -- "$directory" || return
    timeout --kill-after=1s 3s env -u BASH_ENV -u ENV "$@" 9<&-
)

script_failure() {
    local example=$1 input=$2 result=$3 expected=$4 actual=$5 exit_code=$6
    {
        printf 'Try this example in the lesson folder:\n  %s\n' "$example"
        if [[ -n "$input" ]]; then printf 'Standard input (finish with Ctrl-D):\n%s\n' "$input"; fi
        printf 'Expected %s:\n%s\n' "$result" "${expected:-<empty>}"
        if (( ${#actual} > 1000 )); then actual="${actual:0:1000}"$'\n[output truncated]'; fi
        printf 'Actual %s:\n%s\n' "$result" "${actual:-<empty>}"
        if (( exit_code )); then printf 'Command exit status: %d\n' "$exit_code"; fi
    } >&2
    exit 1
}

check_script_output() {
    local script=$1 expected=$2 output example exit_code=0
    shift 2
    [[ -f "$script" ]] || fail "Create ${script##*/} in this challenge folder."
    output=$(run_lesson_command "${script%/*}" "$@") || exit_code=$?
    if (( exit_code )) || [[ "$output" != "$expected" ]]; then
        printf -v example '%q ' "$@"
        script_failure "${example% }" '' 'output' "$expected" "$output" "$exit_code"
    fi
}

check_bash_output() {
    local script=$1 expected=$2
    shift 2
    check_script_output "$script" "$expected" bash --noprofile --norc "./${script##*/}" "$@"
}

add_hidden_note_samples() {
    local destination=$1 sample name
    mkdir -p "$destination/.dispatch"
    for (( sample=1; sample<=64; sample++ )); do
        printf -v name 'handoff-%02d.txt' "$sample"
        printf 'Routine dispatch handoff %02d\n' "$sample" > "$destination/.dispatch/$name"
    done
}

write_log_challenge() {
    local destination=$1
    mkdir -p "$destination/records/archive" "$destination/records/incoming"
    write_dispatch_log "$destination/records/archive/dispatch.log" 1010 1042 3
    write_dispatch_log "$destination/records/incoming/dispatch.log" 1350 1402 decoy-3
}

add_ticket_search_samples() {
    local destination=$1 area note branch sample first_ticket
    for (( area=1; area<=8; area++ )); do
        printf -v branch '%s/records/region-%02d/shift-%02d' "$destination" "$area" "$(( area % 3 + 1 ))"
        mkdir -p "$branch"
        first_ticket=$(( 3000 + area * 100 ))
        write_dispatch_log "$branch/queue.log" "$first_ticket" "$(( first_ticket + 11 ))" "decoy-3-region-$area"
        for (( note=1; note<=8; note++ )); do
            printf -v sample 'handoff-%02d.txt' "$note"
            printf 'Region %02d dispatch handoff %02d\n' "$area" "$note" > "$branch/$sample"
        done
    done
}

write_archive_challenge() (
    local destination=$1 dependency scratch digest password
    local -a missing=()
    for dependency in gzip bzip2 tar zip unzip; do
        if ! command -v "$dependency" >/dev/null; then
            missing+=("$dependency")
        fi
    done
    (( ${#missing[@]} == 0 )) ||
        fail "The archive challenge needs these commands in the VM: ${missing[*]}. Install them and retry."

    mkdir -p "$destination"
    scratch=$(mktemp -d "$destination/.build.XXXXXX")
    trap 'rm -rf -- "$scratch"' EXIT
    digest=$(digest_for password-4)
    password="dispatch-${digest:0:8}"

    printf '%s\n' 'Find handoff.txt inside dispatch.tar.bz2. It has the password for sealed.zip.' |
        gzip -c > "$scratch/routing.txt.gz"
    printf 'Use this password to open sealed.zip: %s\n' "$password" > "$scratch/handoff.txt"
    tar -cjf "$scratch/dispatch.tar.bz2" -C "$scratch" handoff.txt
    printf '%s\n' "$(flag 4)" > "$scratch/receipt.txt"
    (
        cd -- "$scratch"
        zip -q -P "$password" sealed.zip receipt.txt
    )
    mv -f -- "$scratch/routing.txt.gz" "$scratch/dispatch.tar.bz2" "$scratch/sealed.zip" "$destination/"
)


first_ready_parcel() {
    local digest
    digest=$(digest_for parcel-5)
    printf '%d' "$(( 100 + 16#${digest:0:2} ))"
}

write_scan_challenge() {
    local destination=$1 scan first parcel zone status
    first=$(first_ready_parcel)
    mkdir -p "$destination"
    {
        printf 'scan|zone|status|parcel\n'
        for (( scan=0; scan<120; scan++ )); do
            case $(( scan % 5 )) in
                0|1)
                    zone=NORTH status=READY
                    parcel=$(( first + (7 + scan / 5 * 5 + scan % 5 * 3) % ready_parcels ))
                    ;;
                2) zone=NORTH status=NOT_READY; parcel=$(( first - 20 + scan % 11 )) ;;
                3) zone=SOUTH status=READY; parcel=$(( first - 40 + scan % 13 )) ;;
                4) zone=NORTHEAST status=READY; parcel=$(( first - 60 + scan % 17 )) ;;
            esac
            printf '%03d|%s|%s|BOX-%04d\n' "$(( scan + 1 ))" "$zone" "$status" "$parcel"
        done
    } > "$destination/scans.txt"
}

write_shift_notes() {
    local destination=$1 bay
    mkdir -p "$destination"
    {
        printf 'Dispatch shift notes\n\n'
        for (( bay=1; bay<=16; bay++ )); do
            printf 'BAY-%02d\nstatus=waiting\n' "$bay"
            case "$bay" in
                7) printf 'flag=%s\n' "$(flag 9)" ;;
                14) printf 'flag=%s\n' "$(flag decoy-9)" ;;
                *) printf 'note=Awaiting a dispatch update.\n' ;;
            esac
            printf '\n'
        done
    } > "$destination/shift-notes.txt"
}

add_bay_search_samples() {
    local notes="$1/shift-notes.txt" temporary bay
    if [[ ! -f "$notes" ]] || grep -Fxq 'BAY-17' "$notes"; then return; fi
    temporary=$(mktemp "$1/.shift-notes.XXXXXX")
    {
        head -n 2 -- "$notes"
        for (( bay=17; bay<=48; bay++ )); do
            printf 'BAY-%02d\nstatus=waiting\nnote=Awaiting a dispatch update.\n\n' "$bay"
        done
        tail -n +3 -- "$notes"
        for (( bay=49; bay<=80; bay++ )); do
            printf 'BAY-%02d\nstatus=waiting\nnote=Awaiting a dispatch update.\n\n' "$bay"
        done
    } > "$temporary"
    mv -f -- "$temporary" "$notes"
}

check_key_practice() {
    local destination=$1 public_key key_type details bits fingerprint
    public_key="$destination/training-key.pub"
    [[ -s "$destination/training-key" && -s "$public_key" ]] ||
        fail 'Create the training-key pair in this challenge folder first.'
    read -r key_type _ < "$public_key" ||
        fail 'Check that training-key.pub contains your public key.'
    case "$key_type" in
        ssh-*|ecdsa-*|sk-*) ;;
        *) fail 'Check that training-key.pub contains your public key.' ;;
    esac
    details=$(ssh-keygen -l -E sha256 -f "$public_key") ||
        fail 'Check that training-key.pub is a valid public key.'
    read -r bits fingerprint _ <<< "$details"
    [[ -f "$destination/fingerprint.txt" && $(< "$destination/fingerprint.txt") == "$fingerprint" ]] ||
        fail 'Save only the public key’s SHA256 fingerprint in fingerprint.txt.'
}

check_process_practice() {
    local destination=$1 pid process name
    [[ -f "$destination/process-id.txt" ]] ||
        fail 'Save the PID of your sleep process in process-id.txt.'
    pid=$(< "$destination/process-id.txt")
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] ||
        fail 'Put only the numeric PID in process-id.txt.'
    process="/proc/$pid"
    if [[ -O "$process" && "$process/cwd" -ef "$destination" && -r "$process/comm" ]] &&
       read -r name < "$process/comm" && [[ "$name" == sleep ]]; then
        return
    fi
    fail 'Record the PID of a sleep process still running from this challenge folder.'
}

write_parcels() {
    local parcels="$1/parcels"
    mkdir -p "$parcels/east" "$parcels/north" "$parcels/west"
    dd if=/dev/urandom of="$parcels/east/payload.bin" bs=1024 count=8 status=none
    dd if=/dev/urandom of="$parcels/north/payload.bin" bs=1024 count=16 status=none
    dd if=/dev/urandom of="$parcels/west/payload.bin" bs=1024 count=96 status=none
}

add_storage_samples() {
    local parcels="$1/parcels" sample directory
    for (( sample=1; sample<=56; sample++ )); do
        printf -v directory '%s/crate-%02d' "$parcels" "$sample"
        mkdir -p "$directory"
        dd if=/dev/urandom of="$directory/payload.bin" bs=1024 count="$(( 2 + sample * 13 % 25 ))" status=none
    done
}

check_storage_report() {
    local destination=$1 filesystem
    filesystem=$(df --output=fstype -- "$destination")
    read -r filesystem _ <<< "${filesystem#*$'\n'}"
    check_report "$destination/storage-report.txt" "$filesystem"$'\nwest' \
        'Record the filesystem type on the first line and the largest parcel directory name on the second.'
}

check_network_report() {
    local destination=$1 addresses index interface family address
    command -v ip >/dev/null || fail 'This challenge needs the ip command.'
    addresses=$(ip -o -4 address show scope host) ||
        fail 'Could not read local network information with ip.'
    while read -r index interface family address _; do
        if [[ "$family" == inet && "$address" == 127.0.0.1/* ]]; then
            check_report "$destination/network-report.txt" "${interface%:}"$'\n'"$address" \
                'Record the loopback interface name on the first line and its IPv4 address with prefix on the second.'
            return
        fi
    done <<< "$addresses"
    fail 'No IPv4 localhost address was found on this VM.'
}

write_observation_fixture() {
    local id=$1 destination=$2
    mkdir -p -- "$destination"
    if [[ "$id" == 6 ]]; then
        printf '%s\n' 'INFO opened' 'WARN delayed' 'INFO queued' 'WARN retry' 'WARN returned' > "$destination/dispatch.log"
    else
        write_dispatch_card 16 "$destination"
        cat > "$destination/sockets.txt" <<'SOCKETS'
State   Recv-Q Send-Q Local Address:Port  Peer Address:Port
LISTEN  0      128    0.0.0.0:8080        0.0.0.0:*
ESTAB   0      0      127.0.0.1:52014    127.0.0.1:9100
LISTEN  0      64     127.0.0.1:9100     0.0.0.0:*
SOCKETS
    fi
}

write_recent_dispatch() {
    local destination=$1 logfile="$1/logs/dispatch.log" offset minute event
    local -a events=(
        'INFO dispatch assigned'
        'WARN courier delayed'
        'DEBUG scheduler heartbeat'
        'INFO intake opened'
        'WARN scheduler delayed'
        'INFO dispatch closed'
    )
    mkdir -p "$destination/logs"
    write_dispatch_log "$logfile" 2100 2149 decoy-17-archive
    cat >> "$logfile" <<RECORDS
2026-01-15T09:04:00Z TICKET-2164 WARN dispatch retrying $(flag decoy-17-older)
2026-01-15T09:05:00Z $latest_dispatch_warning WARN dispatch retrying $(flag 17)
2026-01-15T09:06:00Z TICKET-2166 INFO courier closed
2026-01-15T09:07:00Z TICKET-2167 DEBUG dispatch heartbeat
2026-01-15T09:08:00Z TICKET-2168 WARN intake delayed
2026-01-15T09:09:00Z TICKET-2169 INFO dispatch assigned
2026-01-15T09:10:00Z TICKET-2170 INFO courier loaded
2026-01-15T09:11:00Z TICKET-2171 WARN courier delayed
2026-01-15T09:12:00Z TICKET-2172 INFO intake opened
2026-01-15T09:13:00Z TICKET-2173 DEBUG dispatch heartbeat
2026-01-15T09:14:00Z TICKET-2174 WARN scheduler delayed $(flag decoy-17-service)
2026-01-15T09:15:00Z TICKET-2175 INFO dispatch closed $(flag decoy-17-level)
RECORDS
    for (( offset=0; offset<48; offset++ )); do
        minute=$(( 16 + offset ))
        event=${events[offset % ${#events[@]}]}
        if (( offset == 31 || offset == 47 )); then
            event+=" $(flag "decoy-17-recent-$offset")"
        fi
        printf '2026-01-15T%02d:%02d:00Z TICKET-%04d %s\n' \
            "$(( 9 + minute / 60 ))" "$(( minute % 60 ))" "$(( 2176 + offset ))" "$event"
    done >> "$logfile"
}

write_mystery_parcels() {
    local destination=$1
    mkdir -p "$destination"
    printf 'Old dispatch receipt %s\n' "$(flag decoy-18)" > "$destination/parcel-a.dat"
    printf '%s\n' "$(flag 18)" | gzip -c > "$destination/parcel-b.dat"
    printf 'parcel,status\nc,waiting\n' > "$destination/parcel-c.dat"
}

add_mystery_samples() {
    local destination=$1 sample path
    for (( sample=1; sample<=60; sample++ )); do
        printf -v path '%s/parcel-%02d.dat' "$destination" "$sample"
        case $(( sample % 3 )) in
            0) printf 'parcel,status\n%02d,waiting\n' "$sample" ;;
            1) printf 'Parcel %02d awaiting review.\n' "$sample" ;;
            2) printf '\000\362\017\000%02d\000\001' "$sample" ;;
        esac > "$path"
    done
}

add_route_samples() {
    local destination=$1 sample name
    mkdir -p "$destination/delivery batch"
    for (( sample=1; sample<=route_samples; sample++ )); do
        case $(( sample % 4 )) in
            0) printf -v name 'route sector-%02d.txt' "$sample" ;;
            1) printf -v name 'route sector-%02d.log' "$sample" ;;
            2) printf -v name 'roster sector-%02d.txt' "$sample" ;;
            3) printf -v name 'archive sector-%02d.txt' "$sample" ;;
        esac
        printf 'Sector %02d dispatch data\n' "$sample" > "$destination/delivery batch/$name"
    done
}

write_manifest_comparison() {
    local destination=$1 manifest parcel status
    local -a statuses=(queued held shipped staged)
    for manifest in yesterday today; do
        for (( parcel=145; parcel<=240; parcel++ )); do
            status=${statuses[parcel % ${#statuses[@]}]}
            if (( parcel == 208 )) && [[ "$manifest" == today ]]; then
                status=shipped
            fi
            printf 'BOX-%03d %s\n' "$parcel" "$status"
        done > "$destination/$manifest.txt"
    done
}

write_repeat_scans() {
    local destination=$1 row parcel
    for (( row=1; row<=128; row++ )); do
        case "$row" in
            39|40) parcel=105 ;;
            93|94) parcel=410 ;;
            *) parcel=$(( 100 + (row * 43 % 79) * 5 )) ;;
        esac
        printf 'BOX-%03d\n' "$parcel"
    done > "$destination/scans.txt"
}

packet_sheet() {
    local route=$1 index=$2 revision=$3
    printf 'Dispatch route %s\nRevision %02d\nStaging lane %02d\n' "$route" "$revision" "$((index + revision + 1))"
}

write_dispatch_packet() {
    local destination=$1 route_index route revision revision_label rack shift decision
    local north=$((1 + 16#${seed:0:2} % 6)) west=$((1 + 16#${seed:2:2} % 6))
    local -a routes=(north west east south central river hill harbor garden market airport depot)
    local -a decisions=(HOLD REJECTED NOT_APPROVED)
    mkdir -p "$destination/records"
    printf '%s\n' north-route.txt west-route.txt > "$destination/reference-manifest.txt"
    printf '%s\n' "$(flag 27)" > "$destination/dispatch.txt"
    {
        printf 'shift|decision|route|revision\n'
        for route_index in "${!routes[@]}"; do
            route="${routes[route_index]}"
            for (( revision=1; revision<=6; revision++ )); do
                printf -v revision_label '%02d' "$revision"
                printf -v rack '%s/warehouse/rack %02d/bin-%02d' "$destination" \
                    "$(( route_index % 4 + 1 ))" "$(( (revision + route_index / 4) % 6 + 1 ))"
                mkdir -p "$rack"
                packet_sheet "$route" "$route_index" "$revision" > "$rack/route-$route-r$revision_label.txt"

                shift=NIGHT
                decision="${decisions[(route_index + revision) % ${#decisions[@]}]}"
                if [[ "$route:$revision" == "north:$north" || "$route:$revision" == "west:$west" ]]; then
                    decision=APPROVED
                elif (( (route_index + revision) % 5 == 0 )); then
                    shift=DAY decision=APPROVED
                fi
                printf '%s|%s|%s|%s\n' "$shift" "$decision" "$route" "$revision_label"
            done
        done
    } > "$destination/records/approvals.log"
}

puzzle_variant() {
    printf '%d' "$((1 + 16#${seed:4:4} % 600))"
}

write_mode_inventory() {
    local destination=$1 row path before after
    for ((row=1; row<=24; row++)); do
        path="/dispatch/bin/tool-$((1000+variant+row))"
        before=0755 after=0755
        case $row in
            4) before=4755 after=4755 ;;
            9|17) after=4755 ;;
            13) after=0750 ;;
        esac
        printf '%s|dispatch|%s\n' "$path" "$before"
        printf '%s|dispatch|%s\n' "$path" "$after" >&3
    done > "$destination/yesterday.txt" 3> "$destination/today.txt"
    printf 'T-%d|APPROVED|/dispatch/bin/tool-%d|4755\n' "$variant" "$((1009+variant))" > "$destination/tickets.txt"
    printf 'T-%d|PENDING|/dispatch/bin/tool-%d|4755\n' "$((variant+1))" "$((1017+variant))" >> "$destination/tickets.txt"
}

manifest_rows() {
    local format=$1 row parcel destination ending=''
    if [[ "$format" == rejected ]]; then ending=$'\r'; fi
    printf 'parcel|destination%s\n' "$ending"
    for ((row=1; row<=24; row++)); do
        printf -v parcel 'PK-%04d' "$((1000+variant+row))"
        destination='East Gate'
        if (( row % 3 == 0 )); then destination='North  Annex'; fi
        if [[ "$format" == rejected ]] && (( row == 4 + variant % 16 )); then
            parcel="${parcel:0:5}"$'\t'"${parcel:5}"
        fi
        printf '%s|%s%s\n' "$parcel" "$destination" "$ending"
    done
}

write_hold_audit() {
    local destination=$1 pass ticket sequence=0 dock status
    printf 'sequence|dock|ticket|status\n' > "$destination/events.log"
    for pass in 1 2; do
        for (( ticket=1; ticket<=96; ticket++ )); do
            case $(( ticket % 3 )) in
                0) dock=EAST ;;
                1) dock=EAST-ANNEX ;;
                2) dock=WEST ;;
            esac
            status=HOLD
            if (( pass == 2 && ticket % 12 != 0 && ticket % 3 != 1 )); then
                status=RELEASED
            fi
            sequence=$(( sequence + 1 ))
            printf '%03d|%s|TICKET-%04d|%s\n' "$sequence" "$dock" "$((ticket+variant))" "$status"
        done
    done >> "$destination/events.log"
}

write_intake_audit() {
    local destination=$1 crate zone
    for (( crate=1; crate<=84; crate++ )); do
        zone=SOUTH-ANNEX
        if (( crate % 2 == 0 )); then zone=SOUTH; fi
        printf '%s|CRATE-%03d\n' "$zone" "$((crate+variant))"
    done > "$destination/plan.txt"
    {
        for (( crate=84; crate>=1; crate-- )); do
            if (( crate == 16 || crate == 44 || crate == 70 || crate == 35 )); then continue; fi
            zone=SOUTH-ANNEX
            if (( crate % 2 == 0 )); then zone=SOUTH; fi
            printf '%s|CRATE-%03d\n' "$zone" "$((crate+variant))"
        done
        printf 'SOUTH-ANNEX|CRATE-%03d\n' "$((85+variant))"
        printf 'SOUTH|CRATE-%03d\n' "$((86+variant))" "$((90+variant))" "$((6+variant))" "$((94+variant))" "$((42+variant))"
    } > "$destination/intake.txt"
}

write_handoff_archive() (
    local destination=$1 staging note batch status directory dock pallets
    staging=$(mktemp -d "$destination/.build.XXXXXX")
    trap 'rm -rf -- "$staging"' EXIT
    for (( note=1; note<=72; note++ )); do
        batch=$(( 100 + note ))
        status=VERIFIED
        dock=$(( note % 7 + 1 ))
        pallets=$(( note % 24 + 5 ))
        case "$note" in
            18) batch=44 status=DRAFT ;;
            "$((27 + variant % 30))") batch=44 dock=$((1+variant%8)) pallets=$((9+variant%29)) ;;
            67) batch=44 status=SUPERSEDED ;;
        esac
        printf -v directory '%s/bundles/shift-%02d' "$staging" "$(( note % 6 + 1 ))"
        mkdir -p "$directory"
        printf 'Batch BATCH-%03d\nState %s\nDock DOCK-%02d\nPallets %d\n' \
            "$batch" "$status" "$dock" "$pallets" > "$directory/note-$note.txt"
    done
    tar -czf "$staging/recovery.tar.gz" -C "$staging" bundles
    mv -f -- "$staging/recovery.tar.gz" "$destination/"
    (cd -- "$destination" && sha256sum recovery.tar.gz > .original.sha256)
)



check_label_script() {
    local script="$1/label.sh" first_line
    [[ -f "$script" ]] || fail 'Create label.sh in this challenge folder.'
    if ! IFS= read -r first_line < "$script" ||
       [[ "$first_line" != '#!/bin/bash' && "$first_line" != '#!/usr/bin/env bash' ]]; then
        fail 'Put a Bash shebang such as #!/bin/bash on the first line of label.sh.'
    fi
    [[ -x "$script" ]] || fail 'Grant execute permission with chmod u+x label.sh.'
    check_script_output "$script" 'EAST: BOX-042' ./label.sh EAST BOX-042 < /dev/null
    check_script_output "$script" 'West Gate: BOX-003' ./label.sh 'West Gate' BOX-003 < /dev/null
}

check_ready_example() {
    local scratch=$1 input=$2 expected=$3 actual exit_code=0
    run_lesson_command "$scratch" bash --noprofile --norc ready.sh > /dev/null <<< "$input" || exit_code=$?
    if [[ -f "$scratch/ready-ids.txt" ]]; then
        actual=$(< "$scratch/ready-ids.txt")
    else
        actual='<file missing>'
    fi
    if (( exit_code )) || [[ "$actual" != "$expected" ]]; then
        script_failure 'bash ready.sh' "$input" 'ready-ids.txt' "$expected" "$actual" "$exit_code"
    fi
}

check_ready_script() (
    local destination=$1 scratch script="$1/ready.sh"
    [[ -f "$script" ]] || fail 'Create ready.sh in this challenge folder.'
    scratch=$(mktemp -d "$destination/.check-ready.XXXXXX")
    trap 'rm -rf -- "$scratch"' EXIT
    cp -- "$script" "$scratch/ready.sh"
    check_ready_example "$scratch" \
        $'EAST-ANNEX|READY|BOX-001\nEAST|READY|BOX-080\nEAST|NOT_READY|BOX-010\nEAST|READY|BOX-002\nEAST|READY|BOX-080' \
        $'BOX-080\nBOX-002\nBOX-080'
    check_ready_example "$scratch" 'WEST|READY|BOX-005' ''
)



timeline_rows() {
    printf '08:15|TICKET-%04d\n' "$((411+variant))"
    printf '08:22|TICKET-%04d\n' "$((26+variant))" "$((630+variant))"
    printf '08:37|TICKET-%04d\n' "$((513+variant))"
    printf '08:59|TICKET-%04d\n' "$((179+variant))"
}

write_timeline_challenge() {
    local destination=$1 scanner minute time dock event match ticket index
    local -a docks=(WEST WEST-ANNEX EAST WEST)
    local -a events=(LOADING LOADED LOADED UNLOADED)
    local -a matches
    mapfile -t matches < <(timeline_rows)
    mkdir -p "$destination/scans"
    for scanner in 1 2; do
        {
            printf 'time|dock|event|ticket\n'
            for (( minute=0; minute<72; minute++ )); do
                printf -v time '%02d:%02d' "$(( 8 + minute / 60 ))" "$(( minute % 60 ))"
                dock=${docks[minute % 4]}
                event=${events[minute % 4]}
                printf '%s|%s|%s|TICKET-%04d\n' "$time" "$dock" "$event" "$(( scanner * 1000 + minute ))"
                if [[ "$time" == 08:14 || "$time" == 09:00 ]]; then
                    printf '%s|WEST|LOADED|TICKET-%04d\n' "$time" "$(( scanner * 200 + minute ))"
                fi
                for index in "${!matches[@]}"; do
                    match=${matches[index]}
                    if [[ "$time" != "${match%%|*}" ]]; then continue; fi
                    ticket="${match#*|}"
                    case "$scanner:$index" in
                        1:1|2:3) continue ;;
                    esac
                    printf '%s|WEST|LOADED|%s\n' "$time" "$ticket"
                done
            done
        } > "$destination/scans/scanner-$scanner.log"
    done
}

route_file_path() {
    local item=$(( ($1 - 1 + variant) % 64 + 1 ))
    printf 'routes/rack-%02d/route-%03d.txt' "$(( (item - 1) / 8 + 1 ))" "$item"
}

write_access_challenge() {
    local destination=$1 item path shift decision role
    local -a roles=(REVIEW TEAM_READ TEAM_EDIT)
    {
        printf 'shift|decision|path|role\n'
        for (( item=1; item<=64; item++ )); do
            path=$(route_file_path "$item")
            mkdir -p "$destination/${path%/*}"
            printf 'Dispatch route %03d\n' "$item" > "$destination/$path"
            shift=NIGHT decision=NOT_APPROVED
            role=${roles[item % 3]}
            case "$item" in
                13) decision=APPROVED role=REVIEW ;;
                38) decision=APPROVED role=TEAM_READ ;;
                57) decision=APPROVED role=TEAM_EDIT ;;
                *)
                    if (( item % 5 == 0 )); then shift=DAY decision=APPROVED; fi
                    ;;
            esac
            printf '%s|%s|%s|%s\n' "$shift" "$decision" "$path" "$role"
        done
    } > "$destination/access.log"
}

check_access_modes() {
    local destination=$1 group=$2 item expected actual path
    for (( item=1; item<=64; item++ )); do
        path=$(route_file_path "$item")
        case "$item" in
            13) expected=400 ;;
            38) expected=640 ;;
            57) expected=660 ;;
            *) expected=600 ;;
        esac
        if [[ "$group" == approved && "$expected" == 600 || "$group" == other && "$expected" != 600 ]]; then continue; fi
        if [[ ! -f "$destination/$path" || -L "$destination/$path" ]] ||
           ! actual=$(stat -c %a -- "$destination/$path") || [[ "$actual" != "$expected" ]]; then
            fail "Check the approval and permission mode for $path."
        fi
    done
}

lesson_text() {
    case "$1:$2" in
        1:intro) cat <<'PROMPT' ;;
Find your bearings

The supply crew left a note in the supplies directory. Find note.txt,
read it, and submit the entire flag with beginnix submit.

Suggested commands
  pwd  ls  cd  cat
PROMPT
        1:hint) printf 'Once you reach the supplies directory, look for a way to display a file in the terminal.\n' ;;
        1:answer) cat <<'ANSWER' ;;
Run pwd, then ls to see supplies. Open the note with these commands.
  cd supplies
  cat note.txt
ANSWER
        1:debrief) printf 'pwd prints your location, ls lists entries, and cd changes directory. cat writes a file to your terminal.\n' ;;
        2:intro) cat <<'PROMPT' ;;
Find the hidden note

The dispatcher tucked the morning handoff note in a hidden
directory. Find that directory, then start typing the note's name
in your command and press Tab to finish it. Read the note and
submit the flag.

Suggested commands
  ls  cd  cat

PROMPT
        2:hint) printf 'Hidden names start with a dot. Check how to include them in a directory listing.\n' ;;
        2:answer) cat <<'ANSWER' ;;
Run ls -a to see .dispatch, then enter it with cd .dispatch.
Type cat morning and press Tab to finish the name. Press Enter to
read the note.
ANSWER
        2:debrief) printf 'Names beginning with a dot are hidden in a normal ls listing. Tab completion saves typing. Optional: press Up to recall your command. Try Ctrl+A and Ctrl+E to move to either end of it.\n' ;;
        3:intro) cat <<'PROMPT' ;;
Follow the ticket

The dispatch team left a flag on ticket TICKET-1042. Search the .log
files under records and submit the flag on that ticket's line. Other
tickets may have flags of their own.

Suggested commands
  find  grep
PROMPT
        3:hint) printf 'The ticket ID is inside a file. Look for a way to search the contents of several files at once.\n' ;;
        3:answer) cat <<'ANSWER' ;;
  find records -type f -name '*.log'
  grep -rF 'TICKET-1042' records

Use the flag on the line for that exact ticket.
ANSWER
        3:debrief) printf 'find searches directory entries. grep searches their contents. With grep, -r searches recursively and -F matches literal text.\n' ;;
        4:intro) cat <<'PROMPT' ;;
Open the shipment

Three files arrived from dispatch. Open routing.txt.gz to find the
first handoff. Follow the notes until you can read the receipt and
submit its flag.

Suggested commands
  ls  file  gzip  bzip2  tar  unzip  cat  man
PROMPT
        4:hint) printf 'Look at the filename endings for clues about which tools can open them. One file uses two formats.\n' ;;
        4:answer) cat <<'ANSWER' ;;
  gzip -dc routing.txt.gz
  tar -xjf dispatch.tar.bz2
  cat handoff.txt
  unzip sealed.zip
  cat receipt.txt

When unzip prompts, enter the password from handoff.txt. Reuse any
files you already unpacked.
ANSWER
        4:debrief) printf 'gzip and bzip2 compress data. tar bundles files, including in compressed tar archives. unzip extracts ZIP files and can prompt for a password.\n' ;;
        5:intro) cat <<'PROMPT' ;;
Reconcile the scans

Dispatch scanned some parcels more than once. In scans.txt, keep
only records whose zone is NORTH and whose status is READY.
Find the alphabetically first parcel ID and count the distinct parcel
IDs in those records.

Combine your findings as FLAG{PARCEL_COUNT}. For example, if the
first ID were BOX-0123 and there were 7 distinct IDs, you would submit
FLAG{BOX-0123_7}.

Suggested commands
  head  grep  cut  awk  sort  wc  man
PROMPT
        5:hint) printf 'A substring match can include other zones or statuses. Match whole fields and handle repeats before you count.\n' ;;
        5:answer) cat <<'ANSWER' ;;
  grep -F '|NORTH|READY|' scans.txt | cut -d '|' -f 4 | sort -u > ready-ids.txt
  head -n 1 ready-ids.txt
  wc -l ready-ids.txt

Use the first ID and the distinct count in that order, with an underscore.
ANSWER
        5:debrief) printf 'A pipe passes output to the next command. cut can select fields, awk can filter records by field, sort can order and deduplicate IDs, and wc can count lines.\n' ;;
        6:intro) cat <<'PROMPT' ;;
Read the docs

Dispatch needs the number of warning lines in dispatch.log.

1. Read Bash's help for read (in Zsh, use bash -c 'help read').
   Find the short option that preserves literal backslashes.
2. Use man grep or grep --help to find the short option that counts
   matching lines. Use it with the pattern '^WARN' on dispatch.log.
3. Submit FLAG{letter-letter-count}, using the two option letters
   without dashes, followed by the number your command printed.
PROMPT
        6:hint) printf 'Search for “count” in the grep manual. The ^ in the pattern means start of line.\n' ;;
        6:answer) cat <<'ANSWER' ;;
  bash -c 'help read'
  grep --help
  grep -c '^WARN' dispatch.log

The options are -r and -c. Use the printed count as the last part of the flag.
ANSWER
        6:debrief) printf 'Bash help documents builtins. grep counts matching lines, so two matches on the same line still count once.\n' ;;
        7:intro) cat <<'PROMPT' ;;
Unlock the note

Dispatch left you a note named delivery-note.txt. Check its owner,
group, and permissions. The owner can write to it but needs read
access too. Add read permission for the owner and leave the other
permissions as they are. Then read the note and submit its flag.

Suggested commands
  stat  chmod  cat
PROMPT
        7:hint) printf 'Permissions are listed separately for the owner, group, and everyone else. Look for a way to add a permission just for the owner.\n' ;;
        7:answer) cat <<'ANSWER' ;;
  stat delivery-note.txt
  chmod u+r delivery-note.txt
  cat delivery-note.txt

The permission change gives the owner read access and keeps write access.
ANSWER
        7:debrief) printf 'stat shows a file’s owner, group, and permissions. chmod changes permissions. In its symbolic notation, u means the owner and + adds a permission.\n' ;;
        8:intro) cat <<'PROMPT' ;;
Two ways to link

Dispatch wants two names for the same route sheet, source.txt.

1. Make a symbolic link named shortcut that points to source.txt.
   Inspect the path stored in shortcut.
2. Make a hard link named mirror to source.txt. Compare their inode
   numbers to see whether they refer to the same file.

Read the flag through either link and submit it. Keep both links
in this folder for the submission check.

Suggested commands
  ln  readlink  ls  cat
PROMPT
        8:hint) printf 'A symbolic link stores a path. A hard link points to the same inode as the original. The link command can create both kinds.\n' ;;
        8:answer) cat <<'ANSWER' ;;
  ln -s source.txt shortcut
  ln source.txt mirror
  readlink shortcut
  ls -i source.txt mirror
  cat mirror

If a name is already in use, inspect it before moving it out of the way.
ANSWER
        8:debrief) printf 'readlink prints the path stored in a symbolic link. Hard links share an inode, so either name still opens the file if the other name is removed.\n' ;;
        9:intro) cat <<'PROMPT' ;;
Edit the shift notes

Open shift-notes.txt in Vim and search for BAY-07. On the next line,
change status=waiting to status=ready. Save the file and exit Vim.
Submit the flag from the BAY-07 entry.

If Vim isn't installed, you can use Neovim. If you're unsure which
mode you're in, press Esc to return to Normal mode.

Suggested commands
  vim  nvim
PROMPT
        9:hint) printf 'In Vim, searching and editing happen in different modes. Find the bay in Normal mode before changing its status.\n' ;;
        9:answer) cat <<'ANSWER' ;;
Open shift-notes.txt with vim or nvim. In Normal mode, type /BAY-07
and press Enter. Press j to move down one line, then cc to replace
that line. Type status=ready, press Esc, then type :wq and press Enter.
ANSWER
        9:debrief) printf 'In Vim, / searches in Normal mode and i starts Insert mode. Esc returns to Normal mode. :wq saves and quits.\n' ;;
        10:intro) cat <<'PROMPT' ;;
Switch shells

The next dispatch needs to come from sh. First, use ps to identify
your current shell. Then start sh and check again. The shell variable
$$ gives you the PID of the shell you're typing in. Look for how ps
can display information about a single PID.

Read the flag in dispatch.txt and submit it while you're still in sh.
Afterward, use exit to return to your usual lab shell.

Suggested commands
  ps  sh  cat  man
PROMPT
        10:hint) printf 'The shell you start inside another shell gets its own PID. Compare the process information before and after the switch.\n' ;;
        10:answer) cat <<'ANSWER' ;;
  ps -p "$$" -o comm=
  sh
  ps -p "$$" -o comm=

Enter the second ps command inside sh. Submit the flag there, then
type exit to return to the parent shell.
ANSWER
        10:debrief) printf 'ps reports information about running processes. $$ identifies the current shell. Starting sh opens a child shell, and exiting it returns you to the parent.\n' ;;
        11:intro) cat <<'PROMPT' ;;
Fingerprint a key

Create an SSH key pair for this exercise. Run ssh-keygen and enter
./training-key at the save prompt so both files stay in this folder.

Identify the public key, then use ssh-keygen to display its
fingerprint. Save just the SHA256:... token on one line in
fingerprint.txt. Read and submit the flag in dispatch.txt.

Keep the private key in the lab folder. This task uses the fingerprint
and runs entirely on your VM.

Suggested commands
  ssh-keygen  ls  man  vim  nvim  cat
PROMPT
        11:hint) printf 'The public key usually has an extra filename extension. Look for fingerprinting in the key generator’s manual.\n' ;;
        11:answer) cat <<'ANSWER' ;;
Run ssh-keygen and give ./training-key as the save path. If you
already created the pair, use the existing files.

  ssh-keygen -l -E sha256 -f training-key.pub

Copy only the SHA256:... token from the output into fingerprint.txt.
ANSWER
        11:debrief) printf 'ssh-keygen creates a key pair. The .pub file is for sharing. The private key stays with you. A fingerprint is a short identifier derived from the public key.\n' ;;
        12:intro) cat <<'PROMPT' ;;
Find your own process

From this challenge folder, start sleep for about two minutes.
Put it in the background by ending its command with &. The shell
shows a job number and a process ID (PID).

Use ps to inspect that PID. Save only the PID in process-id.txt.
Read the flag in dispatch.txt and submit it while sleep is still
running. If it finishes first, start another and record its new PID.

Suggested commands
  sleep  ps  man  vim  nvim  cat
PROMPT
        12:hint) printf 'The number in brackets identifies a job in your shell. Look for the other number to identify the process in ps.\n' ;;
        12:answer) cat <<'ANSWER' ;;
  sleep 120 &
  printf '%s\n' "$!" > process-id.txt
  ps -p "$(cat process-id.txt)"

Submit before the timer ends. The shell variable $! gives the PID
of the most recent background command.
ANSWER
        12:debrief) printf 'A PID identifies a running process. & lets the shell accept commands while a process runs in the background. Linux exposes process details under /proc/PID.\n' ;;
        13:intro) cat <<'PROMPT' ;;
Read the system label

Dispatch needs two facts about this VM. Use uname to find the
kernel release and the machine hardware name, also called the
architecture.

Write them in system-report.txt, one value per line. Put the kernel
release first and the architecture second. Read and submit the flag
in dispatch.txt.

Suggested commands
  uname  man  vim  nvim  cat
PROMPT
        13:hint) printf 'The default output from uname gives only one detail. Its manual lists several other pieces of system information you can request.\n' ;;
        13:answer) cat <<'ANSWER' ;;
  uname -r > system-report.txt
  uname -m >> system-report.txt

The first command writes the release. The second appends the architecture.
ANSWER
        13:debrief) printf 'uname reports facts about the running system. The kernel release identifies the kernel version, and the hardware name tells you its machine architecture.\n' ;;
        14:intro) cat <<'PROMPT' ;;
Weigh the parcels

There are several parcel directories under parcels. Use df to identify
the filesystem type that stores this challenge folder. Then use du
to see which parcel directory uses the most disk space.

In storage-report.txt, put the filesystem type on the first line.
Put just the name of the largest parcel directory on the second
line. Read and submit the flag in dispatch.txt.

Suggested commands
  df  du  man  vim  nvim  cat
PROMPT
        14:hint) printf 'A filesystem is the storage the folder sits on. A parcel directory is just one part of that storage. Each command answers a different question.\n' ;;
        14:answer) cat <<'ANSWER' ;;
  df --output=fstype .
  du -s parcels/*

Write the filesystem type shown by df on the first line of
storage-report.txt. Put west, the largest parcel, on the second.
ANSWER
        14:debrief) printf 'df describes a mounted filesystem. du estimates the storage used by files or directories inside it.\n' ;;
        15:intro) cat <<'PROMPT' ;;
Find the loopback

Loopback lets a machine talk to itself. Use ip to inspect the VM's
interfaces and find the IPv4 address for localhost. The address is
shown with a slash and a prefix length, such as 192.0.2.4/24.

In network-report.txt, put the loopback interface name on the first
line. Put its IPv4 address, including the slash and prefix length,
on the second line. Read and submit the flag in dispatch.txt.

Suggested commands
  ip  man  vim  nvim  cat
PROMPT
        15:hint) printf 'Look for the interface that handles traffic internal to this VM. IPv4 addresses use dots between numbers, and the prefix comes after a slash.\n' ;;
        15:answer) cat <<'ANSWER' ;;
  ip -4 address show scope host

Find the line containing 127.0.0.1 and its prefix. In network-report.txt,
put the interface name first, then the IPv4 address and prefix on a
second line. Use the values shown by your VM.
ANSWER
        15:debrief) printf 'ip can inspect interfaces, addresses, and routes. Loopback traffic stays on the same machine. The number after the slash gives the network prefix length.\n' ;;
        16:intro) cat <<'PROMPT' ;;
See what's listening

Read sockets.txt, a captured TCP socket listing. Which listening socket is
bound only to IPv4 loopback? Write its numeric local port in listener.txt.
Use both the State and Local Address columns. Submit the flag in dispatch.txt.

Optional: compare the capture with ss -ltn on your machine.
PROMPT
        16:hint) printf 'Find a LISTEN row whose local address is 127.0.0.1. A wildcard address covers more interfaces.\n' ;;
        16:answer) cat <<'ANSWER' ;;
  cat sockets.txt
  printf '%s\n' 9100 > listener.txt

The wildcard listener accepts connections on other interfaces too. The
ESTAB row is an existing connection.
ANSWER
        16:debrief) printf 'State tells you whether a socket is listening. Its local address tells you which interface addresses it accepts.\n' ;;
        17:intro) cat <<'PROMPT' ;;
Find the latest dispatch warning

Inspect the last 60 entries in logs/dispatch.log. Find the newest
entry with level WARN from the dispatch service. The window also
contains warnings from other services and flags on unrelated entries.

Write just the matching ticket ID, including the TICKET- prefix,
in latest-ticket.txt. Submit the flag on that same line.

Suggested commands
  tail  grep  man  vim  nvim
PROMPT
        17:hint) printf 'Check how to change how many entries you see at the end of the log. Match both the level and the service before comparing timestamps.\n' ;;
        17:answer)
            cat <<'ANSWER'
  tail -n 60 logs/dispatch.log | grep -F ' WARN dispatch '

The last matching line is the newest warning from dispatch.
ANSWER
            printf 'Write %s in latest-ticket.txt.\n' "$latest_dispatch_warning"
            ;;
        17:debrief) printf 'tail limits a log to recent entries. Checking both the log level and the service helps you find the event you actually need.\n' ;;
        18:intro) cat <<'PROMPT' ;;
Identify the mystery parcel

Three parcels have the same .dat extension. Use file to find the
one that contains gzip-compressed data. Write its original filename,
including .dat, in parcel-name.txt.

Read the contents of the gzip parcel and submit its flag.

Suggested commands
  file  gzip  gunzip  man  vim  nvim
PROMPT
        18:hint) printf 'Check the file format first. If gunzip rejects the .dat suffix, try giving a copy of the compressed file a name ending in .gz.\n' ;;
        18:answer) cat <<'ANSWER' ;;
  file parcel-*.dat
  printf '%s\n' parcel-b.dat > parcel-name.txt
  gzip -dc parcel-b.dat

The file command identifies parcel-b.dat as gzip data. The last command
prints its contents while keeping the parcel intact.

To use gunzip instead, copy parcel-b.dat to parcel-b.gz and run
gunzip parcel-b.gz. Read the resulting parcel-b file with cat.
ANSWER
        18:debrief) printf 'file looks at a file’s contents to identify its format. gzip can write the decompressed data to your terminal while keeping the original file.\n' ;;
        19:intro) cat <<'PROMPT' ;;
Set up the staging area

Dispatch needs a staging area. Create a directory named staging.
Inside it, create an empty file called arrival.txt.

Read and submit the flag in dispatch.txt once both are in place.

Suggested commands
  mkdir  touch  ls  cat
PROMPT
        19:hint) printf 'Make the parent directory first. A command can create an empty file inside it without opening an editor.\n' ;;
        19:answer) cat <<'ANSWER' ;;
  mkdir staging
  touch staging/arrival.txt
  ls staging
ANSWER
        19:debrief) printf 'mkdir creates directories. touch creates an empty file if it does not already exist, and updates timestamps if it does.\n' ;;
        20:intro) cat <<'PROMPT' ;;
Copy and rename a manifest

Make a copy of manifest.txt named backup.txt. Leave manifest.txt
in place. Then rename draft.txt to ready.txt in this folder.

Read and submit the flag in dispatch.txt when the files are ready.

Suggested commands
  cp  mv  ls  cat
PROMPT
        20:hint) printf 'Use the operation that leaves the source in place for the backup. Use the operation that changes a name for the draft.\n' ;;
        20:answer) cat <<'ANSWER' ;;
  cp manifest.txt backup.txt
  mv draft.txt ready.txt
ANSWER
        20:debrief) printf 'cp creates a separate copy. mv changes a path by moving a file or renaming it in place.\n' ;;
        21:intro) cat <<'PROMPT' ;;
Clear the scratch space

Remove the two practice files inside scratch. Once the directory
is empty, remove it too. Leave keep.txt in the challenge folder.

Read and submit the flag in dispatch.txt.

Suggested commands
  rm  rmdir  ls  cat
PROMPT
        21:hint) printf 'List the scratch directory first. The command for removing an empty directory works once its files are gone.\n' ;;
        21:answer) cat <<'ANSWER' ;;
  ls scratch
  rm scratch/old-a.txt scratch/old-b.txt
  rmdir scratch
ANSWER
        21:debrief) printf 'rm removes files. rmdir removes empty directories, which gives you a way to check that a folder has been cleared first.\n' ;;
        22:intro) cat <<'PROMPT' ;;
Select the route sheets

The directory delivery batch contains several files. Copy every
file whose name starts with route and ends in .txt into selected.
Keep the original files in place.

Use quotes to handle the space in the directory name and try a
shell wildcard to select all the matching sheets in one command.
Read and submit the flag in dispatch.txt when you're done.

Suggested commands
  cp  ls  cat
PROMPT
        22:hint) printf 'The shell must treat the directory name as one piece and still be able to expand the wildcard in the filename.\n' ;;
        22:answer) cat <<'ANSWER' ;;
  cp "delivery batch"/route*.txt selected/
  ls selected

The quotes protect the space in the directory name. The unquoted
wildcard can expand to all the matching filenames.
ANSWER
        22:debrief) printf 'Quotes keep spaces inside one argument. The shell expands an unquoted wildcard into matching filenames before cp runs.\n' ;;
        23:intro) cat <<'PROMPT' ;;
Write and append a report

Use printf and shell redirection to write Shift opened as the
first line of shift-report.txt. Run a second command to append
Parcel received on the next line.

Check that the report contains both lines in order, then read
and submit the flag in dispatch.txt.

Suggested commands
  printf  cat
PROMPT
        23:hint) printf 'One kind of redirection replaces a file and another adds to its end. Use the second kind after writing the first line.\n' ;;
        23:answer) cat <<'ANSWER' ;;
  printf '%s\n' 'Shift opened' > shift-report.txt
  printf '%s\n' 'Parcel received' >> shift-report.txt
  cat shift-report.txt
ANSWER
        23:debrief) printf 'The shell sends output to a file with > and appends it with >>. Use >> when you want to keep existing lines.\n' ;;
        24:intro) cat <<'PROMPT' ;;
Separate output and errors

Run check-in.sh with Bash. It prints a normal status and a
separate error message.

Save the error in problems.txt. Use tee to save the normal status
in reception.txt and still see it on your terminal. Read and
submit the flag in dispatch.txt when both files are ready.

Suggested commands
  bash  tee  cat
PROMPT
        24:hint) printf 'Normal output and errors travel on separate streams. Send only errors straight to a file, and pass normal output to the command that can display and save it.\n' ;;
        24:answer) cat <<'ANSWER' ;;
  bash check-in.sh 2> problems.txt | tee reception.txt
  cat problems.txt

The shell redirects errors from Bash to problems.txt. The pipe
carries normal output to tee, which displays and saves it.
ANSWER
        24:debrief) printf 'The shell redirects standard error with 2>. tee reads standard input and copies it to both the terminal output and a file.\n' ;;
        25:intro) cat <<'PROMPT' ;;
Compare the manifests

Compare yesterday.txt and today.txt. One parcel's status changed.
Write just that parcel's ID in changed-parcel.txt, then read and
submit the flag in dispatch.txt.

Suggested commands
  diff  cat  vim  nvim
PROMPT
        25:hint) printf 'Look for the old line and its replacement in the comparison. The parcel ID stays the same.\n' ;;
        25:answer) cat <<'ANSWER' ;;
  diff yesterday.txt today.txt
  printf '%s\n' BOX-208 > changed-parcel.txt

The changed lines have the same ID and different statuses.
ANSWER
        25:debrief) printf 'diff compares files line by line. Its usual exit status is 1 when files differ, which is expected when looking for changes.\n' ;;
        26:intro) cat <<'PROMPT' ;;
Find repeated scans

Some IDs in scans.txt appear on consecutive lines. Write one copy
of each repeated group to duplicate-ids.txt, in the order they
appear. Count neighboring repeats only.

Read and submit the flag in dispatch.txt.

Suggested commands
  uniq  cat
PROMPT
        26:hint) printf 'This command compares neighboring lines. Look for an option that shows just the repeated groups.\n' ;;
        26:answer) cat <<'ANSWER' ;;
  uniq -d scans.txt > duplicate-ids.txt
  cat duplicate-ids.txt

The -d option prints one copy from each adjacent group of repeats.
ANSWER
        26:debrief) printf 'uniq compares adjacent lines. Sort the input first if your goal is to group all matching lines, including ones that started far apart.\n' ;;
        27:intro) cat <<'PROMPT' ;;
Rebuild the dispatch packet

The night shift needs two route sheets. The approval log in records
lists decisions for both shifts. Find the revisions approved for
NIGHT and locate those sheets under warehouse.

Create a handoff directory with these three files.
  north-route.txt   A copy of the approved north route sheet
  west-route.txt    A copy of the approved west route sheet
  manifest.txt      The two filenames in alphabetical order, one per line

Use reference-manifest.txt to verify the finished manifest. Leave the
warehouse originals in place. Use bn check to inspect your packet, then
bn submit to finish.
PROMPT
        27:hint) printf 'Check the shift and the decision together. Each approved record gives you a route and revision to look up in the warehouse.\n' ;;
        27:answer) cat <<'ANSWER' ;;
  grep '^NIGHT|APPROVED|' records/approvals.log
  mkdir -p handoff
  while IFS='|' read -r shift decision route rev; do
      if [[ "$shift" == NIGHT && "$decision" == APPROVED ]]; then
          cp "$(find warehouse -type f -name "route-$route-r$rev.txt")" "handoff/$route-route.txt"
      fi
  done < records/approvals.log
  printf '%s\n' north-route.txt west-route.txt > handoff/manifest.txt
  diff -u reference-manifest.txt handoff/manifest.txt

The approved records give the revision numbers. Quotes keep each path
together when the warehouse directory name contains a space. When the
manifests match, diff prints nothing.
ANSWER
        27:debrief) printf 'Matching approval records first narrows the search to two revisions. A manifest lets you verify the final filenames separately from their contents.\n' ;;
        28:intro) cat <<'PROMPT' ;;
Audit the unresolved holds

Audit events.log for dock EAST. Each row records a status change.
Rows are in time order, oldest first. A ticket's last row gives
its current status. EAST-ANNEX is a separate dock.

Optional documentation practice: look up stable sort in info coreutils
or sort --help. Try sort -s -t '|' -k3,3 events.log and inspect a ticket
with two updates. Its equal ticket keys retain their original time order.

Write the ticket IDs whose current status is HOLD in holds.txt.
List each ID once, one per line, in alphabetical order. Use bn check
to review the report, then bn submit to finish.
PROMPT
        28:hint) printf 'A HOLD in an older row can be followed by a release. Keep one status per ticket before you decide what belongs in the report.\n' ;;
        28:answer) cat <<'ANSWER' ;;
  awk -F '|' '$2 == "EAST" { status[$3] = $4 } END { for (id in status) if (status[id] == "HOLD") print id }' events.log | sort > holds.txt

For each EAST ticket, the newest row replaces its earlier status.
The report lists only tickets whose last status is HOLD.
ANSWER
        28:debrief) printf 'When a log records changes over time, a ticket’s last event gives its current state. Group by ticket before filtering by status.\n' ;;
        29:intro) cat <<'PROMPT' ;;
Reconcile the intake

Compare plan.txt, the expected inventory, with intake.txt, the
received scans. Audit only the SOUTH zone. SOUTH-ANNEX is a
separate zone. Repeated scans count as one crate.

Put the IDs of expected crates with no scan in missing.txt.
Put the IDs of scanned crates absent from the plan in extra.txt.
Each report needs one crate ID per line in alphabetical order.
Check both reports with bn check. Use bn submit to finish.
PROMPT
        29:hint) printf 'Make each list comparable first. Use the exact zone, keep just the IDs, and put both lists in the same order.\n' ;;
        29:answer) cat <<'ANSWER' ;;
  grep '^SOUTH|' plan.txt | cut -d '|' -f 2 | sort -u > expected-ids.txt
  grep '^SOUTH|' intake.txt | cut -d '|' -f 2 | sort -u > received-ids.txt
  comm -23 expected-ids.txt received-ids.txt > missing.txt
  comm -13 expected-ids.txt received-ids.txt > extra.txt

comm compares sorted files. Keep the first-only column for missing crates
and the second-only column for unexpected crates.
ANSWER
        29:debrief) printf 'Normalize the two lists before comparing them. Matching the exact zone and removing duplicates isolates the inventory differences.\n' ;;
        30:intro) cat <<'PROMPT' ;;
Recover the verified handoff

Several shifts left notes in recovery.tar.gz. Find the handoff
note for BATCH-044 whose state is VERIFIED. Notes for the same
batch can have other states.

Copy the verified note into recovery/verified-note.txt. In
recovery/summary.txt, record its dock code on the first line and
its pallet count on the second. Include only the values. Keep
the original archive byte-for-byte. Use bn check, then bn submit.
PROMPT
        30:hint) printf 'A matching batch only narrows the search. Check the state on each matching note before copying it.\n' ;;
        30:answer) cat <<'ANSWER' ;;
  tar -xzf recovery.tar.gz
  mkdir -p recovery
  grep -rlFx 'Batch BATCH-044' bundles | while IFS= read -r note; do
      if grep -qx 'State VERIFIED' "$note"; then cp "$note" recovery/verified-note.txt; fi
  done
  awk '$1 == "Dock" || $1 == "Pallets" { print $2 }' recovery/verified-note.txt > recovery/summary.txt
  sha256sum -c .original.sha256
ANSWER
        30:debrief) printf 'Match all the identifying fields before trusting an archived record. The note and summary let another person check your result.\n' ;;
        31:intro) cat <<'PROMPT' ;;
Print the dispatch labels

Use one printf command with a format string and three arguments to
write these names to labels.txt, one per line, in this order.

  north-route.txt
  west-route.txt
  summary.txt

Then use printf to write BOX-007, BOX-024, and BOX-105 to boxes.txt,
one per line. Give printf the numbers 7, 24, and 105 as arguments
and use the format string to add the zero padding.

For example, printf '%s\n' alpha beta prints each word on its own
line because printf reuses the format for the extra argument.
Submit the flag in dispatch.txt when both files are ready.

Suggested commands
  printf  cat  help
PROMPT
        31:hint) printf 'The format is the first argument. Think about how to print a string, then how to give a number a minimum width.\n' ;;
        31:answer) cat <<'ANSWER' ;;
  printf '%s\n' north-route.txt west-route.txt summary.txt > labels.txt
  printf 'BOX-%03d\n' 7 24 105 > boxes.txt
ANSWER
        31:debrief) printf 'printf reuses its format as long as it has arguments to print. %%s formats text, and %%03d prints a number with at least three digits.\n' ;;
        32:intro) cat <<'PROMPT' ;;
Pass arguments to a script

Create label.sh for Bash. It takes a dock as its first argument
and a parcel ID as its second. Print a single line in this form.

  EAST: BOX-042

In a script, $1 and $2 refer to the first and second arguments.
Quote their expansions so a value with spaces stays together.

Put this interpreter line, called a shebang, at the top of label.sh.
It tells Linux which interpreter to use when you run the file directly.

  #!/bin/bash

Test it by asking Bash to read the file.

  bash label.sh EAST BOX-042

Bash can read the file without execute permission. To run the file
directly, grant yourself execute permission and use its relative path.

  chmod u+x label.sh
  ./label.sh EAST BOX-042

The checker runs label.sh directly with different arguments. Submit
the flag in dispatch.txt once both ways of running it work.

Suggested commands
  bash  chmod  printf  vim  nvim
PROMPT
        32:hint) printf 'Bash gives the values after the script name to numbered variables. Pass each value as its own argument to printf.\n' ;;
        32:answer) cat <<'ANSWER' ;;
Save these lines in label.sh.

  #!/bin/bash
  printf '%s: %s\n' "$1" "$2"

Then run these commands at the shell prompt.

  chmod u+x label.sh
  ./label.sh EAST BOX-042
ANSWER
        32:debrief) printf 'A script reads arguments through $1 and $2. Bash can read the script as a file. Running it directly uses the interpreter named in the shebang and requires execute permission.\n' ;;
        33:intro) cat <<'PROMPT' ;;
Make a dispatch decision

Create a Bash script named decision.sh. It receives a status and
a pallet count. Use the rules below to print exactly one word.

  HOLD, with any count                   REVIEW
  READY, with at least 10 pallets         LOAD
  Anything else                          WAIT

Example Bash script

This example is about staffing a desk. Use it as a model for the
structure of decision.sh, then apply the dispatch rules above.

  #!/bin/bash
  if [[ "$1" == morning ]]; then
      printf '%s\n' OPEN
  elif [[ "$1" == evening ]] && (( $2 >= 2 )); then
      printf '%s\n' STAFFED
  else
      printf '%s\n' CLOSED
  fi

The first matching branch runs. [[ ]] compares text, (( )) compares
numbers, and && requires both tests to pass. else handles the remaining
cases, and fi ends the conditional.

If you save the example as desk.sh, this command prints STAFFED.

  bash desk.sh evening 3

Test your own decision.sh with inputs from the dispatch rules.

  bash decision.sh READY 10

That test should print LOAD.
When the script works, submit the flag in dispatch.txt.

Suggested commands
  bash  printf  help  vim  nvim
PROMPT
        33:hint) printf 'Test the rule for HOLD first. The READY rule needs both a matching status and a large enough pallet count.\n' ;;
        33:answer) cat <<'ANSWER' ;;
Put these lines in decision.sh.

  #!/bin/bash
  if [[ "$1" == HOLD ]]; then
      printf '%s\n' REVIEW
  elif [[ "$1" == READY ]] && (( $2 >= 10 )); then
      printf '%s\n' LOAD
  else
      printf '%s\n' WAIT
  fi
ANSWER
        33:debrief) printf 'Bash runs the first matching branch of an if statement. [[ ]] tests text, and (( )) evaluates arithmetic expressions.\n' ;;
        34:intro) cat <<'PROMPT' ;;
Loop over the queue

Write a Bash script named queue.sh that accepts any number of
route labels. Print one line per argument, with Queued: before
the label. Keep the original order. Labels may contain spaces.

Try bash queue.sh east "west gate". It should print the two lines below.
  Queued: east
  Queued: west gate

In Bash, for item in "$@"; do ... done visits each argument
in turn. Run your script, then submit the flag in dispatch.txt.

Suggested commands
  bash  printf  help  vim  nvim
PROMPT
        34:hint) printf 'Your script needs a loop that visits every argument separately, including any argument containing spaces.\n' ;;
        34:answer) cat <<'ANSWER' ;;
Put these lines in queue.sh.

  for label in "$@"; do
      printf 'Queued: %s\n' "$label"
  done
ANSWER
        34:debrief) printf 'In a Bash script, "$@" expands to one word per argument. A for loop can process them in that same order.\n' ;;
        35:intro) cat <<'PROMPT' ;;
Read from a pipeline

Create ready.sh. It receives lines on standard input. Each line
has three fields separated by |, with the dock first, then the
status, then the ID.
Print the ID when the dock is exactly EAST and the status is
exactly READY. Keep the input order and preserve repeated matches.

Try a small example at the shell prompt

  printf '%s\n' 'front desk|Box\A' 'west gate|Box B' |
  while IFS='|' read -r location label; do
      printf '%s -> %s\n' "$location" "$label"
  done

Expected output

  front desk -> Box\A
  west gate -> Box B

What the loop does

  The pipe at the end of the first command sends its two lines
  to the loop as input. read takes one line at a time.

  IFS means Internal Field Separator. IFS='|' tells this read to
  split fields at the literal pipe character. Spaces within a
  field stay together, so front desk goes into location and
  Box\A goes into label.

  -r tells read to preserve backslashes. The loop runs the code
  between do and done after each successful read. It stops when
  there are no more lines.

Loop template for ready.sh

Copy these lines into your script. Replace the line that starts
with : with your condition and a printf command for matching IDs.

  #!/bin/bash
  while IFS='|' read -r dock status id; do
      : # Replace this placeholder with your test and printf.
  done > ready-ids.txt

In this template, read assigns one field to each of dock, status,
and id, in that order. The redirection after done sends all of the
loop's output to ready-ids.txt. Each run replaces the previous
report, even with zero matches.

Run the script and inspect the report.

  cat incoming.txt | bash ready.sh
  cat ready-ids.txt

The checker pipes in different rows and reads the file your script writes.

Submit the flag in dispatch.txt once your script handles the input.

Suggested commands
  bash  read  cat  printf  vim  nvim
PROMPT
        35:hint) printf 'Split each row as you read it. Check the dock and status before printing the ID.\n' ;;
        35:answer) cat <<'ANSWER' ;;
Save these lines in ready.sh.

  #!/bin/bash
  while IFS='|' read -r dock status id; do
      if [[ "$dock" == EAST && "$status" == READY ]]; then
          printf '%s\n' "$id"
      fi
  done > ready-ids.txt

Run these commands at the shell prompt.

  cat incoming.txt | bash ready.sh
  cat ready-ids.txt
ANSWER
        35:debrief) printf 'A pipeline feeds standard input into your script. read splits each row using IFS. A redirection after done sends output from the whole loop to a file.\n' ;;
        36:intro) cat <<'PROMPT' ;;
Remember the last status

Write states.awk for use with updates.txt. Each row has a parcel
ID and a status separated by |, oldest to newest. Print one row
for each parcel whose final status is HOLD or WAIT. Use the same
ID|STATUS format. The rows can be in any order.

Practice example

Save these three rows in example.txt.

  desk|open
  gate|paused
  desk|closed

Save this complete awk program in example.awk.

  { latest[$1] = $2 }
  END {
      for (name in latest) {
          if (latest[name] == "closed") {
              print name "|" latest[name]
          }
      }
  }

Run the example with this exact command.

  awk -F '|' -f example.awk example.txt

It prints this line.

  desk|closed

How the example works

  -F '|' splits each row at the pipe character. $1 is the first
  field and $2 is the second. -f tells awk to read a program file.

  The first block runs once per row. latest is just the name we
  chose for an array. latest["desk"] starts as "open", then the
  third row replaces it with "closed".

  END runs once, after all the rows have been read. The for loop
  visits the keys desk and gate. The if statement prints only
  the key whose saved value is "closed".

Your turn

Use this same structure in states.awk. Change the condition so
it accepts HOLD or WAIT. In awk, || means either condition can pass.
Run your exercise program with this command.

  awk -F '|' -f states.awk updates.txt

Submit the flag in dispatch.txt when your program works on the
sample and on different inputs.

Suggested commands
  awk  vim  nvim
PROMPT
        36:hint) printf 'Use the ID as the key in an array. Assigning a new status to the same key replaces the old one.\n' ;;
        36:answer) cat <<'ANSWER' ;;
Put these lines in states.awk.

  { last[$1] = $2 }
  END {
      for (id in last)
          if (last[id] == "HOLD" || last[id] == "WAIT")
              print id "|" last[id]
  }

Run this command at the shell prompt.

  awk -F '|' -f states.awk updates.txt

last is the name of the array. Each input row updates one entry.
After all updates, END checks the final value for every ID.
ANSWER
        36:debrief) printf 'An awk array can use a parcel ID as a key. Later assignments replace earlier values, and END can report the final values after reading the file.\n' ;;
        37:intro) cat <<'PROMPT' ;;
Build the dispatch timeline

Two scanners recorded the same shift in separate logs under scans.
The rows contain a time, dock, event, and ticket ID, separated by |.

Build timeline.txt from both logs. Keep events for dock WEST with
event LOADED from 08:15 inclusive until 09:00 exclusive. The
WEST-ANNEX dock has its own records.

Write each result as TIME|TICKET. Remove duplicate pairs, then
sort by time and by ticket ID within the same minute. Use bn check to
review the timeline, then bn submit.
PROMPT
        37:hint) printf 'Check both endpoints of the time window and match the dock and event as whole fields. Compare pairs across both logs before you count a row twice.\n' ;;
        37:answer) cat <<'ANSWER' ;;
  awk -F '|' '$1 >= "08:15" && $1 < "09:00" && $2 == "WEST" && $3 == "LOADED" { print $1 "|" $4 }' scans/*.log | sort -u > timeline.txt

Fixed-width times sort in chronological order. Sorting the whole
pair also orders tickets within a minute and removes exact duplicates.
ANSWER
        37:debrief) printf 'Exact field tests isolate the events you need. Sorting the full time and ticket pair orders the report and removes repeat scans without collapsing different tickets in the same minute.\n' ;;
        39:intro) cat <<'PROMPT' ;;
Audit the overnight permission changes

Two tools gained set-user-ID (SUID) overnight. Review the fictional inventory
snapshots yesterday.txt and today.txt (path|owner|mode). A leading 4 in
these four-digit modes marks SUID. Compare by path and consult tickets.txt
(ticket|decision|path|requested mode). Only APPROVED tickets authorize changes.

Write audit.txt with two lines, using the literal labels shown here:
  INVESTIGATE|path|previous mode|new mode
  APPROVED|path|ticket ID

Use the exact paths and four-digit modes from the snapshots. All evidence
is in this folder. Run bn check to review the report, then bn submit.
PROMPT
        39:hint) printf 'Compare the snapshots with diff -u. For each newly marked path, check the ticket decision and requested mode.\n' ;;
        39:answer) cat <<'ANSWER' ;;
  diff -u yesterday.txt today.txt || true
  awk -F'|' 'FILENAME=="yesterday.txt" {old[$1]=$3; next}
    FILENAME=="tickets.txt" {if ($2=="APPROVED") ticket[$3,$4]=$1; next}
    old[$1]=="0755" && $3=="4755" {
      if (($1,$3) in ticket) approved="APPROVED|" $1 "|" ticket[$1,$3]
      else print "INVESTIGATE|" $1 "|" old[$1] "|" $3
    } END {print approved}' yesterday.txt tickets.txt today.txt > audit.txt
ANSWER
        39:debrief) printf 'A snapshot shows current access. Its baseline and approval record explain which change needs investigation.\n' ;;
        40:intro) cat <<'PROMPT' ;;
The shipment that will not import

Start with import.log. Compare rejected.txt with the small accepted sample
example.txt. The importer requires LF after every record, including the
last. Parcel IDs have the form PK- followed by four digits. Destination
names are exact, including repeated spaces.

Produce repaired.txt from rejected.txt. Keep the header, record order,
destinations and original input intact. Use bn check, then bn submit.
PROMPT
        40:hint) printf 'Compare both files with cat -A. Look at the ends of lines and inside the parcel IDs.\n' ;;
        40:answer) cat <<'ANSWER' ;;
  cat -A example.txt rejected.txt
  sed -e 's/\r$//' -e 's/^\(PK-[0-9]*\)\t/\1/' rejected.txt > repaired.txt
ANSWER
        40:debrief) printf 'Inspecting invisible characters lets you fix a field while preserving meaningful whitespace elsewhere.\n' ;;
        38:intro) cat <<'PROMPT' ;;
Apply the approved access

Dispatch has logged permission requests for 64 route files. Your job
is to apply the approved night-shift requests to the actual files.

1. Find the requests to apply.

   Open access.log. Each row has four fields separated by |.

     shift|decision|path|role

   Select rows where the shift is exactly NIGHT and the decision is
   exactly APPROVED. Skip daytime approvals and decisions such as
   NOT_APPROVED.

2. Set the permissions on each selected file.

   The path field tells you which file to change, relative to the
   challenge folder. The role gives the file's final permissions.

     Role         Owner           Group           Others
     REVIEW       Read only       None            None
     TEAM_READ    Read and write  Read only       None
     TEAM_EDIT    Read and write  Read and write  None

   For example, this made-up row gives the owner read and write
   access and the group read access. Everyone else gets no access.

     NIGHT|APPROVED|routes/rack-99/route-999.txt|TEAM_READ

3. Verify and submit.

   Check the final permissions on the files you changed. Leave every
   other file's permissions as they started. The grader checks all
   64 files. Use bn check to review the modes, then bn submit.
PROMPT
        38:hint) printf 'Check the shift and decision columns before applying a mode. A substring search for APPROVED can pick up a different decision.\n' ;;
        38:answer) cat <<'ANSWER' ;;
  awk -F '|' '$1 == "NIGHT" && $2 == "APPROVED" { print $3 "|" $4 }' access.log |
  while IFS='|' read -r path role; do
      if [[ "$role" == REVIEW ]]; then
          chmod 400 -- "$path"
      elif [[ "$role" == TEAM_READ ]]; then
          chmod 640 -- "$path"
      elif [[ "$role" == TEAM_EDIT ]]; then
          chmod 660 -- "$path"
      fi
      stat -c '%a %n' -- "$path"
  done

Filtering exact fields keeps daytime and unapproved requests out of
the loop. The digits in each mode apply to owner, group, and others.
ANSWER
        38:debrief) printf 'An approval is a filter before it is an action. Checking all modes confirms the approved changes and catches unintended changes elsewhere.\n' ;;
    esac
}
