# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a bash script for building production-ready release packages for WordPress plugins. The script creates clean, distribution-ready ZIP archives by automatically excluding development files and dependencies.

## Core Architecture

### Main Script: `build-release.sh`

The script operates in the following phases:

1. **Plugin Discovery** - Scans the current directory for plugin folders (directories containing PHP files with "Plugin Name:" headers)
2. **Plugin Selection** - Interactive menu (with optional wildcard filtering) or direct specification
3. **Version Detection** - Extracts version from the main plugin file's WordPress header (e.g., `Version: 1.4.1`)
4. **Build Process** - Automatically detects and runs build tools (composer, npm, make) or uses custom `.buildconfig.json`
5. **File Copying** - Uses rsync to copy plugin files to temporary directory, applying exclusion/inclusion rules
6. **Archive Creation** - Creates a ZIP file in `releases/` directory with naming format: `{plugin-name}-{version}.zip`
7. **Cleanup** - Removes temporary files

### Plugin File Detection Logic

The script follows this hierarchy to find the main plugin file:
1. First tries `{plugin-folder}/{plugin-folder}.php`
2. Falls back to first PHP file containing `Plugin Name:` header
3. If neither found, uses first PHP file in directory (line 68-74, 140-146)

This detection logic is critical - any modifications to plugin scanning should preserve this fallback hierarchy.

### Plugin Selection and Filtering

The `select_plugin()` function (lines 44-141) handles three modes of operation:

**1. Full Interactive Menu (no parameter)**
- Displays all available plugins with version numbers
- User selects from numbered list

**2. Direct Build (exact directory match)**
- Parameter matches an existing plugin directory exactly
- Skips menu, builds immediately

**3. Filtered Interactive Menu (wildcard pattern)**
- Parameter doesn't match an exact directory
- Treats parameter as bash pattern (e.g., `"woo*"`, `"*-addon"`)
- Filters plugin list using pattern matching: `[[ "$plugin" == $filter ]]`
- Displays filtered menu with matching plugins only
- Auto-selects if only one match found

**Critical: Pattern quoting** - Wildcard patterns MUST be quoted to prevent shell expansion:
- `./build-release.sh "woo*"` ✅ Correct - quotes prevent shell from expanding
- `./build-release.sh woo*` ❌ Wrong - shell expands to first matching directory

Without quotes, bash expands wildcards before passing arguments to the script, defeating the filtering mechanism.

The logic flow (lines 144-158):
```bash
if [ -d "$SCRIPT_DIR/$1" ]; then
    # Exact match - use directly
else
    # Not exact - treat as filter pattern
    PLUGIN_FOLDER=$(select_plugin "$1")
fi
```

This allows flexible invocation:
- `./build-release.sh` → full menu
- `./build-release.sh my-plugin` → direct build (if exact directory exists)
- `./build-release.sh "my*"` → filtered menu (note: must quote!)
- `./build-release.sh "*addon*"` → filtered menu (note: must quote!)

### Build Process Automation

The build process (lines 205-314) runs **before** file copying and operates in two modes:

**1. Custom Build Configuration (.buildconfig.json)**

If `.buildconfig.json` exists in the plugin directory:
- Requires `jq` command-line JSON processor
- Reads `build` array containing shell commands
- Executes each command sequentially in the plugin directory
- Falls back to automatic detection if jq is not installed

Example detection and execution (lines 209-232):
```bash
BUILDCONFIG_FILE="$PLUGIN_PATH/.buildconfig.json"
if [ -f "$BUILDCONFIG_FILE" ] && command -v jq; then
    BUILD_COMMANDS=$(jq -r '.build[]? // empty' "$BUILDCONFIG_FILE")
    # Execute each command
fi
```

**2. Automatic Build Detection (Default)**

If no `.buildconfig.json` exists or jq unavailable (lines 237-298):

Checks in order:
1. **Makefile** - Runs `make build`, falls back to `make`
2. **composer.json** - Runs `composer install --no-dev --optimize-autoloader --no-interaction`
   - Only runs if composer command is available
3. **package.json** - Only if it contains a `"build"` script
   - Runs `npm install --legacy-peer-deps` (falls back to regular npm install)
   - Then runs `npm run build`
   - Only runs if npm command is available

**Note about vendor/ directory:**

The `vendor/` directory is **not excluded by default** and will be included in releases. If you want to exclude it, add it to `.buildignore`.

### Exclusion Patterns

The script uses a two-tier exclusion system:

**1. Default Exclusions (lines 320-381)**

Defined in the `DEFAULT_EXCLUDES` array, organized by category:
- Version control files (`.git`, `.github`, `.gitignore`)
- Development dependencies (`node_modules/`)
- Build configuration (`webpack.config.js`, `package.json`, `composer.json`)
- Testing files (`tests/`, `phpunit.xml`)
- Documentation source files (`README.md`, `CHANGELOG.md`, `CLAUDE.md`)
- Environment files (`.env*`, `*.log`, `*.sql`)
- Source directories (`src/`)

**Note:** `vendor/` is **not** in the default exclusions - it's included by default.

When modifying default exclusions, maintain this categorical organization for clarity.

**2. Custom Exclusions and Inclusions via .buildignore (lines 383-417)**

The script checks for a `.buildignore` file in each plugin directory. If found:
- Parses the file line by line
- Skips empty lines and lines starting with `#` (comments)
- Trims whitespace from each pattern
- Detects negation patterns (starting with `!`)
  - Negation patterns are added to `CUSTOM_INCLUDES` array (with `!` prefix removed)
  - Regular patterns are added to `CUSTOM_EXCLUDES` array
- Displays summary: "Loaded N custom rule(s): X inclusion(s), Y exclusion(s)"

The parsing logic (lines 239-259) is critical - it handles:
- Comment detection using regex: `^[[:space:]]*#`
- Whitespace trimming using sed
- Empty line filtering
- Negation detection using regex: `^!`
- Prefix removal using bash parameter expansion: `${line#!}`

Custom exclusions are **additive** - they supplement default exclusions (line 419).
Custom inclusions **override** both default and custom exclusions.

**3. Combined Processing with Rsync Arguments (lines 419-436)**

The script builds rsync arguments in a specific order (critical for proper functioning):

1. **Include patterns first** (lines 424-427): Custom inclusions from `CUSTOM_INCLUDES` are converted to `--include` arguments
2. **Exclude patterns second** (lines 429-432): All exclusions (default + custom) from `ALL_EXCLUDES` are converted to `--exclude` arguments

This ordering is essential because rsync processes patterns sequentially - include patterns must come before exclude patterns to properly override exclusions. For example, to exclude most of vendor/ but keep one library:
```bash
--exclude=vendor/ --include=vendor/my-library/** --include=vendor/my-library/
```
Would need proper ordering to work correctly.

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
Builds the specified plugin without showing the menu (only if exact directory match).

### Filtered Menu Mode
```bash
./build-release.sh "{pattern}"
```
Filters the plugin list using wildcard patterns (must be quoted):
- `./build-release.sh "woo*"` - Show plugins starting with "woo"
- `./build-release.sh "*-addon"` - Show plugins ending with "-addon"
- `./build-release.sh "*commerce*"` - Show plugins containing "commerce"

Auto-selects if only one plugin matches the pattern.

**Important:** Patterns must be quoted to prevent shell expansion. Without quotes, bash will expand the wildcard before passing it to the script, which will cause only the first matching directory to be selected instead of filtering the menu.

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

**Required system utilities:**
- `bash` - Shell execution
- `rsync` - File copying with exclusions
- `zip` - Archive creation
- `grep`, `awk`, `du`, `sed` - Text processing and file operations
- `mktemp` - Temporary directory creation

All are standard Unix/Linux tools except possibly rsync (may need installation on minimal systems).

**Optional (for build automation):**
- `composer` - PHP dependency manager (for composer.json projects)
- `npm` - Node package manager (for package.json projects)
- `make` - Build automation (for Makefile projects)
- `jq` - JSON processor (required for `.buildconfig.json` support, falls back to auto-detection if unavailable)

The script gracefully handles missing optional dependencies by skipping the corresponding build steps with warnings.

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
- Regular patterns are passed to rsync's `--exclude` option (exclusions)
- Patterns starting with `!` are passed to rsync's `--include` option (inclusions/negations)
- Supports rsync pattern syntax (wildcards, trailing slashes for directories)

### When to Use

**Exclusions:**
- Plugin has unique build artifacts to exclude
- Plugin uses frameworks that generate files in non-standard locations
- Plugin has confidential files that shouldn't be in releases
- Plugin structure differs significantly from defaults

**Inclusions (Negations):**
- Need to include specific files/folders from excluded directories
- Plugin requires files that are excluded by default (e.g., specific vendor libraries, composer.json)
- Override default exclusions for special cases

### Example Workflow

**Basic exclusions:**
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

cd ..
./build-release.sh plugin-name
```

**With negation patterns:**
```bash
cd plugin-name/
cat > .buildignore << 'EOF'
# Exclude most vendor libraries (vendor/ is already excluded by default)
# But include one essential library
!vendor/
!vendor/essential-library/
!vendor/essential-library/**

# Include composer.json (excluded by default) because plugin needs it
!composer.json

# Exclude custom development files
dev-tools/
*.local.php
EOF

cd ..
./build-release.sh plugin-name
```

### Debugging
The script outputs "Loaded N custom rule(s): X inclusion(s), Y exclusion(s)" when .buildignore is found. If rules aren't working:
1. Verify `.buildignore` is in the plugin root directory
2. Check for syntax errors (unexpected characters, incorrect patterns)
3. Ensure patterns match rsync syntax
4. Remember that patterns are case-sensitive
5. For negation patterns:
   - Include parent directories first: `!vendor/` then `!vendor/my-lib/` then `!vendor/my-lib/**`
   - Use `**` to include directory contents recursively
   - Rsync processes include rules before exclude rules (script handles ordering automatically)
   - Test with `rsync -av --dry-run` to see what would be copied

## Output Structure

```
releases/
└── {plugin-name}-{version}.zip
    └── {plugin-name}/
        └── [plugin files without development artifacts]
```

The ZIP maintains the plugin folder as the root directory, ready for WordPress installation via wp-admin or WP-CLI.
