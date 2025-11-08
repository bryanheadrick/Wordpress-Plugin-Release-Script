#!/bin/bash

# Build Release Script for WordPress Plugins
# Usage: ./build-release.sh [plugin-folder-name]
# Example: ./build-release.sh woocommerce-purchase-order-upload-addon
# If no parameter is provided, an interactive menu will be shown

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to scan for plugin directories
scan_plugins() {
    local plugins=()

    # Find directories that contain a PHP file (likely plugins)
    while IFS= read -r dir; do
        local dirname=$(basename "$dir")
        # Exclude system directories, the script itself, and symlinks
        if [[ "$dirname" != "releases" && "$dirname" != "." && "$dirname" != ".." && "$dirname" != "plugins" ]]; then
            # Skip if directory is a symlink
            if [ -L "$dir" ]; then
                continue
            fi
            # Check if directory contains PHP files
            if find "$dir" -maxdepth 1 -name "*.php" -type f 2>/dev/null | grep -q .; then
                plugins+=("$dirname")
            fi
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -type d 2>/dev/null)

    printf '%s\n' "${plugins[@]}"
}

# Function to display plugin selection menu
select_plugin() {
    local plugins=()
    mapfile -t plugins < <(scan_plugins | sort)

    if [ ${#plugins[@]} -eq 0 ]; then
        echo -e "${RED}Error: No plugin directories found${NC}" >&2
        exit 1
    fi

    # Output menu to stderr so it doesn't get captured by command substitution
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}" >&2
    echo -e "${CYAN}║${NC}         ${GREEN}WordPress Plugin Release Builder${NC}              ${CYAN}║${NC}" >&2
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}" >&2
    echo "" >&2
    echo -e "${YELLOW}Select a plugin to build:${NC}" >&2
    echo "" >&2

    local i=1
    for plugin in "${plugins[@]}"; do
        # Try to get version from plugin file
        local plugin_file="$SCRIPT_DIR/$plugin/$plugin.php"
        local version=""

        if [ ! -f "$plugin_file" ]; then
            # Look for PHP files with "Plugin Name:" header (indicates main plugin file)
            plugin_file=$(grep -l "Plugin Name:" "$SCRIPT_DIR/$plugin"/*.php 2>/dev/null | head -n 1)
            if [ -z "$plugin_file" ]; then
                # Fall back to first PHP file found
                plugin_file=$(find "$SCRIPT_DIR/$plugin" -maxdepth 1 -name "*.php" -type f | head -n 1)
            fi
        fi

        if [ -f "$plugin_file" ]; then
            version=$(grep -i "Version:" "$plugin_file" | head -1 | awk -F: '{print $2}' | tr -d ' ' | tr -d '\r')
        fi

        if [ -n "$version" ]; then
            printf "${BLUE}  [%2d]${NC} %-50s ${GREEN}v%s${NC}\n" "$i" "$plugin" "$version" >&2
        else
            printf "${BLUE}  [%2d]${NC} %-50s ${YELLOW}(version unknown)${NC}\n" "$i" "$plugin" >&2
        fi
        i=$((i + 1))
    done

    echo "" >&2
    echo -e "${BLUE}  [ 0]${NC} ${RED}Cancel${NC}" >&2
    echo "" >&2
    echo -ne "${YELLOW}Enter selection [0-${#plugins[@]}]:${NC} " >&2

    local selection
    read -r selection

    # Validate input
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid selection${NC}" >&2
        exit 1
    fi

    if [ "$selection" -eq 0 ]; then
        echo -e "${YELLOW}Cancelled${NC}" >&2
        exit 0
    fi

    if [ "$selection" -lt 1 ] || [ "$selection" -gt ${#plugins[@]} ]; then
        echo -e "${RED}Invalid selection: $selection${NC}" >&2
        exit 1
    fi

    # Return selected plugin to stdout (arrays are 0-indexed, but menu is 1-indexed)
    echo "${plugins[$((selection - 1))]}"
}

# Check if plugin folder is provided
if [ -z "$1" ]; then
    PLUGIN_FOLDER=$(select_plugin)
    echo ""
else
    PLUGIN_FOLDER="$1"
fi

PLUGIN_PATH="$SCRIPT_DIR/$PLUGIN_FOLDER"

# Verify plugin folder exists
if [ ! -d "$PLUGIN_PATH" ]; then
    echo -e "${RED}Error: Plugin folder '$PLUGIN_FOLDER' not found${NC}"
    echo "Path checked: $PLUGIN_PATH"
    exit 1
fi

# Create releases directory if it doesn't exist
RELEASES_DIR="$SCRIPT_DIR/releases"
mkdir -p "$RELEASES_DIR"

# Get version from plugin file
PLUGIN_FILE="$PLUGIN_PATH/$PLUGIN_FOLDER.php"
if [ ! -f "$PLUGIN_FILE" ]; then
    # Look for PHP files with "Plugin Name:" header (indicates main plugin file)
    PLUGIN_FILE=$(grep -l "Plugin Name:" "$PLUGIN_PATH"/*.php 2>/dev/null | head -n 1)
    if [ -z "$PLUGIN_FILE" ]; then
        # Fall back to first PHP file found
        PLUGIN_FILE=$(find "$PLUGIN_PATH" -maxdepth 1 -name "*.php" -type f | head -n 1)
    fi
fi

if [ -f "$PLUGIN_FILE" ]; then
    VERSION=$(grep -i "Version:" "$PLUGIN_FILE" | head -1 | awk -F: '{print $2}' | tr -d ' ' | tr -d '\r')
    if [ -z "$VERSION" ]; then
        VERSION="1.0.0"
    fi
else
    VERSION="1.0.0"
fi

# Create release filename
RELEASE_NAME="${PLUGIN_FOLDER}-${VERSION}"
RELEASE_ZIP="$RELEASES_DIR/${RELEASE_NAME}.zip"

echo -e "${GREEN}Building release for: ${PLUGIN_FOLDER}${NC}"
echo -e "${GREEN}Version: ${VERSION}${NC}"
echo -e "${GREEN}Output: ${RELEASE_ZIP}${NC}"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
TEMP_PLUGIN_DIR="$TEMP_DIR/$PLUGIN_FOLDER"

echo -e "${YELLOW}Creating temporary build directory...${NC}"
mkdir -p "$TEMP_PLUGIN_DIR"

# Build default exclusion list
DEFAULT_EXCLUDES=(
    '.git'
    '.git/'
    '.github'
    '.github/'
    '.claude'
    '.claude/'
    '.gitignore'
    '.gitattributes'
    '.gitmodules'
    '.gitlab-ci.yml'
    '.travis.yml'
    '.DS_Store'
    'Thumbs.db'
    'node_modules'
    'node_modules/'
    'src'
    'src/'
    'composer.lock'
    'package-lock.json'
    'yarn.lock'
    '.env'
    '.env.*'
    '*.log'
    '*.map'
    '*.sql'
    '*.zip'
    '*.tar.gz'
    '*.rar'
    'tests/'
    'test/'
    'Test/'
    'Tests/'
    'phpunit.xml'
    'phpunit.xml.dist'
    '.phpunit.result.cache'
    'webpack.config.js'
    'gulpfile.js'
    'Gruntfile.js'
    'package.json'
    'composer.json'
    '.editorconfig'
    '.eslintrc'
    '.eslintrc.js'
    '.eslintignore'
    '.prettierrc'
    '.stylelintrc'
    'README.md'
    'CHANGELOG.md'
    'CONTRIBUTING.md'
    'LICENSE.md'
    'TODO.md'
    'CLAUDE.md'
    'build-release.sh'
    '.buildignore'
)

# Check for .buildignore file and add custom exclusions
BUILDIGNORE_FILE="$PLUGIN_PATH/.buildignore"
CUSTOM_EXCLUDES=()

if [ -f "$BUILDIGNORE_FILE" ]; then
    echo -e "${CYAN}Found .buildignore file, loading custom exclusions...${NC}"

    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Trim whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -n "$line" ]; then
            CUSTOM_EXCLUDES+=("$line")
        fi
    done < "$BUILDIGNORE_FILE"

    if [ ${#CUSTOM_EXCLUDES[@]} -gt 0 ]; then
        echo -e "${CYAN}Loaded ${#CUSTOM_EXCLUDES[@]} custom exclusion(s)${NC}"
    fi
fi

# Combine default and custom excludes
ALL_EXCLUDES=("${DEFAULT_EXCLUDES[@]}" "${CUSTOM_EXCLUDES[@]}")

# Build rsync exclude arguments
EXCLUDE_ARGS=()
for exclude in "${ALL_EXCLUDES[@]}"; do
    EXCLUDE_ARGS+=("--exclude=$exclude")
done

# Copy plugin files to temp directory, excluding unwanted files
echo -e "${YELLOW}Copying plugin files...${NC}"
rsync -av "${EXCLUDE_ARGS[@]}" "$PLUGIN_PATH/" "$TEMP_PLUGIN_DIR/"

# Remove the previous release if it exists
if [ -f "$RELEASE_ZIP" ]; then
    echo -e "${YELLOW}Removing previous release...${NC}"
    rm "$RELEASE_ZIP"
fi

# Create zip archive
echo -e "${YELLOW}Creating release archive...${NC}"
cd "$TEMP_DIR"
zip -r "$RELEASE_ZIP" "$PLUGIN_FOLDER" -q

# Calculate file size
FILE_SIZE=$(du -h "$RELEASE_ZIP" | cut -f1)

# Clean up temporary directory
echo -e "${YELLOW}Cleaning up...${NC}"
rm -rf "$TEMP_DIR"

# Success message
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Release built successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Plugin:${NC}   $PLUGIN_FOLDER"
echo -e "${GREEN}Version:${NC}  $VERSION"
echo -e "${GREEN}Size:${NC}     $FILE_SIZE"
echo -e "${GREEN}Location:${NC} $RELEASE_ZIP"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verify archive contents
echo -e "${YELLOW}Archive contents:${NC}"
unzip -l "$RELEASE_ZIP" | head -20
echo ""
echo -e "${GREEN}Release ready for distribution!${NC}"
