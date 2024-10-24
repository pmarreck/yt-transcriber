{
  description = "A flake for running Whisper with MPS (Metal Performance Shaders) support on Mac (Apple Silicon)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";  # Use an up-to-date nixpkgs

  outputs = { self, nixpkgs }: {
    # Define the function for the devShell
    devShells = let
      # Define a common function for the dev environments
      mkCommonDevShell = platform: nixpkgs.legacyPackages.${platform}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${platform}; [
          python310               # Python 3.10
          python310Packages.pip    # Pip for package management
          python310Packages.whisper  # Whisper for transcription
          python310Packages.torch  # PyTorch (with MPS backend support)
          python310Packages.torchaudio  # Torchaudio for audio processing
          ffmpeg                  # Needed for handling audio/video formats
        ];

        shellHook = ''
          echo -e "\033[33mEnvironment for Whisper and PyTorch with MPS on Mac is ready!\033[0m"
        '';
      };
    in {
      # Define the environments for both platforms
      x86_64-darwin = mkCommonDevShell "x86_64-darwin";
      aarch64-darwin = mkCommonDevShell "aarch64-darwin";
    };

    # Define the default devShell for the current platform
    devShell = nixpkgs.mkShell {
      inherit (devShells) aarch64-darwin;
    };
  };
}
