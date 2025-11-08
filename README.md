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

Alternatively, specify the plugin folder name directly:

```bash
./build-release.sh [plugin-folder-name]
```

### Example

```bash
./build-release.sh woocommerce-purchase-order-upload-addon
```

## What It Does

1. **Reads plugin version** from the main plugin file's header
2. **Creates a clean copy** of the plugin, excluding development files
3. **Generates a ZIP archive** in the `releases/` directory
4. **Names the file** using format: `plugin-name-version.zip`

## Excluded Files & Folders

The script automatically excludes:

### Version Control
- `.git/` and all git-related files
- `.github/`
- `.gitignore`, `.gitattributes`, `.gitmodules`
- `.gitlab-ci.yml`, `.travis.yml`

### Development Files
- `.claude/` (AI assistant files)
- `node_modules/`
- `vendor/` (Composer dependencies)
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

## Output

```
releases/
└── plugin-name-version.zip
```

Example output:
```
releases/
└── woocommerce-purchase-order-upload-addon-1.4.1.zip
```

## Features

- ✅ **Version detection** - Automatically reads version from plugin file
- ✅ **Clean builds** - No development files included
- ✅ **Overwrite protection** - Removes old versions before creating new ones
- ✅ **Size reporting** - Shows final archive size
- ✅ **Content verification** - Displays archive contents after build
- ✅ **Colored output** - Easy-to-read build status messages
- ✅ **Error handling** - Exits on errors with helpful messages

## Requirements

- `bash`
- `rsync`
- `zip`
- `grep`, `awk`, `du` (standard Unix tools)

## Notes

- The script must be run from the `plugins/` directory
- Release archives are created in `releases/` subdirectory
- Original plugin files are never modified
- The script uses temporary directories for building (automatically cleaned up)
- File permissions are preserved in the archive

## Example Output

```
Building release for: woocommerce-purchase-order-upload-addon
Version: 1.4.1
Output: /path/to/releases/woocommerce-purchase-order-upload-addon-1.4.1.zip

Creating temporary build directory...
Copying plugin files...
Creating release archive...
Cleaning up...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Release built successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin:   woocommerce-purchase-order-upload-addon
Version:  1.4.1
Size:     36K
Location: /path/to/releases/woocommerce-purchase-order-upload-addon-1.4.1.zip
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
