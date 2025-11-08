# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a bash script for building production-ready release packages for WordPress plugins. The script creates clean, distribution-ready ZIP archives by automatically excluding development files and dependencies.

## Core Architecture

### Main Script: `build-release.sh`

The script operates in the following phases:

1. **Plugin Discovery** - Scans the current directory for plugin folders (directories containing PHP files with "Plugin Name:" headers)
2. **Version Detection** - Extracts version from the main plugin file's WordPress header (e.g., `Version: 1.4.1`)
3. **Temporary Build** - Uses rsync to copy plugin files to a temporary directory, excluding development artifacts
4. **Archive Creation** - Creates a ZIP file in `releases/` directory with naming format: `{plugin-name}-{version}.zip`
5. **Cleanup** - Removes temporary files

### Plugin File Detection Logic

The script follows this hierarchy to find the main plugin file:
1. First tries `{plugin-folder}/{plugin-folder}.php`
2. Falls back to first PHP file containing `Plugin Name:` header
3. If neither found, uses first PHP file in directory (line 68-74, 140-146)

This detection logic is critical - any modifications to plugin scanning should preserve this fallback hierarchy.

### Exclusion Patterns

The script uses a two-tier exclusion system:

**1. Default Exclusions (lines 174-229)**

Defined in the `DEFAULT_EXCLUDES` array, organized by category:
- Version control files (`.git`, `.github`, `.gitignore`)
- Development dependencies (`node_modules/`, `vendor/`)
- Build configuration (`webpack.config.js`, `package.json`, `composer.json`)
- Testing files (`tests/`, `phpunit.xml`)
- Documentation source files (`README.md`, `CHANGELOG.md`, `CLAUDE.md`)
- Environment files (`.env*`, `*.log`, `*.sql`)

When modifying default exclusions, maintain this categorical organization for clarity.

**2. Custom Exclusions via .buildignore (lines 231-255)**

The script checks for a `.buildignore` file in each plugin directory. If found:
- Parses the file line by line
- Skips empty lines and lines starting with `#` (comments)
- Trims whitespace from each pattern
- Adds valid patterns to the `CUSTOM_EXCLUDES` array
- Displays count of loaded custom exclusions

The parsing logic (lines 238-250) is critical - it handles:
- Comment detection using regex: `^[[:space:]]*#`
- Whitespace trimming using sed
- Empty line filtering

Custom exclusions are **additive** - they supplement rather than replace default exclusions (line 258).

**3. Combined Exclusion Processing (lines 257-264)**

All exclusions are combined into `ALL_EXCLUDES` array, then converted to rsync `--exclude` arguments dynamically. This approach allows for flexible plugin-specific configurations while maintaining consistent defaults across all builds.

## Usage

### Interactive Mode (Default)
```bash
./build-release.sh
```
Displays a menu of all available plugins with their versions.

### Direct Build Mode
```bash
./build-release.sh {plugin-folder-name}
```
Builds the specified plugin without showing the menu.

## Development Commands

### Running the Script
The script must be executable and run from the repository root:
```bash
chmod +x build-release.sh
./build-release.sh
```

### Testing Changes
When modifying the script, test with both modes:
```bash
# Test interactive menu
./build-release.sh

# Test direct invocation
./build-release.sh test-plugin-name
```

### Verifying Archive Contents
The script automatically displays archive contents after building. For manual verification:
```bash
unzip -l releases/{plugin-name}-{version}.zip
```

## Script Dependencies

Required system utilities:
- `bash` - Shell execution
- `rsync` - File copying with exclusions
- `zip` - Archive creation
- `grep`, `awk`, `du` - Text processing and file operations
- `mktemp` - Temporary directory creation

All are standard Unix/Linux tools except possibly rsync (may need installation on minimal systems).

## Working with WordPress Plugin Structure

This script expects WordPress plugins to follow standard conventions:
- Plugin main file contains WordPress file headers
- Version information in format: `Version: X.Y.Z`
- Plugin folder name matches the main PHP file name (preferred but not required)

The version detection uses case-insensitive grep (line 149) and strips whitespace/carriage returns (line 149) to handle various formatting.

## Working with .buildignore Files

Each plugin can have its own `.buildignore` file for custom exclusions:

### Location
Place `.buildignore` in the plugin's root directory (same level as the main plugin PHP file).

### Syntax
- One pattern per line
- Comments start with `#` (can have leading whitespace)
- Empty lines are ignored
- Patterns are passed directly to rsync's `--exclude` option
- Supports rsync pattern syntax (wildcards, trailing slashes for directories)

### When to Use
- Plugin has unique build artifacts to exclude
- Plugin uses frameworks that generate files in non-standard locations
- Plugin has confidential files that shouldn't be in releases
- Plugin structure differs significantly from defaults

### Example Workflow
```bash
# Create .buildignore for a plugin
cd plugin-name/
cat > .buildignore << 'EOF'
# Exclude uncompiled assets
src/scss/
src/js/raw/

# Exclude private documentation
internal-docs/
EOF

# Build will automatically use these exclusions
cd ..
./build-release.sh plugin-name
```

### Debugging
The script outputs "Loaded N custom exclusion(s)" when .buildignore is found. If exclusions aren't working:
1. Verify `.buildignore` is in the plugin root directory
2. Check for syntax errors (unexpected characters, incorrect patterns)
3. Ensure patterns match rsync exclude syntax
4. Remember that patterns are case-sensitive

## Output Structure

```
releases/
└── {plugin-name}-{version}.zip
    └── {plugin-name}/
        └── [plugin files without development artifacts]
```

The ZIP maintains the plugin folder as the root directory, ready for WordPress installation via wp-admin or WP-CLI.
