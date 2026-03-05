#!/bin/bash
# Setup script to install git hooks for PasteShelf development
# Run this script once after cloning the repository.

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Setting up git hooks for PasteShelf..."

# Get the root directory of the git repository
ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

# Create symlink for pre-commit hook
if [ -L ".git/hooks/pre-commit" ]; then
    echo -e "${YELLOW}Pre-commit hook already installed, updating...${NC}"
    rm .git/hooks/pre-commit
fi

ln -s ../../scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo ""
echo "The following hooks are now active:"
echo "  - pre-commit: Runs SwiftLint and SwiftFormat before each commit"
