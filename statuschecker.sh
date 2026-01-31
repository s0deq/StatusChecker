if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <input_file> [output_file]"
    echo "  Default output: grouped_results.txt"
    exit 1
fi

input_file="$1"
output_file="${2:-grouped_results.txt}"

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found!"
    exit 1
fi

echo "Reading URLs from: $input_file"
echo "Results will be grouped and saved to: $output_file"
echo ""

# Temporary files for grouping
tmp_200=$(mktemp)
tmp_404=$(mktemp)
tmp_3xx=$(mktemp)
tmp_error=$(mktemp)
tmp_timeout=$(mktemp)

# Clear output file
> "$output_file"

echo "Checking URLs..." | tee -a "$output_file"
echo "----------------------------------------" | tee -a "$output_file"

while IFS= read -r url || [[ -n "$url" ]]; do
    # Skip empty lines and comments
    [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

    echo -n "$url → " | tee -a "$output_file"

    status=$(curl -s -L -o /dev/null -w "%{http_code}" \
             --max-time 15 \
             --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
             "$url" 2>/dev/null)

    if [ -z "$status" ]; then
        echo "Failed / timeout" | tee -a "$output_file"
        echo "$url" >> "$tmp_timeout"
    elif [ "$status" = "200" ]; then
        echo "Active (200 OK)" | tee -a "$output_file"
        echo "$url" >> "$tmp_200"
    elif [ "$status" = "404" ]; then
        echo "Not found (404)" | tee -a "$output_file"
        echo "$url" >> "$tmp_404"
    elif [[ "$status" =~ ^3 ]]; then
        final=$(curl -s -L -o /dev/null -w "%{url_effective}" --max-time 10 "$url" 2>/dev/null)
        echo "Redirected ($status) → ${final:-?}" | tee -a "$output_file"
        echo "$url" >> "$tmp_3xx"
    else
        echo "Error ($status)" | tee -a "$output_file"
        echo "$url" >> "$tmp_error"
    fi

done < "$input_file"

echo "----------------------------------------" | tee -a "$output_file"
echo "" | tee -a "$output_file"

# Final grouped summary
{
    echo "Active (200 OK):"
    if [ -s "$tmp_200" ]; then
        cat "$tmp_200" | sort -u
    else
        echo "  (none)"
    fi
    echo ""

    echo "Redirected (3xx):"
    if [ -s "$tmp_3xx" ]; then
        cat "$tmp_3xx" | sort -u
    else
        echo "  (none)"
    fi
    echo ""

    echo "Not found (404):"
    if [ -s "$tmp_404" ]; then
        cat "$tmp_404" | sort -u
    else
        echo "  (none)"
    fi
    echo ""

    echo "Other errors:"
    if [ -s "$tmp_error" ]; then
        cat "$tmp_error" | sort -u
    else
        echo "  (none)"
    fi
    echo ""

    echo "Timeouts / connection failed:"
    if [ -s "$tmp_timeout" ]; then
        cat "$tmp_timeout" | sort -u
    else
        echo "  (none)"
    fi
    echo ""

    echo "Done. ($(wc -l < "$input_file" | xargs) URLs processed)"
} | tee -a "$output_file"

# Clean up temporary files
rm -f "$tmp_200" "$tmp_404" "$tmp_3xx" "$tmp_error" "$tmp_timeout"

echo ""
echo "Full grouped results saved to: $output_file"