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
        python312
        ffmpeg
        rye
        uv
        phantomjs # Added to fix yt-dlp "nsig extraction failed" warnings
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
requires-python = ">=3.12"
dependencies = [
    "torch",
    "torchvision",
    "torchaudio",
    "openai-whisper",
    "yt-dlp",
    "psutil",
]

[tool.rye]
managed = true
dev-dependencies = []

[tool.hatch.build.targets.wheel]
packages = ["yt_transcriber_deps"]
EOF

          # Create empty lockfiles to avoid warnings
          touch .rye/requirements.lock
          touch .rye/requirements-dev.lock
        fi

        # Create and activate virtual environment
        if [ ! -d .rye/.venv ]; then
          echo "Creating virtual environment with Rye..."
          (cd .rye && rye env create)
        fi
        
        # Activate virtual environment
        source .rye/.venv/bin/activate
        
        # Install dependencies directly with uv
        echo "Installing dependencies with uv..."
        (cd .rye && uv pip install torch torchvision torchaudio openai-whisper yt-dlp psutil)
        
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
