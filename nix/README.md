# Nix Dotfiles

A cross-platform dotfiles configuration using Nix flakes and Home Manager, supporting both macOS and Linux.

## 🎯 Overview

This Nix-based dotfiles setup provides:

- **Cross-platform compatibility**: Works on macOS and Linux
- **Declarative configuration**: All settings defined in Nix files
- **Reproducible environments**: Identical setups across machines
- **Atomic updates**: Safe configuration changes with rollback capability
- **Centralized management**: Single source of truth for all configurations

## 📁 Structure

```
nix/
├── flake.nix                    # Main flake configuration
├── common/
│   ├── home.nix                 # Common Home Manager settings
│   ├── packages.nix             # Cross-platform packages
│   └── programs/
│       ├── helix.nix            # Helix editor configuration
│       ├── fish.nix             # Fish shell configuration
│       ├── bash.nix             # Bash shell configuration
│       ├── wezterm.nix          # WezTerm terminal configuration
│       ├── ghostty.nix          # Ghostty terminal configuration
│       ├── zellij.nix           # Zellij multiplexer configuration
│       └── git.nix              # Git configuration
├── systems/
│   ├── darwin.nix               # macOS system configuration
│   └── linux.nix                # Linux system configuration
├── users/
│   ├── darwin-user.nix          # macOS user configuration
│   └── linux-user.nix           # Linux user configuration
├── install.sh                   # Installation script
├── switch.sh                    # Configuration update script
└── rollback.sh                  # Rollback script
```

## 🚀 Installation

### Prerequisites

- **macOS**: macOS 10.15+ (Catalina or later)
- **Linux**: Any modern Linux distribution with systemd

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd dotfiles/nix
   ```

2. **Run the installation script**:
   ```bash
   ./install.sh
   ```

3. **Follow the prompts** and restart your terminal when complete.

### Manual Installation Steps

<details>
<summary>Click to expand manual installation instructions</summary>

#### 1. Install Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

#### 2. For macOS: Install nix-darwin

```bash
nix run nix-darwin -- switch --flake .#default
```

#### 3. For Linux: Install Home Manager

```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

#### 4. Apply Configuration

**macOS**:
```bash
darwin-rebuild switch --flake .#default
nix run home-manager -- switch --flake .#"x@macos"
```

**Linux**:
```bash
nix run home-manager -- switch --flake .#"x@linux"
```

</details>

## 🔧 Usage

### Updating Configuration

Update your configuration and apply changes:

```bash
./switch.sh
```

**Available options**:
- `./switch.sh --dry-run`: Preview changes without applying
- `./switch.sh --verbose`: Show detailed output
- `./switch.sh --update`: Update flake inputs first

### Rolling Back

If something goes wrong, rollback to the previous generation:

```bash
./rollback.sh
```

**Available options**:
- `./rollback.sh --list`: List available generations
- `./rollback.sh --interactive`: Interactive generation selection
- `./rollback.sh 42`: Rollback to specific generation number

### Managing the Configuration

#### Adding New Programs

1. Create a new program file in `common/programs/`:
   ```nix
   # common/programs/your-program.nix
   { config, pkgs, ... }:
   {
     programs.your-program = {
       enable = true;
       # your configuration here
     };
   }
   ```

2. Add it to `common/home.nix`:
   ```nix
   imports = [
     # ... other imports
     ./programs/your-program.nix
   ];
   ```

3. Apply the changes:
   ```bash
   ./switch.sh
   ```

#### Adding New Packages

Add packages to `common/packages.nix`:

```nix
home.packages = with pkgs; [
  # ... existing packages
  your-new-package
];
```

#### Platform-Specific Configurations

- **macOS-specific**: Edit `systems/darwin.nix` or `users/darwin-user.nix`
- **Linux-specific**: Edit `systems/linux.nix` or `users/linux-user.nix`

## 📋 Included Configurations

| Tool | Description | Configuration |
|------|-------------|---------------|
| **Helix** | Modern text editor | Vim-like keybindings, syntax highlighting, LSP |
| **Fish** | User-friendly shell | Bass plugin, custom functions, aliases |
| **Bash** | Traditional shell | Compatibility layer with Fish |
| **WezTerm** | Modern terminal | Font configuration, keybindings, themes |
| **Ghostty** | Fast terminal | macOS-optimized settings |
| **Zellij** | Terminal multiplexer | Vim-like navigation keybindings |
| **Git** | Version control | Aliases, color output, sensible defaults |

## 🔧 Customization

### User Information

Update your personal information in the appropriate user configuration file:

**For macOS** (`users/darwin-user.nix`):
```nix
programs.git = {
  userName = "Your Name";
  userEmail = "your.email@example.com";
};
```

**For Linux** (`users/linux-user.nix`):
```nix
programs.git = {
  userName = "Your Name";
  userEmail = "your.email@example.com";
};
```

### Themes and Colors

Color schemes are configured in individual program files:

- **Helix**: `common/programs/helix.nix` → `theme = "github_dark_dimmed"`
- **WezTerm**: `common/programs/wezterm.nix` → `config.color_scheme = 'GitHub Dark'`
- **Ghostty**: `common/programs/ghostty.nix` → theme configuration

### Keybindings

Customize keybindings in the respective program files:

- **Helix**: `common/programs/helix.nix` → `keys` section
- **WezTerm**: `common/programs/wezterm.nix` → `config.keys`
- **Zellij**: `common/programs/zellij.nix` → `keybinds`

## 🐛 Troubleshooting

### Common Issues

#### "command not found" after installation

**Solution**: Restart your terminal or source your shell configuration:
```bash
# For Fish
source ~/.config/fish/config.fish

# For Bash  
source ~/.bashrc
```

#### Home Manager build fails

**Solution**: Check for syntax errors in configuration files:
```bash
nix flake check
```

#### macOS: Fish global configuration not working

**Solution**: Manually link the global fish configuration:
```bash
sudo ln -sf ~/.config/fish/global_config_darwin.fish /etc/fish/config.fish
```

#### Rollback not working

**Solution**: List generations and select manually:
```bash
./rollback.sh --list
./rollback.sh --interactive
```

### Getting Help

1. **Check the logs**: Use `--verbose` flag with commands
2. **Validate configuration**: Run `nix flake check` in the nix directory
3. **List generations**: Use `./rollback.sh --list` to see available rollback points
4. **Clean rebuild**: Remove `flake.lock` and rebuild if needed

## 🔗 Useful Commands

```bash
# Check flake inputs
nix flake show

# Update all inputs
nix flake update

# Check configuration syntax
nix flake check

# Collect garbage (clean old generations)
nix-collect-garbage -d

# List installed packages
nix-env -q

# Search for packages
nix search nixpkgs <package-name>
```

## 📚 Resources

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [nix-darwin Manual](https://github.com/LnL7/nix-darwin)
- [NixOS Package Search](https://search.nixos.org/packages)
- [Nix Flakes Tutorial](https://nixos.wiki/wiki/Flakes)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both macOS and Linux (if possible)
5. Submit a pull request

## 📄 License

This configuration is released under the [MIT License](LICENSE).