# Development Workflow

This document outlines the code quality tools and development workflow for LiquidAuthSDK.

## Code Quality Tools

### SwiftLint
SwiftLint enforces Swift style and conventions. Configuration is in `.swiftlint.yml`.

**Installation:**
```bash
brew install swiftlint
```

**Usage:**
```bash
# Check for issues
make lint

# Auto-fix issues where possible
make lint-fix

# Or run directly
swiftlint lint --config .swiftlint.yml
```

### SwiftFormat
SwiftFormat automatically formats Swift code according to style guidelines. Configuration is in `.swiftformat`.

**Installation:**
```bash
brew install swiftformat
```

**Usage:**
```bash
# Format all files
make format

# Or run directly
swiftformat . --config .swiftformat
```

## Development Commands

We've included a Makefile with convenient commands:

```bash
# Install required tools
make install-tools

# Format code
make format

# Run linting
make lint

# Build the package
make build

# Run tests
make test

# Run all checks (format + lint + build + test)
make check-all

# Clean build artifacts
make clean
```

## Pre-commit Hooks

### Option 1: Simple Git Hook
```bash
make pre-commit-setup
```

### Option 2: Pre-commit Framework (Recommended)
```bash
# Install pre-commit
pip install pre-commit

# Install the hooks
pre-commit install

# Run on all files
pre-commit run --all-files
```

## IDE Integration

### Xcode
1. **SwiftLint Integration:**
   - Add a new "Run Script Phase" in Build Phases
   - Script: `if which swiftlint >/dev/null; then swiftlint; else echo "SwiftLint not installed"; fi`

2. **SwiftFormat Integration:**
   - Install the SwiftFormat Xcode extension
   - Or add a Run Script Phase: `if which swiftformat >/dev/null; then swiftformat .; fi`

### VS Code
1. Install the "Swift" extension
2. Install "SwiftLint" extension
3. Add to settings.json:
```json
{
  "swift.format.onSave": true,
  "swiftlint.enable": true,
  "swiftlint.configPath": ".swiftlint.yml"
}
```

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) automatically:
- ✅ Checks code formatting
- ✅ Runs SwiftLint
- ✅ Builds the package
- ✅ Runs tests
- ✅ Generates code coverage

## Code Style Guidelines

### Key Rules Enforced

1. **Line Length:** 120 characters max
2. **Indentation:** 4 spaces
3. **Function Length:** 100 lines warning, 200 error
4. **File Length:** 500 lines warning, 1000 error
5. **Naming:** Clear, descriptive names
6. **Documentation:** All public APIs must be documented

### Custom Rules

- No `print()` statements (use `Logger` instead)
- Consistent import organization
- Proper error handling patterns
- WebAuthn-specific conventions

## Troubleshooting

### SwiftLint Issues
```bash
# Update SwiftLint
brew upgrade swiftlint

# Check version
swiftlint version

# Lint specific files
swiftlint lint --path Sources/LiquidAuthSDK/
```

### SwiftFormat Issues
```bash
# Update SwiftFormat
brew upgrade swiftformat

# Check what would be changed
swiftformat . --config .swiftformat --lint

# Format specific files
swiftformat Sources/ --config .swiftformat
```

### Build Issues
```bash
# Clean and rebuild
make clean
make build

# Update dependencies
swift package update
```

## Contributing

Before submitting a PR:
1. Run `make check-all` to ensure all checks pass
2. Ensure all new code has appropriate documentation
3. Add tests for new functionality
4. Update this README if adding new tools or workflows
