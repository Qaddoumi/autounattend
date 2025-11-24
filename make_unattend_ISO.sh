#!/bin/bash

# Print header
echo "==============================================================================="
echo "███████████████████████████████████████████████████████████████████████████████"
echo "==============================================================================="

# Function to create ISO file
create_iso() {
    local output_path="$1"
    local media_type="$2"
    local title="$3"
    local boot_file="$4"
    local force="$5"
    shift 5
    local source_files=("$@")  # Remaining arguments are source files
    
    # Validate source files exist
    for source_file in "${source_files[@]}"; do
        if [[ ! -f "$source_file" ]]; then
            echo "Error: Source file '$source_file' not found" >&2
            return 1
        fi
    done
    
    # Check if output file exists and force flag
    if [[ -f "$output_path" && "$force" != "true" ]]; then
        echo "Error: Output file '$output_path' already exists. Use -f flag to overwrite." >&2
        return 1
    fi
    
    # Remove existing file if force is enabled
    if [[ -f "$output_path" && "$force" == "true" ]]; then
        rm -f "$output_path"
    fi
    
    # Prepare genisoimage/mkisofs command
    local iso_cmd=""
    
    # Check which ISO creation tool is available
    if command -v genisoimage >/dev/null 2>&1; then
        iso_cmd="genisoimage"
    elif command -v mkisofs >/dev/null 2>&1; then
        iso_cmd="mkisofs"
    else
        echo "Error: Neither genisoimage nor mkisofs found. Please install one of these tools." >&2
        echo "On Ubuntu/Debian: sudo apt-get install genisoimage" >&2
        echo "On RHEL/CentOS: sudo yum install genisoimage" >&2
        echo "On Arch: sudo pacman -S cdrtools --needed --noconfirm" >&2
        return 1
    fi
    
    # Build command arguments
    local cmd_args=()
    cmd_args+=("-V" "$title")  # Volume label
    cmd_args+=("-J")           # Joliet extensions for Windows compatibility
    cmd_args+=("-R")           # Rock Ridge extensions for Unix compatibility
    cmd_args+=("-o" "$output_path")  # Output file
    
    # Add boot options if boot file is specified
    if [[ -n "$boot_file" && -f "$boot_file" ]]; then
        echo "Adding boot file: $boot_file"
        cmd_args+=("-b" "$(basename "$boot_file")")  # Boot image
        cmd_args+=("-c" "boot.cat")                  # Boot catalog
        cmd_args+=("-no-emul-boot")                  # No emulation
        cmd_args+=("-boot-load-size" "4")            # Boot load size
        cmd_args+=("-boot-info-table")               # Boot info table
    fi
    
    # Create a temporary directory to stage files
    local temp_dir=$(mktemp -d)
    local cleanup_temp=true
    
    # Copy all source files to temp directory
    for source_file in "${source_files[@]}"; do
        cp "$source_file" "$temp_dir/"
    done
    
    # Copy boot file if specified
    if [[ -n "$boot_file" && -f "$boot_file" ]]; then
        cp "$boot_file" "$temp_dir/"
    fi
    
    # Add the temp directory as the source
    cmd_args+=("$temp_dir")
    
    echo "Creating ISO with command: $iso_cmd ${cmd_args[*]}"
    echo "Source: ${source_files[*]}"
    echo "Output: $output_path"
    echo "Title: $title"
    echo "Media Type: $media_type"
    
    # Execute the ISO creation command
    if "$iso_cmd" "${cmd_args[@]}"; then
        echo "ISO file created successfully: $output_path"
        
        # Display file info
        if [[ -f "$output_path" ]]; then
            local file_size=$(stat -c%s "$output_path" 2>/dev/null || stat -f%z "$output_path" 2>/dev/null)
            echo "File size: $file_size bytes"
        fi
    else
        echo "Error: Failed to create ISO file" >&2
        cleanup_temp=true
        return 1
    fi
    
    # Cleanup temporary directory
    if [[ "$cleanup_temp" == "true" && -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
    
    return 0
}

# Main script execution
main() {
    local output_path=""
    local force_flag=false
    local boot_file=""
    local media_type="CDR"
    local title="autounattend"
    local source_files=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source)
                # Collect all source files until next flag
                shift
                while [[ $# -gt 0 && "$1" != -* ]]; do
                    source_files+=("$1")
                    shift
                done
                ;;
            -o|--output)
                output_path="$2"
                shift 2
                ;;
            -t|--title)
                title="$2"
                shift 2
                ;;
            -m|--media)
                media_type="$2"
                shift 2
                ;;
            -b|--boot)
                boot_file="$2"
                shift 2
                ;;
            -f|--force)
                force_flag=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -s, --source FILE    Source file to include in ISO (default: ./autounattend.xml)"
                echo "  -o, --output FILE    Output ISO path"
                echo "  -t, --title TITLE    Volume title (default: autounattend)"
                echo "  -m, --media TYPE     Media type (default: CDR)"
                echo "  -b, --boot FILE      Boot image file"
                echo "  -f, --force          Overwrite existing output file"
                echo "  -h, --help           Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use -h or --help for usage information" >&2
                exit 1
                ;;
        esac
    done
    
    # Get absolute path for source
    for i in "${!source_files[@]}"; do
        if [[ -f "${source_files[$i]}" ]]; then
            source_files[$i]=$(realpath "${source_files[$i]}")
        else
            echo "Error: Source file '${source_files[$i]}' not found" >&2
            exit 1
        fi
    done
    
    # Generate output path if not specified
    if [[ -z "$output_path" ]]; then
        local timestamp=$(date '+%Y-%m-%d_%H-%M-%S_%N_%p')
        output_path="$(pwd)/Windows-autounattend_${timestamp}.iso"
    fi
    
    # Convert to absolute path
    output_path=$(realpath "$output_path" 2>/dev/null || echo "$output_path")
    
    echo "Configuration:"
    echo "  Source files: ${source_files[*]}"
    echo "  Output ISO: $output_path"
    echo "  Title: $title"
    echo "  Media type: $media_type"
    echo "  Force overwrite: $force_flag"
    [[ -n "$boot_file" ]] && echo "  Boot file: $boot_file"
    echo ""
    
    # Create the ISO
    create_iso "$output_path" "$media_type" "$title" "$boot_file" "$force_flag" "${source_files[@]}"
}

# Run main function with all arguments
main "$@"