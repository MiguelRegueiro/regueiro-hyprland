#!/bin/sh

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    else
        echo "Package installation needs root access; install sudo or doas, or run as root." >&2
        return 1
    fi
}

package_is_installed() {
    manager=$1
    package=$2
    case "$manager" in
        arch) pacman -Qq "$package" >/dev/null 2>&1 ;;
        debian|debian-backports) dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -Fx installed >/dev/null ;;
        fedora) rpm -q "$package" >/dev/null 2>&1 ;;
        freebsd) pkg info -e "$package" >/dev/null 2>&1 ;;
        void) xbps-query -p pkgver "$package" >/dev/null 2>&1 ;;
        *) echo "Unknown package manager for ownership tracking: $manager" >&2; return 2 ;;
    esac
}

package_query_command() {
    case "$1" in
        arch) printf '%s\n' pacman ;;
        debian|debian-backports) printf '%s\n' dpkg-query ;;
        fedora) printf '%s\n' rpm ;;
        freebsd) printf '%s\n' pkg ;;
        void) printf '%s\n' xbps-query ;;
        *) return 2 ;;
    esac
}

tracked_install() (
    manager=$1
    shift
    [ "$#" -gt 0 ] || return 0

    query_command=$(package_query_command "$manager") || {
        echo "Unknown package manager for ownership tracking: $manager" >&2
        return 2
    }
    if ! command -v "$query_command" >/dev/null 2>&1; then
        echo "Cannot safely track package ownership: $query_command is unavailable." >&2
        return 1
    fi

    for package do
        case "$package" in
            -*|*' '*)
                echo "Invalid package name for ownership tracking: $package" >&2
                return 2
                ;;
        esac
    done

    umask 077
    before_file=$(mktemp "${TMPDIR:-/tmp}/triton-packages-before.XXXXXX")
    newly_installed_file=$(mktemp "${TMPDIR:-/tmp}/triton-packages-new.XXXXXX")
    trap 'rm -f "$before_file" "$newly_installed_file"' EXIT HUP INT TERM

    for package do
        if package_is_installed "$manager" "$package"; then
            printf '%s\n' "$package" >>"$before_file"
        fi
    done

    install_status=0
    case "$manager" in
        arch) run_as_root pacman -S --needed "$@" || install_status=$? ;;
        debian) run_as_root apt install "$@" || install_status=$? ;;
        debian-backports) run_as_root apt install -t trixie-backports "$@" || install_status=$? ;;
        fedora) run_as_root dnf install "$@" || install_status=$? ;;
        freebsd) run_as_root pkg install "$@" || install_status=$? ;;
        void) run_as_root xbps-install -S "$@" || install_status=$? ;;
        *) echo "Unknown package manager for tracked installation: $manager" >&2; return 2 ;;
    esac

    for package do
        if ! grep -Fx "$package" "$before_file" >/dev/null 2>&1 && package_is_installed "$manager" "$package"; then
            printf '%s\n' "$package" >>"$newly_installed_file"
        fi
    done

    if [ ! -s "$newly_installed_file" ]; then
        return "$install_status"
    fi
    state_dir=${TRITON_PACKAGE_STATE_DIR:-$HOME/.local/state/triton-desktop/packages}
    mkdir -p "$state_dir"
    manifest=$state_dir/$manager.list
    merged_file=$(mktemp "$state_dir/.${manager}.XXXXXX")
    if [ -f "$manifest" ]; then cat "$manifest" >"$merged_file"; fi
    while IFS= read -r package; do
        if ! grep -Fx "$package" "$merged_file" >/dev/null 2>&1; then
            printf '%s\n' "$package" >>"$merged_file"
        fi
    done <"$newly_installed_file"
    mv "$merged_file" "$manifest"
    return "$install_status"
)

install_catalog() (
    manager=$1
    catalog=$2
    selection=$3
    shift 3
    if [ ! -r "$catalog" ]; then
        echo "Package catalog is missing or unreadable: $catalog" >&2
        return 1
    fi
    if [ "$selection" != all ] && [ "$selection" != bootstrap ]; then
        case "$selection" in
            ,*|*,|*,,*)
                echo "Invalid package group selection: $selection" >&2
                return 2
                ;;
        esac
        available_groups=$(awk -F '\t' 'NF >= 2 && $1 !~ /^#/ && $1 != "" { print $1 }' "$catalog" | sort -u)
        remaining=$selection
        while [ -n "$remaining" ]; do
            group=${remaining%%,*}
            case "$group" in
                ''|*[!a-z0-9_-]*)
                    echo "Invalid package group selection: $selection" >&2
                    return 2
                    ;;
            esac
            if ! printf '%s\n' "$available_groups" | grep -Fx "$group" >/dev/null; then
                echo "Unknown package group '$group' for this platform. Available groups: $(printf '%s\n' "$available_groups" | tr '\n' ' ')" >&2
                return 2
            fi
            if [ "$remaining" = "$group" ]; then
                remaining=
            else
                remaining=${remaining#*,}
            fi
        done
    fi
    packages=$(awk -F '\t' -v selection="$selection" '
        BEGIN { count = split(selection, requested, ","); for (i = 1; i <= count; i++) selected[requested[i]] = 1 }
        NF >= 2 && $1 !~ /^#/ && $1 != "" && $2 != "" &&
            (selection == "all" || selection == "bootstrap" && $1 == "base" ||
                selection != "bootstrap" && ($1 == "base" || $1 == "core" || selected[$1])) { print $2 }
    ' "$catalog")
    set -f
    set -- $packages "$@"
    tracked_install "$manager" "$@"
)

select_catalog_groups() (
    catalog=$1
    groups_file=$(mktemp "${TMPDIR:-/tmp}/triton-groups.XXXXXX")
    trap 'rm -f "$groups_file"' EXIT HUP INT TERM
    awk -F '\t' 'NF >= 2 && $1 != "base" && $1 != "core" && $1 !~ /^#/ && $1 != "" { print $1 }' "$catalog" | sort -u >"$groups_file"

    printf '%s\n' 'Optional package groups (base and core are always included):' >&2
    index=1
    while IFS= read -r group; do
        printf '  %s) %s\n' "$index" "$group" >&2
        index=$((index + 1))
    done <"$groups_file"
    printf '%s\n' 'Enter numbers separated by commas; Enter selects the full recommended set, or type none.' >&2
    printf 'Selection: ' >&2
    answer=
    IFS= read -r answer || {
        echo 'Could not read an interactive package-group selection.' >&2
        return 1
    }
    case "$answer" in
        '') printf '%s\n' all; return 0 ;;
        all) printf '%s\n' all; return 0 ;;
        none) printf '%s\n' core; return 0 ;;
    esac

    case "$answer" in
        ,*|*,|*,,*|*[!0-9,]*)
            echo 'Enter a comma-separated list of menu numbers, all, or none.' >&2
            return 2
            ;;
    esac

    selected=
    remaining=$answer
    while [ -n "$remaining" ]; do
        number=${remaining%%,*}
        group=$(sed -n "${number}p" "$groups_file")
        if [ -z "$group" ]; then
            echo "No optional package group has menu number $number." >&2
            return 2
        fi
        case ",$selected," in
            *,$group,*) ;;
            *)
                if [ -n "$selected" ]; then selected=$selected,$group; else selected=$group; fi
                ;;
        esac
        if [ "$remaining" = "$number" ]; then remaining=; else remaining=${remaining#*,}; fi
    done
    printf '%s\n' "$selected"
)
