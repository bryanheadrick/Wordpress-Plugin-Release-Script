# Plugin Build Release Script

This directory contains a build script to create production-ready release packages for WordPress plugins.

## Usage

### Interactive Menu (Recommended)

Run without parameters to see an interactive plugin selection menu:

```bash
./build-release.sh
```

The menu displays all available plugins with their current versions, making it easy to select which plugin to build.

### Direct Build

Specify the plugin folder name directly to build without showing a menu:

```bash
./build-release.sh woocommerce-generic-plugin
```

### Filtered Menu (Wildcard Pattern)

Use wildcard patterns to filter the plugin list in the interactive menu:

```bash
# Show only plugins starting with "woo"
./build-release.sh "woo*"

# Show only plugins ending with "-addon"
./build-release.sh "*-addon"

# Show plugins containing "commerce"
./build-release.sh "*commerce*"
```

**Important:** Always **quote the pattern** (use `"pattern"`) to prevent the shell from expanding wildcards before passing them to the script.

**Features:**
- Supports bash wildcard patterns (`*`, `?`, etc.)
- Shows filtered interactive menu with matching plugins
- Auto-selects if only one plugin matches the pattern
- Displays "Filtering plugins matching: pattern" message

**Common mistake:**
```bash
# ❌ Wrong - shell expands woo* to first matching directory
./build-release.sh woo*

# ✅ Correct - quotes prevent shell expansion
./build-release.sh "woo*"
```

## What It Does

1. **Reads plugin version** from the main plugin file's header
2. **Runs build process** (if build files detected or configured)
3. **Creates a clean copy** of the plugin, excluding development files
4. **Generates a ZIP archive** in the `releases/` directory
5. **Names the file** using format: `plugin-name-version.zip`

## Build Process

The script automatically detects and runs build tools before packaging:

### Automatic Detection (Default)

If no `.buildconfig.json` exists, the script automatically checks for and runs:

**Makefile:**
- Runs `make build` (falls back to `make` if no build target exists)

**composer.json:**
- Runs `composer install --no-dev --optimize-autoloader`
- `vendor/` directory is included by default (not excluded)
- Skips if composer is not installed

**package.json:**
- Only runs if a `"build"` script is defined
- Executes `npm install` then `npm run build`
- `node_modules/` is always excluded (only built assets are included)
- Skips if npm is not installed

### Custom Build Configuration

Create a `.buildconfig.json` file in your plugin root to customize the build process:

```json
{
  "build": [
    "composer install --no-dev --optimize-autoloader",
    "npm install --legacy-peer-deps",
    "npm run build"
  ]
}
```

**Features:**
- Specify custom build commands in any order
- Commands run sequentially in the plugin directory
- Empty `build` array skips all automatic detection
- Requires `jq` to be installed (falls back to auto-detection if not available)

**See `.buildconfig.json.example` for more examples**

## Excluded Files & Folders

The script automatically excludes default development files, and you can add custom exclusions using a `.buildignore` file.

### Default Exclusions

The following are excluded by default:

### Version Control
- `.git/` and all git-related files
- `.github/`
- `.gitignore`, `.gitattributes`, `.gitmodules`
- `.gitlab-ci.yml`, `.travis.yml`

### Development Files
- `.claude/` (AI assistant files)
- `node_modules/`
- `src/` (source files)
- `tests/`, `test/`
- `composer.json`, `composer.lock`
- `package.json`, `package-lock.json`, `yarn.lock`
- Build config files (webpack, gulp, grunt)

### Documentation (source)
- `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`
- `TODO.md`, `CLAUDE.md`
- `LICENSE.md` (plugin includes license.txt instead)

### Environment & Logs
- `.env*` files
- `*.log` files
- `*.sql` files
- `.DS_Store`, `Thumbs.db`

### Build Artifacts
- `*.map` files
- Previous `*.zip` files
- `*.tar.gz`, `*.rar`

### Code Quality Tools
- `.editorconfig`
- `.eslintrc*`, `.eslintignore`
- `.prettierrc`, `.stylelintrc`
- `phpunit.xml*`, `.phpunit.result.cache`

### Custom Exclusions with .buildignore

You can add plugin-specific exclusions by creating a `.buildignore` file in your plugin's root directory. This file works similarly to `.gitignore`:

**Create a `.buildignore` file:**
```bash
# In your plugin directory
cd your-plugin-name/
touch .buildignore
```

**Example `.buildignore` content:**
```
# Exclude source files
src/
assets/scss/

# Exclude specific files
secret-config.php
*.bak

# Exclude build artifacts
dist/uncompiled/

# Include patterns (negation) - override default exclusions
# Include a specific vendor library even though vendor/ is excluded by default
!vendor/
!vendor/my-essential-library/
!vendor/my-essential-library/**

# Include composer.json if plugin needs it at runtime
!composer.json
```

**Features:**
- One pattern per line
- Lines starting with `#` are comments
- Empty lines are ignored
- Supports wildcards (`*`, `?`, etc.)
- Trailing slashes indicate directories
- Exclusions are **additive** to the default exclusions
- **Negation support**: Patterns starting with `!` are **inclusions** that override exclusions
  - Use `!pattern` to include files/folders that would otherwise be excluded
  - Useful for including specific items from excluded directories (e.g., `!vendor/my-library/`)
  - Can override both default exclusions and custom exclusions
- See `.buildignore.example` for a complete example

## Output

```
releases/
└── plugin-name-version.zip
```

Example output:
```
releases/
└── woocommerce-generic-plugin-1.4.1.zip
```

## Features

- ✅ **Interactive menu** - Browse and select from available plugins
- ✅ **Wildcard filtering** - Filter plugin list using patterns (e.g., `"woo*"`)
- ✅ **Automated builds** - Auto-detects and runs composer, npm, and make
- ✅ **Custom build config** - Optional `.buildconfig.json` for custom workflows
- ✅ **Version detection** - Automatically reads version from plugin file
- ✅ **Clean builds** - No development files included
- ✅ **Custom exclusions** - Per-plugin `.buildignore` support with negation patterns
- ✅ **Overwrite protection** - Removes old versions before creating new ones
- ✅ **Size reporting** - Shows final archive size
- ✅ **Content verification** - Displays archive contents after build
- ✅ **Colored output** - Easy-to-read build status messages
- ✅ **Error handling** - Exits on errors with helpful messages

## Requirements

### Required
- `bash` - Shell execution
- `rsync` - File copying with exclusions
- `zip` - Archive creation
- `grep`, `awk`, `du` - Text processing (standard Unix tools)

### Optional (for build automation)
- `composer` - For PHP dependency management
- `npm` - For JavaScript builds
- `make` - For Makefile-based builds
- `jq` - For `.buildconfig.json` support (falls back to auto-detection without it)

## Notes

- The script must be run from the `plugins/` directory
- Release archives are created in `releases/` subdirectory
- Original plugin files are never modified
- The script uses temporary directories for building (automatically cleaned up)
- File permissions are preserved in the archive

## Example Output

```
Building release for: woocommerce-generic-plugin
Version: 1.4.1
Output: /path/to/releases/woocommerce-generic-plugin-1.4.1.zip

Creating temporary build directory...
Copying plugin files...
Creating release archive...
Cleaning up...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Release built successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin:   woocommerce-generic-plugin
Version:  1.4.1
Size:     36K
Location: /path/to/releases/woocommerce-generic-plugin-1.4.1.zip
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Troubleshooting

### "Plugin folder not found"
- Ensure you're running the script from the `plugins/` directory
- Check that the plugin folder name is correct (case-sensitive)

### "Version: 1.0.0" (incorrect version)
- Check that your main plugin file has a valid `Version:` header
- Ensure the version line follows WordPress plugin header format

### Permission denied
- Make the script executable: `chmod +x build-release.sh`

## Distribution

After building, the ZIP file in `releases/` is ready for:
- WordPress.org plugin repository upload
- Manual distribution to customers
- Automated deployment systems
- Version control tagging
