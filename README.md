`statuschecker.sh` checks a list of URLs and groups them by result: **200 (active)**, **404 (not found)**, **3xx (redirects)**, **other HTTP errors**, and **timeouts**. It also detects **soft 404s** (pages that return `200 OK` but display “not found” content), which is especially useful on social sites.

---

## Features

- Read URLs from a file (**one URL per line**)
- Group results by:
  - `200` Active
  - `404` Not Found
  - `3xx` Redirected (any `300–399`)
  - Other HTTP status codes (e.g., `500`, `403`, etc.)
  - `timeout` (failed connections / timeouts)
  - `inactive` (soft 404s: `200` with “not found” indicators)
- Optional filtering: output only specific groups (e.g., only `200` and `404`)
- Write results to a file or print to console only

---

## Requirements

- Bash (Linux/macOS, or WSL on Windows)
- Common CLI tools typically available on Unix systems  
  (exact dependencies depend on implementation—commonly `curl`, `grep`, `awk`, etc.)

---

## Installation

Clone the repo and make the script executable:

```bash
git clone StatusChecker.git
cd StatusChecker
chmod +x statuschecker.sh
Usage
bash statuschecker.sh [OPTIONS] <input_file> [output_file]
Arguments
input_file (required)
File containing one URL per line.

output_file (optional)
Where to save grouped results.

Default: Result.txt
Use - to print only to console (no file written)
Options
-h, --help
Show help and exit

--version
Show version and exit

-f, --filter CODES
Filter groups by status codes (comma-separated).

Supported values:

200 → Active
404 → Not found
3xx → Redirected (any 300–399)
Any other number (e.g., 500) → Only that HTTP status code
timeout → Timeouts / failed connections
inactive → Soft 404s (HTTP 200 with “not found” content)
Examples
Run using default output file (Result.txt):

bash statuschecker.sh urls.txt
Filter output to only 200 and 404, writing to a custom file:

bash statuschecker.sh --filter 200,404 input.txt Result-200-404.txt
Show only timeouts and print to console (no file):

bash statuschecker.sh links.txt --filter timeout -
Show help:

bash statuschecker.sh --help
Input File Format
Example urls.txt:
https://example.com
https://example.com/does-not-exist
https://github.com
Output
The script groups URLs into labeled sections based on the final classification (active, not found, redirects, errors, timeout, inactive). If --filter is used, only the requested groups are included in the output.

Notes on Soft 404 Detection
Some platforms return 200 OK even when a page/profile doesn’t exist and show a “not found” message in the HTML. This script attempts to detect those cases and classifies them as:

inactive (soft 404)
The exact matching rules depend on the script’s implementation (keywords/patterns).

Troubleshooting
“Permission denied”: run chmod +x statuschecker.sh
All URLs show timeout: check network/DNS access, proxy/VPN, or firewall rules
Unexpected classifications: soft-404 detection may need tuning for your target sites
Contributing
PRs and issues are welcome:

improvements to grouping/formatting
better soft-404 detection patterns
performance improvements (parallelism, retries)
compatibility fixes across platforms
License
Add your license here (e.g., MIT). If you don’t have one yet, create a LICENSE file and reference it here.


