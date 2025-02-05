#!/bin/bash

# Function to check and add .gitkeep to empty directories
add_gitkeep() {
  for dir in "$1"/*/; do
    if [ -d "$dir" ]; then
      # Check if directory is empty
      if [ -z "$(ls -A "$dir")" ]; then
        # Add .gitkeep file if directory is empty
        touch "$dir/.gitkeep"
        echo "Added .gitkeep to $dir"
      fi
      # Recursively check subdirectories
      add_gitkeep "$dir"
    fi
  done
}

# Start from the provided directory or current directory if not specified
start_dir="${1:-.}"

# Start the process
add_gitkeep "$start_dir"
