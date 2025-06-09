# Portable Linux Environment - Stage 1 Foundation

A modular, cross-platform development environment configuration system.

## Quick Start

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Current Stage: 1 - Foundation Layer

### Completed Features
- ✅ Cross-platform detection (Linux, WSL, Termux, Containers)
- ✅ Package manager abstraction
- ✅ Repository structure
- ✅ Basic Git configuration
- ✅ Essential tool installation

### Platform Support
- **Termux** (Android)
- **Ubuntu/Debian** and derivatives
- **Fedora/RHEL** and derivatives
- **Arch Linux** and derivatives
- **openSUSE**
- **Alpine Linux**
- **WSL** (Windows Subsystem for Linux)

### Repository Structure
```
dotfiles/
├── config/          # Configuration files
│   ├── git/        # Git configuration
│   ├── shell/      # Shell configurations
│   └── tmux/       # Tmux configuration
├── scripts/         # Utility scripts
│   ├── detect/     # Platform detection
│   ├── install/    # Installation scripts
│   └── utils/      # Helper utilities
├── docs/           # Documentation
└── backups/        # Backup storage
```

## Next Steps

Stage 2 will introduce:
- Nushell configuration
- Starship prompt
- Advanced shell integration

## Contributing

Feel free to fork and customize for your needs!
