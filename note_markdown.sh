#!/bin/bash

# Run script for note-markdown project
# Converts all Note .txt files in NOTE_DIR to markdown

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

if [ ! -d "$NOTE_DIR" ]; then
    echo "Error: NOTE_DIR '$NOTE_DIR' is not a valid directory"
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

echo "Running note_markdown.py on NOTE_DIR: $NOTE_DIR"
python note_markdown.py

echo "✓ Done"
