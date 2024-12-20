#!/usr/bin/env bash

# proompt.sh
#
# An enhanced script for crafting AI prompts from project files with support for
# modern development stacks including Ruby, Python, Rust, Go, and more.

# Default extensions covering your complete tech stack
DEFAULT_EXTENSIONS="py,js,jsx,ts,tsx,rs,go,rb,php,sh,bash,zsh,md,txt,sql,toml,yaml,yml,json,html,css,scss,env,conf,prisma,graphql,svelte,vue,astro,tf,hcl,dockerfile,ex,exs,eex,leex,heex,proto,prom,k6.js"

# File patterns to always ignore (except .env.example)
ALWAYS_IGNORE=(
    "node_modules/"
    "vendor/"
    "target/"
    "dist/"
    "build/"
    "__pycache__/"
    ".git/"
    "*.pyc"
    "*.pyo"
    "*.pyd"
    "*.so"
    "*.dylib"
    "*.dll"
    "*.class"
    "*.log"
    ".env"
    ".env.local"
    ".env.*.local"
    "*.lock"
)

is_ignored() {
    local path="$1"
    # Special case for .env.example
    if [ "$(basename "$path")" = ".env.example" ]; then
        return 1
    fi
    # Explicitly exclude .git and other VCS folders
    case "$(basename "$path")" in
        .git|.svn|.hg|.bzr|CVS) return 0 ;;
    esac
    git check-ignore -q "$path"
    return $?
}

print_tree_helper() {
    local prefix="$1"
    local path="$2"
    local entries=()

    while IFS= read -r -d $'\0' entry; do
        if ! is_ignored "$entry"; then
            entries+=("$entry")
        fi
    done < <(find "$path" -mindepth 1 -maxdepth 1 -print0 | sort -z)

    local last_index=$((${#entries[@]} - 1))

    for i in "${!entries[@]}"; do
        local entry="${entries[$i]}"
        local entry_name
        entry_name=$(basename "$entry")

        if [ -d "$entry" ]; then
            entry_name="${entry_name}/"
        fi

        if [ "$i" -eq "$last_index" ]; then
            echo "${prefix}└── ${entry_name}"
            if [ -d "$entry" ]; then
                print_tree_helper "${prefix}    " "$entry"
            fi
        else
            echo "${prefix}├── ${entry_name}"
            if [ -d "$entry" ]; then
                print_tree_helper "${prefix}│   " "$entry"
            fi
        fi
    done
}

print_tree() {
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not in a git repository"
        exit 1
    fi

    # Print the root directory
    echo "$(basename "$PWD")/"
    print_tree_helper "" "$PWD"
}

# creates a single markdown string with the contents of all the files in the project
get_combined() {
    local extensions="$1"
    local ignore_case="$2"
    local include_no_ext="$3"
    local max_file_size="$4"

    IFS=',' read -ra ext_array <<<"$extensions"

    # construct a single regex for all extensions
    local regex
    regex=$(
        IFS='|'
        printf "%s" "${ext_array[*]}"
    )

    local no_ext_regex=""
    if [ -n "$include_no_ext" ]; then
        no_ext_regex="|(^[^.]+$)"
    fi

    # Use git ls-files and filter by both gitignore and our custom ignore logic
    git ls-files | while IFS= read -r file; do
        if ! is_ignored "$file" && echo "$file" | grep -q $ignore_case -E "(\\.(${regex})$)$no_ext_regex"; then
            # Skip files larger than max_file_size
            if [ -n "$max_file_size" ]; then
                local size
                size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
                if [ "$size" -gt "$max_file_size" ]; then
                    printf "Skipping %s (size: %s bytes, max: %s bytes)\n" "$file" "$size" "$max_file_size" >&2
                    continue
                fi
            fi

            extension="${file##*.}"
            
            # Handle files without extension
            if [ "$file" = "$extension" ]; then
                extension="txt"
            fi
            
            # Special handling for specific file types
            case "$file" in
                *.k6.js)
                    extension="javascript"
                    ;;
                *.tf|*.hcl)
                    extension="hcl"
                    ;;
                *dockerfile*)
                    extension="dockerfile"
                    ;;
                .env.example)
                    extension="env"
                    ;;
            esac

            contents=$(cat "$file")
            printf "%s:\n\`\`\`%s\n%s\n\`\`\`\n\n" "$file" "$extension" "$contents"
        fi
    done
}

# Generate a summary of the project structure and key files
generate_summary() {
    printf "Project Summary:\n\n"

    # Check for common configuration files
    local config_files=(
        "package.json"
        "Cargo.toml"
        "go.mod"
        "Gemfile"
        "requirements.txt"
        "poetry.lock"
        "docker-compose.yml"
        "terraform.tf"
        ".github/workflows"
        ".env.example"
    )

    printf "Configuration Files Found:\n"
    for file in "${config_files[@]}"; do
        if [ -e "$file" ]; then
            printf "- %s\n" "$file"
        fi
    done
    printf "\n"

    # Print custom tree
    printf "Project Structure:\n"
    print_tree
    printf "\n"
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        printf "Error: %s is required but not installed. Please install it and try again.\n" "$1" >&2
        exit 1
    fi
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Options:
  -i, --ignore-case     Ignore case when matching file extensions
  -x, --extensions      Specify file extensions to include (comma-separated)
  -t, --tree           Print the project tree
  -d, --defaults       Use the default settings (recommended)
  -n, --no-ext         Include files without extensions
  -m, --max-size=SIZE  Skip files larger than SIZE bytes
  -s, --summary        Generate a project summary
  -h, --help           Show this help message and exit

Examples:
  $(basename "$0") -d -s                     # Use defaults with project summary
  $(basename "$0") -x=rb,rs,go -m=1000000    # Process specific file types with size limit
  $(basename "$0") -s                        # Generate only project summary
  $(basename "$0") -i -x=py,js,rb            # Process specific extensions, ignore case

Notes:
  - The script will include .env.example while ignoring other .env files
  - Uses git to determine which files to process
  - Custom tree implementation respects .gitignore while including .env.example
EOF
}

main() {
    check_command git

    local extensions=""
    local ignore_case=""
    local print_tree=false
    local include_no_ext=""
    local max_file_size=""
    local generate_proj_summary=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -i|--ignore-case)
            ignore_case="-iregex"
            shift
            ;;
        -x|--extensions=*)
            if [[ "$1" == "-x" ]]; then
                extensions="${2#*=}"
                shift 2
            else
                extensions="${1#*=}"
                shift
            fi
            ;;
        -t|--tree)
            print_tree=true
            shift
            ;;
        -d|--defaults)
            extensions="$DEFAULT_EXTENSIONS"
            print_tree=true
            shift
            ;;
        -n|--no-ext)
            include_no_ext="true"
            shift
            ;;
        -m|--max-size=*)
            max_file_size="${1#*=}"
            shift
            ;;
        -s|--summary)
            generate_proj_summary=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            printf "Unknown option: %s\n" "$1" >&2
            show_usage
            exit 1
            ;;
        esac
    done

    if [ -z "$extensions" ] && [ -z "$include_no_ext" ]; then
        printf "ERROR: Extensions cannot be empty. Did you mean to pass the \`-n\` flag to include files without extensions?\n" >&2
        exit 1
    fi

    if $generate_proj_summary; then
        generate_summary
    fi

    if $print_tree; then
        print_tree
        printf "\n"
    fi

    get_combined "$extensions" "$ignore_case" "$include_no_ext" "$max_file_size"
}

main "$@"