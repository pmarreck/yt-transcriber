{
  description = "A flake for running Whisper with MPS (Metal Performance Shaders) support on Mac (Apple Silicon)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }: let
    supportedSystems = [ "x86_64-darwin" "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    mkCommonDevShell = system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      # Platform-specific packages
      platformPkgs = if pkgs.stdenv.isLinux then [ pkgs.libgcc pkgs.libstdcxx5 ] else [];
    in pkgs.mkShell {
      # Absolute minimum Nix-managed dependencies
      buildInputs = with pkgs; platformPkgs ++ [
        python311
        ffmpeg
        rye
        python311Packages.uv
      ];

      shellHook = ''
        # Set up Rye project if it doesn't exist
        if [ ! -d .rye ]; then
          echo "Creating new Rye project..."
          mkdir -p .rye

          # Create a minimal Python module structure to satisfy Rye's requirements
          mkdir -p .rye/yt_transcriber_deps
          echo "# yt-transcriber dependencies module" > .rye/yt_transcriber_deps/__init__.py

          # Create pyproject.toml with dependencies
          cat > .rye/pyproject.toml << EOF
[project]
name = "yt-transcriber-deps"
version = "0.1.0"
description = "Dependencies for YouTube transcriber using Whisper"
requires-python = ">=3.11"
dependencies = [
    "torch",
    "torchvision",
    "torchaudio",
    "openai-whisper>=20240930",
    "numba>=0.60.0",
    "yt-dlp",
    "psutil",
    "llvmlite>=0.43.0",
]

[tool.rye]
managed = true
dev-dependencies = []

[tool.hatch.build.targets.wheel]
packages = ["yt_transcriber_deps"]
EOF


        fi

        # Clean .rye for fresh setup before sync
        rm -rf .rye
        # Sync Rye unconditionally to ensure venv and deps
        echo "Syncing Rye environment..."
        rm -f .rye/requirements.lock .rye/requirements-dev.lock
        (cd .rye && rye sync --force --update-all) || { echo "Error: Failed to sync Rye environment"; exit 1; }

        # Check for activate script and activate
        if [ -f .rye/.venv/bin/activate ]; then
          source .rye/.venv/bin/activate || { echo "Error: Failed to activate Rye environment"; exit 1; }
        else
          echo "Venv activate script missing, retrying sync with force..."
          (cd .rye && rye sync --force) || { echo "Error: Failed to force sync Rye environment"; exit 1; }
          source .rye/.venv/bin/activate || { echo "Error: Failed to activate Rye environment after force sync"; exit 1; }
        fi

        # Install dependencies directly with uv
        echo "Installing dependencies with uv..."
        (cd .rye && uv pip install torch torchvision torchaudio openai-whisper yt-dlp psutil) || { echo "Error: Failed to install dependencies with uv"; exit 1; }

        echo -e "\033[33mWhisper environment ready with MPS support!\033[0m"
        echo "Python: $(python --version)"

        # Check if torch is available
        if python -c "import torch" 2>/dev/null; then
          echo "Torch: $(python -c 'import torch; print(f"PyTorch {torch.__version__}")')"
          echo "MPS available: $(python -c 'import torch; print(torch.backends.mps.is_available())')"
        else
          echo "Torch: Not available"
          echo "MPS available: False"
        fi

        # Add .rye/.venv/bin to PATH
        export PATH="$PWD/.rye/.venv/bin:$PATH"
      '';
    };
  in {
    devShells = forAllSystems (system: {
      default = mkCommonDevShell system;
    });
  };
}
