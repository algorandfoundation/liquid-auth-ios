# Makefile for LiquidAuthSDK
# Provides convenient commands for linting, formatting, and building

.PHONY: help format lint lint-fix build test clean install-tools

# Default target
help:
	@echo "Available commands:"
	@echo "  make format     - Format all Swift files using SwiftFormat"
	@echo "  make lint       - Run SwiftLint to check for issues"
	@echo "  make lint-fix   - Run SwiftLint with auto-fix enabled"
	@echo "  make build      - Build the Swift package"
	@echo "  make test       - Run tests"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make install-tools - Install SwiftLint and SwiftFormat via Homebrew"
	@echo "  make check-all  - Run format, lint, build, and test"

# Install required tools via Homebrew
install-tools:
	@echo "Installing SwiftLint and SwiftFormat..."
	brew install swiftlint swiftformat

# Format all Swift files
format:
	@echo "Formatting Swift files..."
	swiftformat . --config .swiftformat

# Check Swift code formatting
format-check:
	@echo "🔍 Checking Swift code formatting..."
	@swiftformat --lint Sources/

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	swiftlint lint --config .swiftlint.yml

# Run SwiftLint with auto-fix
lint-fix:
	@echo "Running SwiftLint with auto-fix..."
	swiftlint lint --fix --config .swiftlint.yml

# Build the Swift package
build:
	@echo "Building Swift package..."
	swift build

# Run tests
test:
	@echo "Running tests..."
	swift test

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build

# Check everything: format, lint, build, test
check-all: format lint build test
	@echo "All checks completed successfully!"

# Pre-commit hook setup
pre-commit-setup:
	@echo "Setting up pre-commit hook..."
	@mkdir -p .git/hooks
	@echo '#!/bin/sh' > .git/hooks/pre-commit
	@echo 'make format lint build' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed!"

# GitHub Actions workflow helper
ci-check: lint build test
	@echo "CI checks completed!"
