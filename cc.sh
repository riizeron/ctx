# Configuration switcher script with context tracking
# Compatible with both bash and zsh
# This file should be sourced in your shell profile

# Configuration
CTX_CONFIG_BASE_DIR="$HOME/.config/ctx"
CTX_CURRENT_CONTEXT_FILE="$HOME/.config/ctx/.current"

# Ensure configuration directory exists
mkdir -p "$CTX_CONFIG_BASE_DIR"

# Colors for output
if [[ -t 1 ]]; then  # Only use colors if stdout is a terminal
    CTX_RED='\033[0;31m'
    CTX_GREEN='\033[0;32m'
    CTX_YELLOW='\033[1;33m'
    CTX_BLUE='\033[0;34m'
    CTX_CYAN='\033[0;36m'
    CTX_NC='\033[0m' # No Color
else
    CTX_RED=''
    CTX_GREEN=''
    CTX_YELLOW=''
    CTX_BLUE=''
    CTX_CYAN=''
    CTX_NC=''
fi

# Helper function to print colored output
ctx_print_color() {
    local color=$1; shift
    echo -e "${color}$*${CTX_NC}"
}

# Function to display usage information
ctx_usage() {
    cat << EOF
Usage: ctx <command> [<category> [<config_name>]]

Commands:
    list <category>         - List all categories or configurations in category
    use <category> [config] - Activate specific config or interactive select
    show [category]         - Show current context for category or all categories
    init                    - Initialize context switcher (run once after installation)

Examples:
    ctx list                - List all categories
    ctx list abc            - List configurations in 'abc'
    ctx use abc cfg1        - Activate 'cfg1' in 'abc'
    ctx use abc             - Interactive select for 'abc'
    ctx show asd            - Show current context for 'asd'
    ctx show                - Show current contexts for all categories

Installation:
    1. Source this file in your shell profile (~/.bashrc or ~/.zshrc):
       echo 'source /path/to/ctx-switcher.sh' >> ~/.bashrc  # or ~/.zshrc
    2. Run 'ctx init' to set up automatic context restoration
    3. Restart your shell or run 'source ~/.bashrc' (or ~/.zshrc)

Configuration Structure:
    ~/.config/ctx/
    ├── category1/
    │   ├── config1/
    │   │   └── activate     # Script that sets environment variables
    │   └── config2/
    │       └── activate
    └── category2/
        └── config3/
            └── activate

Example activate script:
    export DATABASE_URL="postgresql://localhost:5432/mydb"
    export API_KEY="your-api-key"
    export ENV="development"
EOF
}

# Function to check if category exists
ctx_check_category() {
    local category=$1
    if [[ ! -d "$CTX_CONFIG_BASE_DIR/$category" ]]; then
        ctx_print_color $CTX_RED "Category '$category' does not exist."
        return 1
    fi
    return 0
}

# Function to get all configurations in a category
ctx_get_configurations() {
    local category=$1
    local configs=()
    local dir
    
    if [[ ! -d "$CTX_CONFIG_BASE_DIR/$category" ]]; then
        return 1
    fi
    
    for dir in "$CTX_CONFIG_BASE_DIR/$category"/*/; do
        if [[ -d "$dir" && -f "${dir}activate" ]]; then
            configs+=("$(basename "$dir")")
        fi
    done
    
    if [[ ${#configs[@]} -gt 0 ]]; then
        printf '%s\n' "${configs[@]}" | sort
        return 0
    else
        return 1
    fi
}

# Function to list categories or configurations
ctx_list() {
    if [[ -z ${1-} ]]; then
        ctx_print_color $CTX_CYAN "Available categories:"
        if [[ -d "$CTX_CONFIG_BASE_DIR" ]]; then
            for dir in "$CTX_CONFIG_BASE_DIR"/*/; do
                if [[ -d "$dir" ]]; then
                    echo "  $(basename "$dir")"
                fi
            done
        else
            ctx_print_color $CTX_YELLOW "No categories found. Create your first category with configurations."
        fi
    else
        local category=$1
        if ! ctx_check_category "$category"; then
            return 1
        fi
        
        ctx_print_color $CTX_CYAN "Configurations in '$category':"
        if ! ctx_get_configurations "$category"; then
            ctx_print_color $CTX_YELLOW "No configurations found in '$category'."
            return 1
        fi
    fi
}

# Function to activate a specific configuration
ctx_activate_configuration() {
    local category=$1
    local cfg=$2
    local file="$CTX_CONFIG_BASE_DIR/$category/$cfg/activate"
    
    if [[ ! -f "$file" ]]; then
        ctx_print_color $CTX_RED "Config '$cfg' not found in '$category'."
        return 1
    fi
    
    ctx_print_color $CTX_GREEN "Activating $category/$cfg..."
    
    # Source the activation script in the current shell
    if source "$file"; then
        # Record current context
        local temp_file="${CTX_CURRENT_CONTEXT_FILE}.tmp.$$"
        
        # Remove existing entry for this category and add new one
        if [[ -f "$CTX_CURRENT_CONTEXT_FILE" ]]; then
            grep -v "^$category=" "$CTX_CURRENT_CONTEXT_FILE" 2>/dev/null > "$temp_file" || true
        fi
        echo "$category=$cfg" >> "$temp_file"
        mv "$temp_file" "$CTX_CURRENT_CONTEXT_FILE"
        
        ctx_print_color $CTX_GREEN "✓ Context activated successfully"
        return 0
    else
        ctx_print_color $CTX_RED "✗ Failed to activate configuration"
        return 1
    fi
}

# Function to show current contexts
ctx_show() {
    if [[ -z ${1-} ]]; then
        ctx_print_color $CTX_CYAN "Current contexts:"
        if [[ ! -f "$CTX_CURRENT_CONTEXT_FILE" ]]; then
            ctx_print_color $CTX_YELLOW "No contexts set."
            return 0
        fi
        
        while IFS='=' read -r category config; do
            if [[ -n "$category" && -n "$config" ]]; then
                ctx_print_color $CTX_GREEN "  $category → $config"
            fi
        done < "$CTX_CURRENT_CONTEXT_FILE"
    else
        local category=$1
        if [[ -f "$CTX_CURRENT_CONTEXT_FILE" ]] && grep -q "^$category=" "$CTX_CURRENT_CONTEXT_FILE" 2>/dev/null; then
            local current_config
            current_config=$(grep "^$category=" "$CTX_CURRENT_CONTEXT_FILE" | cut -d'=' -f2-)
            ctx_print_color $CTX_GREEN "$category → $current_config"
        else
            ctx_print_color $CTX_YELLOW "No context set for '$category'."
        fi
    fi
}

# Function for interactive configuration selection
ctx_use_interactive() {
    local category=$1
    local configs=()
    
    # Read configurations into array
    while IFS= read -r cfg; do
        configs+=("$cfg")
    done < <(ctx_get_configurations "$category")

    if (( ${#configs[@]} == 0 )); then
        ctx_print_color $CTX_YELLOW "No configurations found in '$category'."
        return 1
    fi

    ctx_print_color $CTX_CYAN "Select configuration for '$category':"
    
    # Display options
    local i
    for i in "${!configs[@]}"; do
        echo "  $((i+1))) ${configs[i]}"
    done
    
    # Get user selection
    local choice
    while true; do
        echo -n "Enter number (1-${#configs[@]}): "
        read choice
        
        # Validate input
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#configs[@]} )); then
            ctx_activate_configuration "$category" "${configs[$((choice-1))]}"
            return $?
        else
            ctx_print_color $CTX_RED "Invalid selection. Please enter a number between 1 and ${#configs[@]}."
        fi
    done
}

# Function to restore context on shell startup
ctx_restore_context() {
    if [[ ! -f "$CTX_CURRENT_CONTEXT_FILE" ]]; then
        return 0
    fi
    
    local restored=0
    while IFS='=' read -r category config; do
        if [[ -n "$category" && -n "$config" ]]; then
            local file="$CTX_CONFIG_BASE_DIR/$category/$config/activate"
            if [[ -f "$file" ]]; then
                source "$file" 2>/dev/null && ((restored++))
            fi
        fi
    done < "$CTX_CURRENT_CONTEXT_FILE"
    
    if (( restored > 0 )); then
        ctx_print_color $CTX_GREEN "✓ Restored $restored context(s)"
    fi
}

# Function to initialize context switcher
ctx_init() {
    ctx_print_color $CTX_CYAN "Initializing context switcher..."
    
    # Detect shell type
    local shell_rc=""
    local shell_name=""
    
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
        shell_name="zsh"
    elif [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
        shell_name="bash"
    else
        ctx_print_color $CTX_YELLOW "Unknown shell. Please manually add context restoration to your shell profile."
        return 1
    fi
    
    # Check if auto-restore is already configured
    if grep -q "ctx_restore_context" "$shell_rc" 2>/dev/null; then
        ctx_print_color $CTX_YELLOW "Context auto-restore already configured in $shell_rc"
    else
        echo "" >> "$shell_rc"
        echo "# Context switcher auto-restore" >> "$shell_rc"
        echo "ctx_restore_context 2>/dev/null" >> "$shell_rc"
        ctx_print_color $CTX_GREEN "✓ Added context auto-restore to $shell_rc"
    fi
    
    # Create example configuration if none exists
    if [[ ! -d "$CTX_CONFIG_BASE_DIR" ]] || [[ -z "$(ls -A "$CTX_CONFIG_BASE_DIR" 2>/dev/null)" ]]; then
        local example_dir="$CTX_CONFIG_BASE_DIR/example/demo"
        mkdir -p "$example_dir"
        
        cat > "$example_dir/activate" << 'EOF'
#!/bin/bash
# Example activation script
export CTX_DEMO_VAR="This is a demo context"
export CTX_ENVIRONMENT="demo"
echo "Demo context activated! Try: echo \$CTX_DEMO_VAR"
EOF
        chmod +x "$example_dir/activate"
        
        ctx_print_color $CTX_GREEN "✓ Created example configuration at $example_dir"
        ctx_print_color $CTX_YELLOW "Try: ctx use example demo"
    fi
    
    ctx_print_color $CTX_GREEN "✓ Initialization complete!"
    ctx_print_color $CTX_CYAN "Restart your shell or run 'source $shell_rc' to enable auto-restore"
}

# Main function
cc() {
    if (( $# == 0 )); then
        ctx_usage
        return 1
    fi

    case "$1" in
        list)
            ctx_list "${2-}"
            ;;
        use)
            if [[ -z ${2-} ]]; then
                ctx_print_color $CTX_RED "Category is required."
                ctx_usage
                return 1
            fi
            
            if ! ctx_check_category "$2"; then
                return 1
            fi
            
            if [[ -n ${3-} ]]; then
                ctx_activate_configuration "$2" "$3"
            else
                ctx_use_interactive "$2"
            fi
            ;;
        show)
            ctx_show "${2-}"
            ;;
        init)
            ctx_init
            ;;
        help|-h|--help)
            ctx_usage
            ;;
        *)
            ctx_print_color $CTX_RED "Unknown command '$1'."
            ctx_usage
            return 1
            ;;
    esac
}

# Auto-complete function for bash
if [[ -n "$BASH_VERSION" ]]; then
    _ctx_completion() {
        local cur prev opts
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"

        case $COMP_CWORD in
            1)
                opts="list use show init help"
                COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
                ;;
            2)
                case $prev in
                    list|use|show)
                        if [[ -d "$CTX_CONFIG_BASE_DIR" ]]; then
                            local categories
                            categories=$(find "$CTX_CONFIG_BASE_DIR" -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | grep -v "^ctx$" | sort)
                            COMPREPLY=($(compgen -W "${categories}" -- ${cur}))
                        fi
                        ;;
                esac
                ;;
            3)
                case "${COMP_WORDS[1]}" in
                    use)
                        local category="${COMP_WORDS[2]}"
                        if [[ -d "$CTX_CONFIG_BASE_DIR/$category" ]]; then
                            local configs
                            configs=$(ctx_get_configurations "$category" 2>/dev/null)
                            COMPREPLY=($(compgen -W "${configs}" -- ${cur}))
                        fi
                        ;;
                esac
                ;;
        esac
    }
    complete -F _ctx_completion ctx
fi

# Auto-complete function for zsh
if [[ -n "$ZSH_VERSION" ]]; then
    _ctx_zsh_completion() {
        local context state line
        
        _arguments \
            '1:command:(list use show init help)' \
            '2:category:_ctx_categories' \
            '3:config:_ctx_configs'
    }
    
    _ctx_categories() {
        if [[ -d "$CTX_CONFIG_BASE_DIR" ]]; then
            local categories
            categories=(${(@f)"$(find "$CTX_CONFIG_BASE_DIR" -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | grep -v "^ctx$" | sort)"})
            _describe 'categories' categories
        fi
    }
    
    _ctx_configs() {
        local category="${words[3]}"
        if [[ -n "$category" && -d "$CTX_CONFIG_BASE_DIR/$category" ]]; then
            local configs
            configs=(${(@f)"$(ctx_get_configurations "$category" 2>/dev/null)"})
            _describe 'configurations' configs
        fi
    }
    
    compdef _ctx_zsh_completion ctx
fi

# Export the main function so it's available in the current shell
export -f ctx 2>/dev/null || true  # bash
typeset -gf ctx 2>/dev/null || true  # zsh

# Welcome message on first load
if [[ -z "$CTX_LOADED" ]]; then
    export CTX_LOADED=1
    if [[ -f "$CTX_CURRENT_CONTEXT_FILE" ]]; then
        ctx_restore_context
    fi
fi