{
  description = "A flake for running Whisper with MPS (Metal Performance Shaders) support on Mac (Apple Silicon)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }: let
    supportedSystems = [ "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    mkCommonDevShell = system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in pkgs.mkShell {
      # Absolute minimum Nix-managed dependencies
      buildInputs = with pkgs; [
        python310
        ffmpeg
      ];

      shellHook = ''
        # Set up virtual environment if it doesn't exist
        if [ ! -d .venv ]; then
          echo "Creating new Python virtual environment..."
          python -m venv .venv
        fi

        # Activate virtual environment
        source .venv/bin/activate

        # Install Python packages if needed
        if [ ! -f .venv/.packages-installed ]; then
          echo "Installing Python packages..."
          python -m pip install --upgrade pip
          python -m pip install torch torchvision torchaudio
          python -m pip install openai-whisper
          # Mark packages as installed
          touch .venv/.packages-installed
        fi

        echo -e "\033[33mWhisper environment ready with MPS support!\033[0m"
        echo "Python: $(python --version)"
        echo "Torch: $(python -c 'import torch; print(f"PyTorch {torch.__version__}")')"
        echo "MPS available: $(python -c 'import torch; print(torch.backends.mps.is_available())')"

        # Add .venv/bin to PATH
        export PATH="$PWD/.venv/bin:$PATH"
      '';
    };
  in {
    devShells = forAllSystems (system: {
      default = mkCommonDevShell system;
    });
  };
}
