#!/bin/bash

# ctx.sh - Context switcher for managing environment configurations
# This script must be sourced, not executed directly

# Configuration
CTX_CONFIG_DIR="$HOME/.config/ctx"
CTX_CURRENT_FILE="$CTX_CONFIG_DIR/current"
CTX_CONTEXTS_DIR="$CTX_CONFIG_DIR/contexts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
ctx_echo() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to ensure directories exist
ctx_ensure_dirs() {
    mkdir -p "$CTX_CONFIG_DIR" "$CTX_CONTEXTS_DIR"
}

# Function to save current environment variables to context file
ctx_save_context() {
    local context_name="$1"
    
    if [[ -z "$context_name" ]]; then
        ctx_echo "$RED" "Error: Context name is required"
        return 1
    fi
    
    ctx_ensure_dirs
    
    local context_file="$CTX_CONTEXTS_DIR/$context_name"
    
    # Create context file header
    cat > "$context_file" << 'EOF'
#!/bin/bash
# Auto-generated context file
# This file contains environment variables for context: 
EOF
    
    echo "# Context: $context_name" >> "$context_file"
    echo "# Created: $(date)" >> "$context_file"
    echo "" >> "$context_file"
    
    # Save all exported environment variables (excluding some system ones)
    local exclude_vars="PWD|OLDPWD|SHLVL|_|PS1|PS2|TERM|HOME|USER|LOGNAME|SHELL|PATH"
    
    # Get all exported variables and filter them
    export -p | grep -vE "^declare -x ($exclude_vars)=" | \
    sed 's/declare -x /export /' >> "$context_file"
    
    # Make the context file executable
    chmod +x "$context_file"
    
    ctx_echo "$GREEN" "Context '$context_name' saved successfully"
    ctx_echo "$BLUE" "Context file: $context_file"
}

# Function to load context from file
ctx_load_context() {
    local context_name="$1"
    
    if [[ -z "$context_name" ]]; then
        ctx_echo "$RED" "Error: Context name is required"
        return 1
    fi
    
    local context_file="$CTX_CONTEXTS_DIR/$context_name"
    
    if [[ ! -f "$context_file" ]]; then
        ctx_echo "$RED" "Error: Context '$context_name' not found"
        ctx_echo "$YELLOW" "Available contexts:"
        ctx_list_contexts
        return 1
    fi
    
    # Source the context file to load environment variables
    source "$context_file"
    
    # Save current context name
    echo "$context_name" > "$CTX_CURRENT_FILE"
    
    ctx_echo "$GREEN" "Context '$context_name' loaded successfully"
}

# Function to list all available contexts
ctx_list_contexts() {
    ctx_ensure_dirs
    
    if [[ ! -d "$CTX_CONTEXTS_DIR" ]] || [[ -z "$(ls -A "$CTX_CONTEXTS_DIR" 2>/dev/null)" ]]; then
        ctx_echo "$YELLOW" "No contexts found"
        return 0
    fi
    
    local current_context=""
    if [[ -f "$CTX_CURRENT_FILE" ]]; then
        current_context=$(cat "$CTX_CURRENT_FILE")
    fi
    
    ctx_echo "$BLUE" "Available contexts:"
    
    for context_file in "$CTX_CONTEXTS_DIR"/*; do
        if [[ -f "$context_file" ]]; then
            local context_name=$(basename "$context_file")
            if [[ "$context_name" == "$current_context" ]]; then
                ctx_echo "$GREEN" "  * $context_name (current)"
            else
                echo "    $context_name"
            fi
        fi
    done
}

# Function to show current context
ctx_current() {
    if [[ -f "$CTX_CURRENT_FILE" ]]; then
        local current=$(cat "$CTX_CURRENT_FILE")
        ctx_echo "$GREEN" "Current context: $current"
    else
        ctx_echo "$YELLOW" "No current context set"
    fi
}

# Function to delete a context
ctx_delete_context() {
    local context_name="$1"
    
    if [[ -z "$context_name" ]]; then
        ctx_echo "$RED" "Error: Context name is required"
        return 1
    fi
    
    local context_file="$CTX_CONTEXTS_DIR/$context_name"
    
    if [[ ! -f "$context_file" ]]; then
        ctx_echo "$RED" "Error: Context '$context_name' not found"
        return 1
    fi
    
    # Confirm deletion
    read -p "Are you sure you want to delete context '$context_name'? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$context_file"
        
        # If this was the current context, clear it
        if [[ -f "$CTX_CURRENT_FILE" ]]; then
            local current=$(cat "$CTX_CURRENT_FILE")
            if [[ "$current" == "$context_name" ]]; then
                rm -f "$CTX_CURRENT_FILE"
                ctx_echo "$YELLOW" "Cleared current context"
            fi
        fi
        
        ctx_echo "$GREEN" "Context '$context_name' deleted successfully"
    else
        ctx_echo "$YELLOW" "Deletion cancelled"
    fi
}

# Function to show context details
ctx_show_context() {
    local context_name="$1"
    
    if [[ -z "$context_name" ]]; then
        ctx_echo "$RED" "Error: Context name is required"
        return 1
    fi
    
    local context_file="$CTX_CONTEXTS_DIR/$context_name"
    
    if [[ ! -f "$context_file" ]]; then
        ctx_echo "$RED" "Error: Context '$context_name' not found"
        return 1
    fi
    
    ctx_echo "$BLUE" "Context: $context_name"
    ctx_echo "$BLUE" "File: $context_file"
    echo ""
    
    # Show environment variables from context file (excluding comments and empty lines)
    grep -E '^export ' "$context_file" | while IFS= read -r line; do
        echo "  $line"
    done
}

# Function to auto-restore last context on shell startup
ctx_auto_restore() {
    if [[ -f "$CTX_CURRENT_FILE" ]]; then
        local last_context=$(cat "$CTX_CURRENT_FILE")
        if [[ -n "$last_context" ]] && [[ -f "$CTX_CONTEXTS_DIR/$last_context" ]]; then
            ctx_echo "$BLUE" "Auto-restoring context: $last_context"
            ctx_load_context "$last_context"
        fi
    fi
}

# Function to clear current context
ctx_clear() {
    if [[ -f "$CTX_CURRENT_FILE" ]]; then
        rm -f "$CTX_CURRENT_FILE"
        ctx_echo "$GREEN" "Current context cleared"
    else
        ctx_echo "$YELLOW" "No current context to clear"
    fi
}

# Function to set environment variable in current context
ctx_set_var() {
    local var_name="$1"
    local var_value="$2"
    
    if [[ -z "$var_name" ]]; then
        ctx_echo "$RED" "Error: Variable name is required"
        ctx_echo "$YELLOW" "Usage: ctx set <VAR_NAME> <value>"
        return 1
    fi
    
    # Set the variable in current environment
    export "$var_name"="$var_value"
    
    # If there's a current context, update its file
    if [[ -f "$CTX_CURRENT_FILE" ]]; then
        local current_context=$(cat "$CTX_CURRENT_FILE")
        if [[ -n "$current_context" ]]; then
            ctx_save_context "$current_context"
            ctx_echo "$GREEN" "Variable '$var_name' set and saved to context '$current_context'"
        else
            ctx_echo "$GREEN" "Variable '$var_name' set in current environment"
        fi
    else
        ctx_echo "$GREEN" "Variable '$var_name' set in current environment"
        ctx_echo "$YELLOW" "Tip: Save to a context with 'ctx save <context_name>' to persist"
    fi
}

# Function to unset environment variable from current context
ctx_unset_var() {
    local var_name="$1"
    
    if [[ -z "$var_name" ]]; then
        ctx_echo "$RED" "Error: Variable name is required"
        ctx_echo "$YELLOW" "Usage: ctx unset <VAR_NAME>"
        return 1
    fi
    
    # Unset the variable from current environment
    unset "$var_name"
    
    # If there's a current context, update its file
    if [[ -f "$CTX_CURRENT_FILE" ]]; then
        local current_context=$(cat "$CTX_CURRENT_FILE")
        if [[ -n "$current_context" ]]; then
            ctx_save_context "$current_context"
            ctx_echo "$GREEN" "Variable '$var_name' unset and removed from context '$current_context'"
        else
            ctx_echo "$GREEN" "Variable '$var_name' unset from current environment"
        fi
    else
        ctx_echo "$GREEN" "Variable '$var_name' unset from current environment"
    fi
}

# Main function to handle commands
ctx() {
    local command="$1"
    shift
    
    case "$command" in
        "save"|"s")
            ctx_save_context "$@"
            ;;
        "load"|"l"|"use"|"u")
            ctx_load_context "$@"
            ;;
        "list"|"ls")
            ctx_list_contexts
            ;;
        "current"|"c")
            ctx_current
            ;;
        "delete"|"del"|"rm")
            ctx_delete_context "$@"
            ;;
        "show"|"describe"|"desc")
            ctx_show_context "$@"
            ;;
        "clear")
            ctx_clear
            ;;
        "set")
            ctx_set_var "$@"
            ;;
        "unset")
            ctx_unset_var "$@"
            ;;
        "auto-restore")
            ctx_auto_restore
            ;;
        "help"|"h"|"")
            cat << 'EOF'
ctx - Context switcher for environment variables

USAGE:
    ctx <command> [arguments]

COMMANDS:
    save <name>         Save current environment to context
    load <name>         Load context and set as current
    list                List all available contexts
    current             Show current context
    delete <name>       Delete a context
    show <name>         Show context variables
    clear               Clear current context
    set <var> <value>   Set environment variable in current context
    unset <var>         Unset environment variable from current context
    auto-restore        Restore last context (for shell startup)
    help                Show this help message

ALIASES:
    save: s             load: l, use, u
    list: ls            current: c
    delete: del, rm     show: describe, desc
    help: h

EXAMPLES:
    ctx save dev                    # Save current environment as 'dev' context
    ctx load prod                   # Load 'prod' context
    ctx set DATABASE_URL "postgres://localhost/mydb"
    ctx list                        # List all contexts
    ctx current                     # Show current context
    ctx show dev                    # Show variables in 'dev' context

SETUP:
    Add to your ~/.bashrc or ~/.zshrc:
        alias ctx='source /path/to/ctx.sh && ctx'
        # Optional: auto-restore last context on shell startup
        source /path/to/ctx.sh && ctx auto-restore

NOTES:
    - This script must be sourced, not executed
    - Contexts are saved in ~/.config/ctx/
    - Use 'ctx auto-restore' in shell startup to restore last context
EOF
            ;;
        *)
            ctx_echo "$RED" "Unknown command: $command"
            ctx_echo "$YELLOW" "Use 'ctx help' for usage information"
            return 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ctx_echo "$RED" "Error: This script must be sourced, not executed directly"
    ctx_echo "$YELLOW" "Usage: source ctx.sh"
    ctx_echo "$YELLOW" "Or add this to your ~/.bashrc:"
    ctx_echo "$BLUE" "    alias ctx='source /path/to/ctx.sh && ctx'"
    exit 1
fi

# If no arguments provided when sourcing, just define the functions
if [[ $# -eq 0 ]]; then
    return 0
fi

# If arguments provided, execute the ctx function
ctx "$@"