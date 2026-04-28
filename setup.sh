#!/bin/bash

# Setup script for note-markdown project
# Installs requirements and configures environment

set -e  # Exit on error

echo "Setting up note-markdown project..."

# Check if running on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    PYTHON_CMD="python3"
else
    PYTHON_CMD="python"
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv .venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source .venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing requirements..."
pip install -r requirements.txt

echo ""
echo "✓ Setup complete!"
echo "To activate the virtual environment, run: source .venv/bin/activate"
