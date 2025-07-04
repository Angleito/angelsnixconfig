{ pkgs, ... }:
let
  gitName  = builtins.getEnv "GIT_NAME";
  gitEmail = builtins.getEnv "GIT_EMAIL";
in
{
  programs.git = {
    enable = true;
    userName  = if gitName != "" then gitName else "Unknown";
    userEmail = if gitEmail != "" then gitEmail else "unknown@example.com";
    
    # Use SSH for GitHub
    extraConfig = {
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };
      
      # Sign commits with SSH key
      commit.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";
      
      # Use macOS keychain for credentials
      credential.helper = "osxkeychain";
      
      # Hooks configuration
      core.hooksPath = "~/.config/git/hooks";
    };
  };
  
  # SSH configuration
  programs.ssh = {
    enable = true;
    
    # Use macOS keychain for SSH keys
    extraConfig = ''
      Host github.com
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_ed25519
        AddKeysToAgent yes
        UseKeychain yes
    '';
  };
}
