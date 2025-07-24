#!/bin/bash

# Usage message function
usage() {
    echo "Usage: $0 [--mvnclean] [ [nosubdirs:]path...]" >&2
    echo "Concatenates files from the specified paths (or current directory if none provided)." >&2
    echo "Paths can be directories or files:" >&2
    echo "  directory         Include files recursively from the directory" >&2
    echo "  nosubdirs:directory  Include only top-level files from the directory" >&2
    echo "  file             Include the specified file directly" >&2
    echo "Options:" >&2
    echo "  --mvnclean       Search for pom.xml from each directory and run mvn clean once per unique pom.xml" >&2
    exit 1
}

# Initialize variables
MVNCLEAN=false
ROOT_DIRS=()
NO_SUBDIRS_FLAGS=()
FILES=()
ORIGINAL_ARGS=$#
declare -A POM_DIRS  # Associative array to track unique pom.xml directories

# Parse command-line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --mvnclean)
            MVNCLEAN=true
            shift
            ;;
        nosubdirs:*)
            dir="${1#nosubdirs:}"
            if [ -z "$dir" ]; then
                echo "Error: 'nosubdirs:' prefix requires a directory path" >&2
                usage
            fi
            ROOT_DIRS+=("$dir")
            NO_SUBDIRS_FLAGS+=("true")
            shift
            ;;
        *)
            if [ -f "$1" ]; then
                FILES+=("$1")
            elif [ -d "$1" ]; then
                ROOT_DIRS+=("$1")
                NO_SUBDIRS_FLAGS+=("false")
            else
                echo "Error: '$1' is neither a readable file nor a directory" >&2
                usage
            fi
            shift
            ;;
    esac
done

# Set root directories to current directory if none provided and no files
if [ ${#ROOT_DIRS[@]} -eq 0 ] && [ ${#FILES[@]} -eq 0 ]; then
    ROOT_DIRS=(".")
    NO_SUBDIRS_FLAGS=("false")
fi

# If no arguments were provided at all and no options, inform user about default and show usage
if [ "$ORIGINAL_ARGS" -eq 0 ] && [ "$MVNCLEAN" = false ]; then
    echo "No paths provided, defaulting to current directory (.)."
    usage
fi

# Validate directories
for ((i=0; i<${#ROOT_DIRS[@]}; i++)); do
    dir="${ROOT_DIRS[$i]}"
    if [ ! -d "$dir" ]; then
        echo "Error: '$dir' is not a directory" >&2
        usage
    fi
    if [ ! -r "$dir" ]; then
        echo "Error: '$dir' is not readable" >&2
        usage
    fi
done

# Validate files
for file in "${FILES[@]}"; do
    if [ ! -r "$file" ]; then
        echo "Error: '$file' is not readable" >&2
        usage
    fi
done

# Handle --mvnclean option (only for directories)
if [ "$MVNCLEAN" = true ]; then
    for dir in "${ROOT_DIRS[@]}"; do
        echo "Searching for pom.xml starting from $dir..."
        current_dir=$(realpath "$dir")
        while [ "$current_dir" != "/" ]; do
            if [ -f "$current_dir/pom.xml" ]; then
                echo "Found pom.xml in $current_dir."
                POM_DIRS["$current_dir"]=1  # Store unique pom.xml directory
                break
            fi
            current_dir=$(dirname "$current_dir")
        done
        if [ "$current_dir" = "/" ] && [ ! -f "/pom.xml" ]; then
            echo "No pom.xml found in $dir or its parent directories."
        fi
    done

    # Run mvn clean for each unique pom.xml directory
    for pom_dir in "${!POM_DIRS[@]}"; do
        echo "Running mvn clean in $pom_dir."
        cd "$pom_dir" || exit 1
        mvn clean || exit 1
        cd - >/dev/null || exit 1
    done
fi

# Output what the script will do
total_paths=$(( ${#ROOT_DIRS[@]} + ${#FILES[@]} ))
if [ $total_paths -eq 1 ]; then
    if [ ${#FILES[@]} -eq 1 ]; then
        echo "Concatenating file ${FILES[0]} into part files."
    elif [ "${NO_SUBDIRS_FLAGS[0]}" = true ]; then
        echo "Concatenating top-level files from ${ROOT_DIRS[0]} into part files."
    else
        echo "Concatenating files from ${ROOT_DIRS[0]} into part files."
    fi
else
    echo "Concatenating files from the following paths:"
    for ((i=0; i<${#ROOT_DIRS[@]}; i++)); do
        if [ "${NO_SUBDIRS_FLAGS[$i]}" = true ]; then
            echo "  [top-level only] ${ROOT_DIRS[$i]}"
        else
            echo "  ${ROOT_DIRS[$i]}"
        fi
    done
    for file in "${FILES[@]}"; do
        echo "  [file] $file"
    done
fi

# Constants
HEADER="concatenated sources"
SEPARATOR="---------------------------------------------"
CHAR_LIMIT=100000
PART_PREFIX="$(basename "$(pwd)")-part"
PART_EXT=".txt"

# Remove existing part files
rm -f "${PART_PREFIX}"*"${PART_EXT}"

# Initialize variables
part_num=1
char_count=0
output_file="${PART_PREFIX}${part_num}${PART_EXT}"

# Write header to first file
echo "$HEADER" > "$output_file"
char_count=$(( ${#HEADER} + 1 )) # +1 for newline

# Process directories
for ((i=0; i<${#ROOT_DIRS[@]}; i++)); do
    dir="${ROOT_DIRS[$i]}"
    no_subdirs="${NO_SUBDIRS_FLAGS[$i]}"

    # Build find command based on no-subdirs flag for this directory
    if [ "$no_subdirs" = true ]; then
        FIND_CMD="find \"$dir\" -maxdepth 1 -type f -name \"*.*\" -not -path \"./.*/*\" -print0"
    else
        FIND_CMD="find \"$dir\" -type f -name \"*.*\" -not -path \"./.*/*\" -print0"
    fi

    # Find all files in specified directory and process them
    eval "$FIND_CMD" | while IFS= read -r -d '' file; do
        # Print filename to console
        echo "$file"

        # Skip if file is not readable
        if [ ! -r "$file" ]; then
            echo "Warning: Skipping unreadable file: $file" >&2
            continue
        fi

        # Calculate character count for this file's contribution
        separator_count=${#SEPARATOR}
        file_marker="file $file:"
        file_marker_count=${#file_marker}
        content_count=$(cat "$file" 2>/dev/null | wc -c | tr -d ' ') || content_count=0
        if [ -z "$content_count" ] || ! [[ "$content_count" =~ ^[0-9]+$ ]]; then
            echo "Warning: Could not determine size of $file, assuming 0 characters" >&2
            content_count=0
        fi
        total_addition=$(( separator_count + 1 + file_marker_count + 1 + content_count + 1 )) # +1 for each newline

        # Check if adding this file exceeds the limit
        if [ $(( char_count + total_addition )) -gt $CHAR_LIMIT ]; then
            # Start a new file
            part_num=$(( part_num + 1 ))
            output_file="${PART_PREFIX}${part_num}${PART_EXT}"
            echo "$HEADER" > "$output_file"
            char_count=$(( ${#HEADER} + 1 ))
        fi

        # Append to current file
        echo "$SEPARATOR" >> "$output_file"
        echo "$file_marker" >> "$output_file"
        cat "$file" >> "$output_file" 2>/dev/null || echo "Warning: Failed to append $file" >&2
        echo "" >> "$output_file" # Extra newline for consistency

        # Update character count
        char_count=$(( char_count + total_addition ))
    done
done

# Process individual files
for file in "${FILES[@]}"; do
    # Print filename to console
    echo "$file"

    # Skip if file is not readable (already validated, but for consistency)
    if [ ! -r "$file" ]; then
        echo "Warning: Skipping unreadable file: $file" >&2
        continue
    fi

    # Calculate character count for this file's contribution
    separator_count=${#SEPARATOR}
    file_marker="file $file:"
    file_marker_count=${#file_marker}
    content_count=$(cat "$file" 2>/dev/null | wc -c | tr -d ' ') || content_count=0
    if [ -z "$content_count" ] || ! [[ "$content_count" =~ ^[0-9]+$ ]]; then
        echo "Warning: Could not determine size of $file, assuming 0 characters" >&2
        content_count=0
    fi
    total_addition=$(( separator_count + 1 + file_marker_count + 1 + content_count + 1 )) # +1 for each newline

    # Check if adding this file exceeds the limit
    if [ $(( char_count + total_addition )) -gt $CHAR_LIMIT ]; then
        # Start a new file
        part_num=$(( part_num + 1 ))
        output_file="${PART_PREFIX}${part_num}${PART_EXT}"
        echo "$HEADER" > "$output_file"
        char_count=$(( ${#HEADER} + 1 ))
    fi

    # Append to current file
    echo "$SEPARATOR" >> "$output_file"
    echo "$file_marker" >> "$output_file"
    cat "$file" >> "$output_file" 2>/dev/null || echo "Warning: Failed to append $file" >&2
    echo "" >> "$output_file" # Extra newline for consistency

    # Update character count
    char_count=$(( char_count + total_addition ))
done