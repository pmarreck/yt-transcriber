#!/usr/bin/env bash
# test_flake.sh

# Test helper functions
assert_success() {
    if [ $? -eq 0 ]; then
        echo "✅ Test passed: $1"
    else
        echo "❌ Test failed: $1"
        exit 1
    fi
}

assert_failure() {
    if [ $? -ne 0 ]; then
        echo "✅ Test passed: $1"
    else
        echo "❌ Test failed: $1"
        exit 1
    fi
}

# Test 1: Check flake syntax
test_flake_syntax() {
    nix flake check
    assert_success "Flake syntax is valid"
}

# Test 2: Verify devShell output
test_devshell_output() {
    nix develop -c echo "Shell works"
    assert_success "Can enter devShell"
}

# Test 3: Verify platform-specific shell
test_platform_shell() {
    # Get current platform
    platform=$(nix eval --impure --expr 'builtins.currentSystem' | tr -d '"')
    nix develop .#devShells.${platform}.default -c echo "Platform shell works"
    assert_success "Platform-specific shell works"
}

# Run all tests
echo "Running Nix flake tests..."
test_flake_syntax
test_devshell_output
test_platform_shell
echo "All tests completed!"
