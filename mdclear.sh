#!/bin/bash

# Clear script for note-markdown project
# Deletes the .markdown folder from the target directory

set -e  # Exit on error

# Load .env file
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    exit 1
fi

# Read NOTE_DIR from .env
NOTE_DIR=$(grep "^NOTE_DIR=" .env | cut -d '=' -f 2)

# Trim whitespace and trailing slash
NOTE_DIR=$(echo "$NOTE_DIR" | xargs | sed 's:/*$::')

if [ -z "$NOTE_DIR" ]; then
    echo "Error: NOTE_DIR not found in .env"
    exit 1
fi

MARKDOWN_PATH="$NOTE_DIR/.markdown"

# Check if .markdown folder exists
if [ ! -d "$MARKDOWN_PATH" ]; then
    echo "No .markdown folder found at: $MARKDOWN_PATH"
    exit 0
fi

# Confirm deletion
read -p "Are you sure you want to delete $MARKDOWN_PATH? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Delete the folder
rm -rf "$MARKDOWN_PATH"
echo "✓ .markdown folder deleted successfully"
