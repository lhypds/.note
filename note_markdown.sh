#!/bin/bash

# Run script for note-markdown project
# Converts all Note .txt files in TARGET_DIR to markdown

set -e  # Exit on error

# Load .env file
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    exit 1
fi

# Read TARGET_DIR from .env
TARGET_DIR=$(grep "^TARGET_DIR=" .env | cut -d '=' -f 2)

# Trim whitespace and trailing slash
TARGET_DIR=$(echo "$TARGET_DIR" | xargs | sed 's:/*$::')

if [ -z "$TARGET_DIR" ]; then
    echo "Error: TARGET_DIR not found in .env"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: TARGET_DIR '$TARGET_DIR' is not a valid directory"
    exit 1
fi

# Activate virtual environment
if [ -f "../.venv/bin/activate" ]; then
    source ../.venv/bin/activate
elif [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
else
    echo "Error: virtual environment not found. Run setup.sh first."
    exit 1
fi

echo "Running note_markdown.py on TARGET_DIR: $TARGET_DIR"
python note_markdown.py

echo "✓ Done"
