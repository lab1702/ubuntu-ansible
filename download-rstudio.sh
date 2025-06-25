#!/bin/bash

# RStudio Downloader for Linux
# 
# A robust script to automatically detect your Linux distribution and download 
# the latest version of RStudio Desktop from Posit's official servers.
#
# Author: lab1702
# Version: 1.0.0
# License: MIT
# Repository: https://github.com/lab1702/rstudio-downloader
# 
# Requirements:
#   - bash 4.0+
#   - curl or wget
#   - Standard Unix tools (grep, uname, mktemp)
#
# Supported Distributions:
#   - Ubuntu, Debian, Linux Mint, Pop!_OS, Elementary OS, Zorin OS (.deb)
#   - Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux, openSUSE (.rpm)

set -euo pipefail

# Script version
readonly SCRIPT_VERSION="1.0.0"

# API endpoints and fallback version
readonly RSTUDIO_VERSION_URL="https://download1.rstudio.org/current.ver"  # Primary version endpoint
readonly GITHUB_API_URL="https://api.github.com/repos/rstudio/rstudio/releases"  # Fallback version source
readonly DEFAULT_FALLBACK_VERSION="2023.12.1+402"  # Last known working version

# Color codes for output (check if terminal supports colors)
# shellcheck disable=SC2034  # Variables used in print functions
if [[ -t 1 ]] && [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_MISSING_DEPENDENCY=2
readonly EXIT_UNSUPPORTED_SYSTEM=3
readonly EXIT_NETWORK_ERROR=4
readonly EXIT_FILE_ERROR=5

# Global variables
declare DISTRO=""
declare VERSION=""
declare ARCH=""
declare PACKAGE_TYPE=""
declare LATEST_VERSION=""
declare LATEST_VERSION_FULL=""
declare DOWNLOAD_URL=""
declare FILENAME=""
declare DOWNLOAD_DIR=""
declare -g TEST_MODE=false
declare -g FORCE_DOWNLOAD=false
declare -g QUIET_MODE=false
declare -g DEBUG=${DEBUG:-false}

# Output functions for consistent messaging

# Print informational message to stderr (respects quiet mode)
# Args: $1 - message to print
print_info() {
    [[ "$QUIET_MODE" == true ]] && return
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

# Print error message to stderr (always shown, not affected by quiet mode)
# Args: $1 - error message to print
print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    # Also print to stdout for better visibility in non-interactive environments
    [[ ! -t 0 ]] && echo -e "${RED}[ERROR]${NC} $1"
}

# Print warning message to stderr (respects quiet mode)
# Args: $1 - warning message to print
print_warning() {
    [[ "$QUIET_MODE" == true ]] && return
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

# Print debug message to stderr (only when DEBUG=true)
# Args: $1 - debug message to print
print_debug() {
    if [[ "${DEBUG:-false}" == true ]]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Display help information
usage() {
    cat << EOF
RStudio Downloader for Linux v${SCRIPT_VERSION}

Usage: ${0##*/} [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --version       Show script version
    -t, --test          Test mode (show what would be downloaded)
    -f, --force         Force download even if file exists
    -q, --quiet         Quiet mode (minimal output)
    -d, --dir DIR       Download directory (default: current directory)
    --debug             Enable debug output

EXAMPLES:
    ${0##*/}                    # Download RStudio to current directory
    ${0##*/} --test             # Show what would be downloaded
    ${0##*/} -d /tmp           # Download to /tmp directory
    ${0##*/} --force --quiet   # Force download with minimal output

EOF
}

# System validation functions

# Check if required dependencies are installed
# Exits with appropriate error code if dependencies are missing
check_dependencies() {
    local deps=("curl" "grep")
    local missing=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing[*]}"
        print_info "Please install them using your package manager"
        exit $EXIT_MISSING_DEPENDENCY
    fi
    
    # Check for download tool
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        print_error "Neither wget nor curl is installed"
        print_info "Please install one of them using your package manager"
        exit $EXIT_MISSING_DEPENDENCY
    fi
}

# Detect and validate Linux distribution and architecture
# Sets global variables: DISTRO, VERSION, ARCH, PACKAGE_TYPE
# Exits if distribution/architecture is unsupported
detect_distro() {
    print_debug "Detecting Linux distribution..."
    
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect Linux distribution (missing /etc/os-release)"
        exit $EXIT_UNSUPPORTED_SYSTEM
    fi
    
    # Source os-release variables
    # shellcheck source=/dev/null
    source /etc/os-release
    
    DISTRO="${ID:-unknown}"
    VERSION="${VERSION_ID:-unknown}"
    ARCH=$(uname -m)
    
    print_info "Detected: ${NAME:-$DISTRO} ${VERSION} (${ARCH})"
    
    # Normalize distribution names and determine package type
    case "${DISTRO,,}" in  # Convert to lowercase
        ubuntu|debian|linuxmint|pop|elementary|zorin)
            PACKAGE_TYPE="deb"
            ;;
        fedora|rhel|centos|rocky|almalinux|scientificlinux)
            PACKAGE_TYPE="rpm"
            ;;
        opensuse*|suse*)
            PACKAGE_TYPE="rpm"
            ;;
        arch|manjaro|endeavouros)
            print_error "Arch-based distributions should use AUR or official repositories"
            print_info "Try: yay -S rstudio-desktop or paru -S rstudio-desktop"
            exit $EXIT_UNSUPPORTED_SYSTEM
            ;;
        *)
            print_error "Unsupported distribution: ${DISTRO}"
            print_info "Supported: Ubuntu, Debian, Fedora, RHEL, CentOS, openSUSE, and derivatives"
            print_info "Visit: https://posit.co/download/rstudio-desktop/"
            exit $EXIT_UNSUPPORTED_SYSTEM
            ;;
    esac
    
    # Validate architecture
    case "${ARCH}" in
        x86_64|amd64)
            # Supported
            ;;
        *)
            print_error "Unsupported architecture: ${ARCH}"
            print_info "RStudio only supports x86_64/amd64 architecture"
            exit $EXIT_UNSUPPORTED_SYSTEM
            ;;
    esac
}

# Version detection and URL construction functions

# Get latest RStudio version with multiple fallbacks
# Sets global variables: LATEST_VERSION, LATEST_VERSION_FULL
# Uses primary endpoint, GitHub API, and hardcoded fallback
get_latest_version() {
    print_info "Fetching latest RStudio version..."
    
    # Primary method: RStudio version endpoint
    print_debug "Trying primary endpoint: ${RSTUDIO_VERSION_URL}"
    if LATEST_INFO=$(curl -sf --connect-timeout 10 "${RSTUDIO_VERSION_URL}"); then
        # Extract full version with build number from the format: 2023.12.1+402.pro3
        if [[ "$LATEST_INFO" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+) ]]; then
            local version="${BASH_REMATCH[1]}"
            local build="${BASH_REMATCH[2]}"
            # Additional validation - ensure version numbers are reasonable
            if [[ "${version%%.*}" -ge 2020 ]] && [[ "${build}" -ge 100 ]]; then
                LATEST_VERSION="$version"
                LATEST_VERSION_FULL="${version}+${build}"
                print_debug "Found version from primary source: ${LATEST_VERSION_FULL}"
            fi
        fi
    fi
    
    # Fallback: GitHub API
    if [[ -z "$LATEST_VERSION" ]]; then
        print_debug "Trying GitHub API: ${GITHUB_API_URL}"
        if GITHUB_JSON=$(curl -sf --connect-timeout 10 "${GITHUB_API_URL}/latest"); then
            if [[ "$GITHUB_JSON" =~ \"tag_name\":[[:space:]]*\"v?([0-9]+\.[0-9]+\.[0-9]+)\" ]]; then
                LATEST_VERSION="${BASH_REMATCH[1]}"
                # GitHub doesn't provide build number, use a reasonable default
                LATEST_VERSION_FULL="${LATEST_VERSION}+402"
                print_debug "Found version from GitHub: ${LATEST_VERSION_FULL}"
            fi
        fi
    fi
    
    # Final fallback
    if [[ -z "$LATEST_VERSION" ]]; then
        print_warning "Could not fetch latest version, using fallback"
        LATEST_VERSION_FULL="${DEFAULT_FALLBACK_VERSION}"
        LATEST_VERSION="${LATEST_VERSION_FULL%+*}"
    fi
    
    print_info "RStudio version: ${LATEST_VERSION_FULL}"
}

# Construct download URL based on distribution and version
# Sets global variables: DOWNLOAD_URL, FILENAME
# Chooses appropriate package type and repository based on detected system
construct_download_url() {
    local version_hyphen="${LATEST_VERSION_FULL/+/-}"
    
    case "$PACKAGE_TYPE" in
        deb)
            # Determine base URL based on Ubuntu version
            local base_url="https://download1.rstudio.org/electron"
            if [[ "$DISTRO" == "ubuntu" ]]; then
                local major_version="${VERSION%%.*}"
                if [[ "$major_version" -ge 22 ]]; then
                    base_url="${base_url}/jammy/amd64"
                elif [[ "$major_version" -ge 20 ]]; then
                    base_url="${base_url}/focal/amd64"
                else
                    base_url="${base_url}/bionic/amd64"
                fi
            else
                # Default for Debian and other deb-based distros
                base_url="${base_url}/jammy/amd64"
            fi
            
            DOWNLOAD_URL="${base_url}/rstudio-${version_hyphen}-amd64.deb"
            FILENAME="rstudio-${version_hyphen}-amd64.deb"
            ;;
        rpm)
            # Use CentOS 8 builds for all RPM-based distros
            DOWNLOAD_URL="https://download1.rstudio.org/electron/centos8/x86_64/rstudio-${version_hyphen}-x86_64.rpm"
            FILENAME="rstudio-${version_hyphen}-x86_64.rpm"
            ;;
    esac
    
    print_debug "Constructed URL: ${DOWNLOAD_URL}"
}

# Download functions

# Verify download URL is accessible and secure
# Returns: 0 if URL is valid and accessible, 1 otherwise
# Validates URL is from official RStudio servers and responds with HTTP 200
verify_url() {
    print_debug "Verifying download URL..."
    
    # Basic URL validation - ensure it's HTTPS and from expected domain
    if [[ ! "$DOWNLOAD_URL" =~ ^https://download1\.rstudio\.org/ ]]; then
        print_error "Invalid download URL - not from official RStudio servers"
        print_debug "URL: ${DOWNLOAD_URL}"
        return 1
    fi
    
    local http_code
    http_code=$(curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 10 "${DOWNLOAD_URL}")
    
    if [[ "$http_code" != "200" ]]; then
        print_warning "URL verification failed (HTTP ${http_code})"
        print_debug "URL: ${DOWNLOAD_URL}"
        return 1
    fi
    
    return 0
}

# Download RStudio package with progress and verification
# Downloads to current working directory or DOWNLOAD_DIR if specified
# Performs security checks, file validation, and atomic operations
download_rstudio() {
    local download_dir="${DOWNLOAD_DIR:-$(pwd)}"
    
    # Validate filename to prevent directory traversal attacks
    if [[ "$FILENAME" =~ \.\./|^/|\.\.$ ]]; then
        print_error "Invalid filename detected: ${FILENAME}"
        exit $EXIT_FILE_ERROR
    fi
    
    local full_path="${download_dir}/${FILENAME}"
    
    # Validate download directory
    if [[ ! -d "$download_dir" ]]; then
        print_error "Download directory does not exist: ${download_dir}"
        exit $EXIT_FILE_ERROR
    fi
    
    if [[ ! -w "$download_dir" ]]; then
        print_error "Download directory is not writable: ${download_dir}"
        exit $EXIT_FILE_ERROR
    fi
    
    print_info "Download target: ${full_path}"
    print_info "Download URL: ${DOWNLOAD_URL}"
    
    # Check if file already exists
    if [[ -f "$full_path" ]] && [[ "$FORCE_DOWNLOAD" != true ]]; then
        print_warning "File already exists: ${full_path}"
        if [[ -t 0 ]]; then  # Check if stdin is a terminal
            read -p "Do you want to overwrite it? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Download cancelled"
                exit $EXIT_SUCCESS
            fi
        else
            print_error "File exists and --force not specified"
            print_info "Use --force to overwrite or remove the existing file"
            exit $EXIT_FILE_ERROR
        fi
    fi
    
    # Verify URL before downloading
    if ! verify_url; then
        print_error "Download URL appears to be invalid"
        print_info "This might be a temporary issue. Please try again later."
        exit $EXIT_NETWORK_ERROR
    fi
    
    # Create temporary file for download with secure permissions
    local temp_file
    temp_file=$(mktemp "${full_path}.XXXXXX") || {
        print_error "Failed to create temporary file"
        exit $EXIT_FILE_ERROR
    }
    chmod 600 "${temp_file}"
    trap 'rm -f "${temp_file}"' EXIT
    
    # Download with appropriate tool and security measures
    print_info "Starting download..."
    if command -v wget &> /dev/null; then
        local wget_opts=("--show-progress" "--no-cookies" "--secure-protocol=auto" "--max-redirect=3")
        [[ "$QUIET_MODE" == true ]] && wget_opts=("--quiet" "--no-cookies" "--secure-protocol=auto" "--max-redirect=3")
        
        if ! wget -O "${temp_file}" "${DOWNLOAD_URL}" "${wget_opts[@]}"; then
            print_error "Download failed"
            exit $EXIT_NETWORK_ERROR
        fi
    else
        local curl_opts=("--progress-bar" "--location" "--max-redirs" "3" "--proto" "=https")
        [[ "$QUIET_MODE" == true ]] && curl_opts=("--silent" "--location" "--max-redirs" "3" "--proto" "=https")
        
        if ! curl -o "${temp_file}" "${DOWNLOAD_URL}" "${curl_opts[@]}"; then
            print_error "Download failed"
            exit $EXIT_NETWORK_ERROR
        fi
    fi
    
    # Basic validation - check if downloaded file has reasonable size (> 50MB, < 1GB)
    local file_size
    file_size=$(stat -c%s "${temp_file}" 2>/dev/null || echo "0")
    if [[ "$file_size" -lt 52428800 ]]; then  # 50MB in bytes
        print_error "Downloaded file appears to be too small (${file_size} bytes)"
        print_info "This might indicate a download error or server issue"
        exit $EXIT_NETWORK_ERROR
    elif [[ "$file_size" -gt 1073741824 ]]; then  # 1GB in bytes
        print_error "Downloaded file appears to be too large (${file_size} bytes)"
        print_info "This might indicate a download error or security issue"
        exit $EXIT_NETWORK_ERROR
    fi
    
    # Move temporary file to final location
    if ! mv -f "${temp_file}" "${full_path}"; then
        print_error "Failed to save file to final location"
        exit $EXIT_FILE_ERROR
    fi
    
    # Remove trap since we successfully moved the file
    trap - EXIT
    
    print_info "Download completed successfully!"
    print_info "File saved to: ${full_path}"
    
    # Display installation instructions
    if [[ "$QUIET_MODE" != true ]]; then
        echo
        print_info "To install RStudio, run:"
        case "$PACKAGE_TYPE" in
            deb)
                echo "  sudo apt update"
                echo "  sudo apt install '${full_path}'"
                echo ""
                echo "  # Alternative method:"
                echo "  sudo dpkg -i '${full_path}'"
                echo "  sudo apt-get install -f  # Fix any dependency issues"
                ;;
            rpm)
                if command -v dnf &> /dev/null; then
                    echo "  sudo dnf install '${full_path}'"
                elif command -v yum &> /dev/null; then
                    echo "  sudo yum install '${full_path}'"
                elif command -v zypper &> /dev/null; then
                    echo "  sudo zypper install '${full_path}'"
                else
                    echo "  sudo rpm -i '${full_path}'"
                fi
                ;;
        esac
    fi
}

# Command line interface functions

# Parse and validate command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "RStudio Downloader v${SCRIPT_VERSION}"
                exit 0
                ;;
            -t|--test)
                TEST_MODE=true
                shift
                ;;
            -f|--force)
                FORCE_DOWNLOAD=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -d|--dir)
                if [[ -z "${2:-}" ]]; then
                    print_error "Option $1 requires an argument"
                    exit $EXIT_GENERAL_ERROR
                fi
                # Validate and normalize directory path
                DOWNLOAD_DIR="$(readlink -f "$2" 2>/dev/null || echo "$2")"
                shift 2
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit $EXIT_GENERAL_ERROR
                ;;
        esac
    done
}

# Main execution flow
main() {
    [[ "$QUIET_MODE" != true ]] && echo "=== RStudio Downloader for Linux v${SCRIPT_VERSION} ==="
    [[ "$QUIET_MODE" != true ]] && echo
    
    # Check dependencies first
    check_dependencies
    
    # Detect system information - use explicit error handling to prevent silent failures
    if ! detect_distro; then
        exit $EXIT_UNSUPPORTED_SYSTEM
    fi
    get_latest_version
    construct_download_url
    
    if [[ "$TEST_MODE" == true ]]; then
        print_info "Test mode results:"
        echo "  Distribution: ${DISTRO} ${VERSION}"
        echo "  Architecture: ${ARCH}"
        echo "  Package type: ${PACKAGE_TYPE}"
        echo "  Version: ${LATEST_VERSION_FULL}"
        echo "  Download URL: ${DOWNLOAD_URL}"
        echo "  Target file: ${DOWNLOAD_DIR:-$(pwd)}/${FILENAME}"
        
        # Verify URL in test mode
        if verify_url; then
            echo "  URL status: Valid"
        else
            echo "  URL status: Invalid or unreachable"
        fi
    else
        download_rstudio
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi