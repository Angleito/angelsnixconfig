{ config, pkgs, ... }:

{
  # Set the primary user (required for the options below)
  system.primaryUser = "angel";
  
  # Nix configuration
  nix = {
    package = pkgs.nix;
    settings.experimental-features = "nix-command flakes";
  };

  # Set your username
  users.users.angel = {
    name = "angel";
    home = "/Users/angel";
  };
  
  # Fix nixbld group ID
  ids.gids.nixbld = 350;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    nodejs_20  # Include Node.js for npm
    claude-code   # NEW – install from nixpkgs instead of npm
  ];
  
  # Power management settings - prevent display from turning off
  system.activationScripts.powerManagement.text = ''
    echo "Configuring power management settings..."
    
    # Prevent display from sleeping (0 = never)
    pmset -a displaysleep 0
    
    # Prevent system from sleeping when on AC power (0 = never)
    pmset -c sleep 0
    
    # Prevent disk from sleeping
    pmset -a disksleep 0
    
    # Keep the system awake when the display is off
    pmset -a powernap 0
    
    # Prevent automatic sleep when on AC power
    pmset -c autopoweroff 0
    
    # Optional: Keep display awake even when system is idle
    pmset -a lessbright 0
    
    echo "Power management settings configured"
  '';
  
  # Install Xcode Command Line Tools if not already installed
  system.activationScripts.xcodeTools.text = ''
    if ! xcode-select -p &> /dev/null; then
      echo "Installing Xcode Command Line Tools..."
      touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^:]*: //')
      if [ -n "$PROD" ]; then
        softwareupdate -i "$PROD" --verbose
      else
        echo "Could not find Xcode Command Line Tools in software update catalog"
        echo "You may need to install manually with: xcode-select --install"
      fi
      rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    else
      echo "Xcode Command Line Tools already installed"
    fi
  '';
  
  # System-wide npm configuration for other CLI tools
  system.activationScripts.postActivation.text = ''
    # Configure npm globally for all users
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin"
    
    # Create npm global directory for the primary user
    sudo -u ${config.system.primaryUser} mkdir -p /Users/${config.system.primaryUser}/.npm-global
    sudo -u ${config.system.primaryUser} mkdir -p /Users/${config.system.primaryUser}/.npm-cache
    
    # Note: npm configuration moved to user-level to avoid permission issues
    # Users can configure npm manually with:
    # npm config set prefix ~/.npm-global
    # npm config set cache ~/.npm-cache
    
    # Install Sui CLI
    if ! command -v sui &> /dev/null; then
      echo "Installing Sui CLI..."
      # Install Sui using cargo (Rust package manager)
      if command -v cargo &> /dev/null; then
        sudo -u ${config.system.primaryUser} cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui
        echo "Sui CLI installed successfully!"
      else
        echo "Cargo not found. Installing Sui via npm as fallback..."
        sudo -u ${config.system.primaryUser} npm install -g @mysten/sui
      fi
    else
      echo "Sui CLI is already installed"
    fi
    
    # Install Walrus CLI
    if ! command -v walrus &> /dev/null; then
      echo "Installing Walrus CLI..."
      # Check the architecture and download appropriate binary
      ARCH=$(uname -m)
      if [ "$ARCH" = "arm64" ]; then
        WALRUS_ARCH="arm64"
      else
        WALRUS_ARCH="x86_64"
      fi
      
      # Download Walrus binary for macOS
      echo "Downloading Walrus CLI for macOS $WALRUS_ARCH..."
      curl -L "https://github.com/MystenLabs/walrus-sites/releases/latest/download/site-builder-macos-$WALRUS_ARCH" -o /tmp/walrus
      
      # Make it executable and move to local bin
      chmod +x /tmp/walrus
      sudo -u ${config.system.primaryUser} mkdir -p /Users/${config.system.primaryUser}/.local/bin
      sudo -u ${config.system.primaryUser} mv /tmp/walrus /Users/${config.system.primaryUser}/.local/bin/walrus
      
      # Configure Walrus for testnet
      echo "Configuring Walrus for testnet..."
      sudo -u ${config.system.primaryUser} mkdir -p /Users/${config.system.primaryUser}/.config/walrus
      cat > /tmp/walrus-config.yaml << 'EOF'
system_object: 0x70a61a5cf43b2c00aacf57e6784f5c8a09b4dd68de16f96b7c5a3bb5c3c8c04e5
storage_nodes:
  - name: wal-devnet-0
    rpc_url: https://rpc-walrus-testnet.nodes.guru:443
    rest_url: https://storage.testnet.sui.walrus.site/v1
  - name: wal-devnet-1
    rpc_url: https://walrus-testnet-rpc.bartestnet.com
    rest_url: https://walrus-testnet-storage.bartestnet.com/v1
  - name: wal-devnet-2
    rpc_url: https://walrus-testnet.blockscope.net
    rest_url: https://walrus-testnet-storage.blockscope.net/v1
  - name: wal-devnet-3
    rpc_url: https://walrus-testnet-rpc.nodes.guru
    rest_url: https://walrus-testnet-storage.nodes.guru/v1
  - name: wal-devnet-4
    rpc_url: https://walrus.testnet.arcadia.global
    rest_url: https://walrus-storage.testnet.arcadia.global/v1
EOF
      sudo -u ${config.system.primaryUser} mv /tmp/walrus-config.yaml /Users/${config.system.primaryUser}/.config/walrus/client_config.yaml
      
      echo "Walrus CLI installed and configured for testnet!"
    else
      echo "Walrus CLI is already installed"
    fi
  '';

  # Homebrew configuration
  homebrew = {
    enable = true;
    
    # Keep Homebrew up to date
    onActivation = {
      autoUpdate = true;
      cleanup = "zap"; # Remove unused formulae and casks
      upgrade = true;
    };
    
    # Taps - removed deprecated/unnecessary taps
    taps = [
      # homebrew/core and homebrew/cask are now built-in and don't need to be tapped
      # homebrew/services has been deprecated
    ];
    
    # Homebrew formulae (CLI tools)
    brews = [
      "mas" # Mac App Store CLI
    ];
    
    # Homebrew casks (GUI applications)
    casks = [
      "warp"           # Warp terminal
      "cursor"         # Cursor AI editor
      "brave-browser"  # Brave browser
      "orbstack"       # Docker/container management
      "zoom"           # Zoom video conferencing
      "slack"          # Slack messaging
    ];
    
    # Mac App Store apps (requires 'mas' brew)
    masApps = {
      # "App Name" = App_ID;
      # To find App IDs, use: mas search "app name"
      "GarageBand" = 682658836;
    };
  };

  # macOS system defaults
  system.defaults = {
    # Dock settings
    dock = {
      autohide = false; # Keep dock visible
      show-recents = false;
      minimize-to-application = true;
      mru-spaces = false; # Don't rearrange spaces
    };
    
    # Finder settings
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXEnableExtensionChangeWarning = false;
    };
    
    # Trackpad settings
    trackpad = {
      Clicking = true; # Tap to click
      TrackpadThreeFingerDrag = true;
    };
    
    # Other macOS settings
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3; # Full keyboard access
      ApplePressAndHoldEnabled = false; # Key repeat
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };
  };

  # Used for backwards compatibility
  system.stateVersion = 4;
}
