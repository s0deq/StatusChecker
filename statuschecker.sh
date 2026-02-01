
show_help() {
    cat << 'EOF'
Usage: ./statuschecker.sh [OPTIONS] <input_file> [output_file]

Checks URLs from a file and groups them by status (200 OK, 404 Not Found, 3xx Redirects, other errors, timeouts).

Options:
  -h, --help          Show this help message and exit
  --version           Show version and exit
  -f, --filter CODES  Filter groups by status codes (comma-separated, e.g., 200,404,301)
                      - 200: Active
                      - 404: Not found
                      - 3xx: Redirected (any 300-399)
                      - Other numbers: Errors matching that code
                      - 'timeout': Failed connections/timeouts

Arguments:
  input_file          File with one URL per line (required)
  output_file         Optional – where to save grouped results
                      Default: Result.txt
                      Use '-' to print only to console (no file)

Examples:
  ./statuschecker.sh urls.txt
  ./statuschecker.sh twitter.txt --filter 200,404 Result-200-404.txt
  ./statuschecker.sh links.txt --filter timeout -
  ./statuschecker.sh --help
EOF
}
Box_st() { echo "
╔══════════════════════════════════════╗
║                                      ║
║            STATUS CHECKER            ║
║                                      ║
╚══════════════════════════════════════╝ "
}

show_version() {
    Box_st
    echo "StatusChecker v1.1"
}
# Defaults
filter_codes=()
output_file="Result.txt"

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --version)
            show_version
            exit 0
            ;;
        -f|--filter)
            shift
            IFS=',' read -r -a filter_codes <<< "$1"
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
        *)
            break
            ;;
    esac
    shift
done

# Arguments
if [ $# -lt 1 ]; then
    echo "Error: Missing input file"
    show_help
    exit 1
fi

input_file="$1"
if [ $# -gt 1 ]; then
    output_file="$2"
fi

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found!"
    exit 1
fi

if [ "$output_file" = "-" ]; then
    output_file="/dev/null"
    echo "Results will only be shown in console (no file saved)"
else
    echo "Saving grouped results to: $output_file"
fi

# Clear output file
> "$output_file" 2>/dev/null || true

# Temporary files for groups
tmp_200=$(mktemp)
tmp_404=$(mktemp)
tmp_3xx=$(mktemp)
tmp_error=$(mktemp)
tmp_timeout=$(mktemp)
Box_st
echo "Checking URLs from: $input_file" | tee -a "$output_file"
echo "Filters: ${filter_codes[*]:-(none – showing all)}" | tee -a "$output_file"
echo "----------------------------------------" | tee -a "$output_file"

while IFS= read -r url || [[ -n "$url" ]]; do
    [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

    echo -n "$url → " | tee -a "$output_file"

    status=$(curl -s -L -o /dev/null -w "%{http_code}" \
             --max-time 15 \
             --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
             "$url" 2>/dev/null)

    if [ -z "$status" ]; then
        msg="Failed to connect / timeout"
        echo "$msg" | tee -a "$output_file"
        echo "$url" >> "$tmp_timeout"
    elif [ "$status" = "200" ]; then
        msg="Active (200 OK)"
        echo "$msg" | tee -a "$output_file"
        echo "$url" >> "$tmp_200"
    elif [ "$status" = "404" ]; then
        msg="Not found (404)"
        echo "$msg" | tee -a "$output_file"
        echo "$url" >> "$tmp_404"
    elif [[ "$status" =~ ^3 ]]; then
        final_url=$(curl -s -L -o /dev/null -w "%{url_effective}" --max-time 10 "$url" 2>/dev/null)
        msg="Redirected ($status) → ${final_url:-unknown}"
        echo "$msg" | tee -a "$output_file"
        echo "$url" >> "$tmp_3xx"
    else
        msg="Error ($status)"
        echo "$msg" | tee -a "$output_file"
        echo "$url" >> "$tmp_error"
    fi
done < "$input_file"

echo "----------------------------------------" | tee -a "$output_file"
echo "" | tee -a "$output_file"

# Check if a group should be shown based on filters
should_show() {
    local group="$1"
    if [ ${#filter_codes[@]} -eq 0 ]; then
        return 0  # No filters → show all
    fi
    case "$group" in
        200) [[ " ${filter_codes[*]} " =~ " 200 " ]] && return 0 ;;
        404) [[ " ${filter_codes[*]} " =~ " 404 " ]] && return 0 ;;
        3xx) for f in "${filter_codes[@]}"; do [[ $f =~ ^3 ]] && return 0; done ;;
        error) for f in "${filter_codes[@]}"; do [ "$f" = "$status" ] && return 0; done ;;  # Note: status is per URL, but for group, assume if any non-standard
        timeout) [[ " ${filter_codes[*]} " =~ " timeout " || " ${filter_codes[*]} " =~ " 0 " ]] && return 0 ;;
    esac
    return 1
}

# Grouped summary (only show filtered groups)
{
    if should_show 200; then
        echo "Active (200 OK):"
        if [ -s "$tmp_200" ]; then
            sort -u "$tmp_200"
        else
            echo "  (none)"
        fi
        echo ""
    fi

    if should_show 3xx; then
        echo "Redirected (3xx):"
        if [ -s "$tmp_3xx" ]; then
            sort -u "$tmp_3xx"
        else
            echo "  (none)"
        fi
        echo ""
    fi

    if should_show 404; then
        echo "Not found (404):"
        if [ -s "$tmp_404" ]; then
            sort -u "$tmp_404"
        else
            echo "  (none)"
        fi
        echo ""
    fi

    if should_show error; then
        echo "Other errors:"
        if [ -s "$tmp_error" ]; then
            sort -u "$tmp_error"
        else
            echo "  (none)"
        fi
        echo ""
    fi

    if should_show timeout; then
        echo "Timeouts / failed:"
        if [ -s "$tmp_timeout" ]; then
            sort -u "$tmp_timeout"
        else
            echo "  (none)"
        fi
        echo ""
    fi

    echo "Done. ($(wc -l < "$input_file" | xargs) URLs processed)"
} | tee -a "$output_file"

# Cleanup
rm -f "$tmp_200" "$tmp_404" "$tmp_3xx" "$tmp_error" "$tmp_timeout"

echo ""
echo "Grouped results saved to: $output_file (if not '-')"