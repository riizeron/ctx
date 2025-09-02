# Installation script for ctx configuration switcher

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_color() {
    local color=$1; shift
    printf "%b\n" "${color}$*${NC}"
}

# Installation directories
INSTALL_DIR="$HOME/.local/opt/ctx"
BIN_DIR="$HOME/.local/bin"
SCRIPT_NAME="ctx.sh"
SYMLINK_NAME="ctx"


# Function to detect current shell
detect_shell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "bash"
    else
        # Fallback to $SHELL environment variable
        basename "${SHELL:-/bin/bash}"
    fi
}

# Function to check if PATH contains directory
path_contains() {
    local dir=$1
    [[ ":$PATH:" == *":$dir:"* ]]
}

# Function to add directory to PATH in shell config
add_to_path() {
    local shell_config=$1
    local dir=$2
    
    # Create config file if it doesn't exist
    touch "$shell_config"
    
    # Check if PATH export already exists
    if grep -q "export PATH.*$dir" "$shell_config" 2>/dev/null; then
        print_color $YELLOW "PATH entry already exists in $shell_config"
        return 0
    fi
    
    # Add PATH export
    echo "" >> "$shell_config"
    echo "# Added by ctx installer" >> "$shell_config"
    echo "export PATH=\"$dir:\$PATH\"" >> "$shell_config"
    
    print_color $GREEN "Added $dir to PATH in $shell_config"
}

# Function to update PATH in current session
update_current_path() {
    local dir=$1
    if ! path_contains "$dir"; then
        export PATH="$dir:$PATH"
        print_color $GREEN "Updated PATH for current session"
    fi
}

# Function to setup PATH
setup_path() {
    local current_shell
    current_shell=$(detect_shell)
    
    if path_contains "$BIN_DIR"; then
        print_color $GREEN "$BIN_DIR is already in PATH"
        return 0
    fi
    
    print_color $YELLOW "$BIN_DIR is not in PATH. Adding..."
    
    case "$current_shell" in
        "zsh")
            if [[ -f "$HOME/.zshenv" ]] || [[ ! -f "$HOME/.zshrc" ]]; then
                add_to_path "$HOME/.zshenv" "$BIN_DIR"
            else
                add_to_path "$HOME/.zshrc" "$BIN_DIR"
            fi
            ;;
        "bash")
            if [[ -f "$HOME/.bash_profile" ]]; then
                add_to_path "$HOME/.bash_profile" "$BIN_DIR"
            else
                add_to_path "$HOME/.bashrc" "$BIN_DIR"
            fi
            ;;
        *)
            # Try to add to .profile as fallback
            add_to_path "$HOME/.profile" "$BIN_DIR"
            ;;
    esac
    
    # Update PATH for current session
    update_current_path "$BIN_DIR"
}

# Function to download ctx script
download_ctx() {
    local github_url="https://api.github.com/repos/riizeron/ctx/releases/latest"
    
    print_color $BLUE "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # Check if we have the script in current directory
    if [[ -f "./ctx" ]]; then
        print_color $BLUE "Found ctx script in current directory, copying..."
        rsync -a "./ctx" "$INSTALL_DIR/$SCRIPT_NAME"
    elif [[ -f "./ctx.sh" ]]; then
        print_color $BLUE "Found ctx.sh script in current directory, copying..."
        rsync -a "./ctx.sh" "$INSTALL_DIR/$SCRIPT_NAME"
    else
        local tarball_url
        tarball_url=$(curl -fsSL "$github_url" \
            | grep '"tarball_url"' | head -1 | cut -d '"' -f 4)

        if [[ -z "$tarball_url" ]]; then
            print_color $RED "Error: Unable to fetch latest release tarball URL"
            exit 1
        fi

        print_color $BLUE "Downloading and extracting latest release from $tarball_url..."
        # Create a temp dir for extraction
        local tmpdir
        tmpdir=$(mktemp -d)

        # Download and extract tarball into temp dir
        curl -fsSL "$tarball_url" | tar -xz -C "$tmpdir" --strip-components=1

        # Copy all extracted files into installation directory
        cp -r "$tmpdir"/* "$INSTALL_DIR"/

        # Clean up
        rm -rf "$tmpdir"
    fi
    
    # Make script executable
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    print_color $GREEN "ctx script installed to $INSTALL_DIR/$SCRIPT_NAME"
}

# Function to create symlink
create_symlink() {
    print_color $BLUE "Creating bin directory: $BIN_DIR"
    mkdir -p "$BIN_DIR"
    
    local symlink_path="$BIN_DIR/$SYMLINK_NAME"
    local target_path="$INSTALL_DIR/$SCRIPT_NAME"
    
    # Remove existing symlink if it exists
    if [[ -L "$symlink_path" ]]; then
        print_color $YELLOW "Removing existing symlink: $symlink_path"
        rm "$symlink_path"
    elif [[ -f "$symlink_path" ]]; then
        print_color $YELLOW "Backing up existing file: $symlink_path"
        mv "$symlink_path" "${symlink_path}.backup.$(date +%s)"
    fi
    
    # Create symlink
    ln -s "$target_path" "$symlink_path"
    print_color $GREEN "Created symlink: $symlink_path -> $target_path"
}

# Function to verify installation
verify_installation() {
    local symlink_path="$BIN_DIR/$SYMLINK_NAME"
    
    if [[ ! -L "$symlink_path" ]]; then
        print_color $RED "Error: Symlink was not created"
        return 1
    fi
    
    if [[ ! -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        print_color $RED "Error: ctx script was not installed"
        return 1
    fi
    
    if [[ ! -x "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        print_color $RED "Error: ctx script is not executable"
        return 1
    fi
    
    print_color $GREEN "Installation verified successfully!"
    return 0
}

# Function to show post-installation instructions
show_instructions() {
   ctx help 
}

# Main installation function
main() {
    print_color $CYAN "Installing ctx configuration switcher..."
    echo
    
    # Check if running on supported system
    if [[ ! -d "$HOME" ]]; then
        print_color $RED "Error: HOME directory not found"
        exit 1
    fi
    
    # Run installation steps
    setup_path
    download_ctx
    create_symlink
    
    # Verify installation
    if verify_installation; then
        show_instructions
    else
        print_color $RED "Installation verification failed"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "ctx installer"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --uninstall   Uninstall ctx"
        echo
        echo "This script installs ctx configuration switcher to:"
        echo "  Script: $INSTALL_DIR/$SCRIPT_NAME"
        echo "  Symlink: $BIN_DIR/$SYMLINK_NAME"
        exit 0
        ;;
    --uninstall)
        print_color $YELLOW "Uninstalling ctx..."
        
        # Remove symlink
        if [[ -L "$BIN_DIR/$SYMLINK_NAME" ]]; then
            rm "$BIN_DIR/$SYMLINK_NAME"
            print_color $GREEN "Removed symlink: $BIN_DIR/$SYMLINK_NAME"
        fi
        
        # Remove installation directory
        if [[ -d "$INSTALL_DIR" ]]; then
            rm -rf "$INSTALL_DIR"
            print_color $GREEN "Removed installation directory: $INSTALL_DIR"
        fi
        
        print_color $CYAN "ctx has been uninstalled"
        print_color $YELLOW "Note: PATH modifications in shell configs were not removed"
        exit 0
        ;;
    "")
        # No arguments, proceed with installation
        main
        ;;
    *)
        print_color $RED "Unknown option: $1"
        print_color $YELLOW "Use --help for usage information"
        exit 1
        ;;
esac