# Portable Development Environment

A modular system using service layer architecture for platform abstraction.

## Architecture

### Service Layer Pattern

The platform detection service provides:
- Centralized platform detection logic
- Caching for performance
- Package manager abstractions
- Consistent interface across all stages

### Five-Stage Deployment

1. **Foundation**: Platform service, essential tools
2. **Shell Evolution**: Modern shell environment
3. **CLI Modernization**: Enhanced command-line tools
4. **Development Ecosystem**: Programming languages and tools
5. **Integration & Polish**: Final configurations

## Usage

```bash
# Initial setup
./stage1/install.sh

# Platform information
source ~/dotfiles/shared/utils/platform.sh
show_platform

# Continue with next stages
./stage2/install.sh
```

## Platform Service API

- `get_platform()` - Load platform info (cached or dynamic)
- `show_platform()` - Display platform details
- `pkg_update()` - Update package repositories
- `pkg_install <packages>` - Install packages
EOF

    cat > "$DOTFILES_DIR/stage1/README.md" << 'EOF'
# Stage 1: Foundation Layer

## Overview

Establishes the platform detection service and core infrastructure.

## Service Layer Architecture

Stage 1 creates a comprehensive platform service that:
- Detects OS, distribution, and package manager
- Caches results for performance
- Provides package manager abstractions
- Exports a consistent API for all stages

## Components

- `shared/utils/platform.sh` - Platform detection service
- `.platform` - Cached platform information
- Foundation tools: git, curl, build essentials

## Platform Service Functions

### Detection
- `detect_os()` - Identify operating system
- `detect_distro()` - Identify distribution
- `detect_pkg_manager()` - Identify package manager

### Cache Management
- `save_platform_info()` - Cache detection results
- `load_platform_info()` - Load cached or dynamic info

### Package Management
- `pkg_update()` - Update repositories
- `pkg_install()` - Install packages

## Usage

```bash
# Load platform service
source ~/dotfiles/shared/utils/platform.sh

# Get platform info
get_platform

# Install packages
pkg_install neovim tmux
```