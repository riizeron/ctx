#!/bin/bash

# Configuration switcher script with context tracking

set -euo pipefail

CONFIG_BASE_DIR="$HOME/.config/ctx"
CURRENT_CONTEXT_FILE="$HOME/.config/ctx/.current"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_color() {
    local color=$1; shift
    echo -e "${color}$*${NC}"
}

usage() {
    local script_name
    script_name=$(basename "$0")
    cat << EOF
Usage: $script_name <command> [<category> [<config_name>]]

Commands:
    list <category>         - List all categories or configurations in category
    use <category> [config] - Activate specific config or interactive select
    show [category]         - Show current context for category or all categories

Examples:
    $script_name list              - List all categories
    $script_name list abc          - List configurations in 'abc'
    $script_name use abc cfg1      - Activate 'cfg1' in 'abc'
    $script_name use abc           - Interactive select for 'abc'
    $script_name show asd          - Show current context for 'asd'
    $script_name show              - Show current contexts for all categories
EOF
}

check_category() {
    local category=$1
    if [[ ! -d "$CONFIG_BASE_DIR/$category" ]]; then
        print_color $RED "Category '$category' does not exist."
        exit 1
    fi
}

get_configurations() {
    local category=$1
    local configs=()
    local dir
    for dir in "$CONFIG_BASE_DIR/$category"/*/; do
        [[ -f "${dir}activate" ]] && configs+=("$(basename "$dir")")
    done
    printf '%s\n' "${configs[@]}" | sort
}

cmd_list() {
    if [[ -z ${1-} ]]; then
        print_color $CYAN "Available categories:"
        for dir in "$CONFIG_BASE_DIR"/*/; do
            echo "  $(basename "$dir")"
        done
    else
        local category=$1
        check_category "$category"
        print_color $CYAN "Configurations in '$category':"
        get_configurations "$category" || print_color $YELLOW "No configurations found."
    fi
}

activate_configuration() {
    local category=$1
    local cfg=$2
    local file="$CONFIG_BASE_DIR/$category/$cfg/activate"
    if [[ ! -f "$file" ]]; then
        print_color $RED "Config '$cfg' not found in '$category'."
        exit 1
    fi
    print_color $GREEN "Activating $category/$cfg..."
    source "$file"
    # Record current context
    grep -v "^$category=" "$CURRENT_CONTEXT_FILE" 2>/dev/null > "${CURRENT_CONTEXT_FILE}.tmp" || true
    echo "$category=$cfg" >> "${CURRENT_CONTEXT_FILE}.tmp"
    mv "${CURRENT_CONTEXT_FILE}.tmp" "$CURRENT_CONTEXT_FILE"
    print_color $GREEN "Activated."
}

cmd_show() {
    if [[ -z ${1-} ]]; then
        print_color $CYAN "Current contexts for all categories:"
        if [[ ! -f "$CURRENT_CONTEXT_FILE" ]]; then
            print_color $YELLOW "No contexts set."
            return
        fi
        cat "$CURRENT_CONTEXT_FILE"
    else
        local category=$1
        if grep -q "^$category=" "$CURRENT_CONTEXT_FILE" 2>/dev/null; then
            grep "^$category=" "$CURRENT_CONTEXT_FILE"
        else
            print_color $YELLOW "No context set for '$category'."
        fi
    fi
}

cmd_use_interactive() {
    local category=$1
    local configs=()
    while IFS= read -r cfg; do
        configs+=("$cfg")
    done < <(get_configurations "$category")

    if (( ${#configs[@]} == 0 )); then
        print_color $YELLOW "No configurations found in '$category'."
        exit 1
    fi

    print_color $CYAN "Select configuration for '$category':"
    PS3='Enter number> '
    select choice in "${configs[@]}"; do
        if [[ -n $choice ]]; then
            activate_configuration "$category" "$choice"
            break
        else
            print_color $RED "Invalid selection."
        fi
    done
}

if (( $# == 0 )); then
    usage
    exit 1
fi

case "$1" in
    list)
        cmd_list "${2-}"
        ;;
    use)
        if [[ -z ${2-} ]]; then
            print_color $RED "Category is required."
            usage
            exit 1
        fi
        check_category "$2"
        if [[ -n ${3-} ]]; then
            activate_configuration "$2" "$3"
        else
            cmd_use_interactive "$2"
        fi
        ;;
    show)
        cmd_show "${2-}"
        ;;
    *)
        print_color $RED "Unknown command '$1'."
        usage
        exit 1
        ;;
esac
