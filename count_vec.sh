#!/bin/bash

# Help message function
show_help() {
    echo "Usage: $0 [-d <directory> | -f <file>]"
    echo
    echo "Counts RISC-V vector instructions (e.g., vadd, vle, etc.) in .s files."
    echo
    echo "Options:"
    echo "  -d <directory>   Directory containing .s files to scan"
    echo "  -f <file>        Single .s file to scan"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -d riscv-output"
    echo "  $0 -f riscv-output/main.s"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d)
            target_type="dir"
            target_path="$2"
            shift 2
            ;;
        -f)
            target_type="file"
            target_path="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate input
if [[ -z "$target_type" || -z "$target_path" ]]; then
    show_help
fi

# Perform grep depending on type
if [[ "$target_type" == "dir" ]]; then
    if [[ ! -d "$target_path" ]]; then
        echo "Error: Directory '$target_path' not found"
        exit 1
    fi
    files=("$target_path"/*.s)
elif [[ "$target_type" == "file" ]]; then
    if [[ ! -f "$target_path" ]]; then
        echo "Error: File '$target_path' not found"
        exit 1
    fi
    files=("$target_path")
fi

# Extract vector instruction counts
results=$(grep -hoP '^\s*\Kv\w+' "${files[@]}" 2>/dev/null | sort | uniq -c | sort -nr)

# Print results
if [[ -n "$results" ]]; then
    echo "$results"
    echo
else
    echo "(no vector instructions found)"
    echo
fi

# Compute and print total
total=$(echo "$results" | awk '{s+=$1} END {print s+0}')
echo "Total = $total"
