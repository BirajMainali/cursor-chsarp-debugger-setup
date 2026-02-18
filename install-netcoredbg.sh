#!/usr/bin/env bash

set -e

REPO="Samsung/netcoredbg"
API="https://api.github.com/repos/$REPO/releases/latest"

echo ""
echo "Fetching latest netcoredbg release..."

release_json=$(curl -s -H "Accept: application/vnd.github+json" "$API")

assets=$(echo "$release_json" | jq -r '.assets[] | select(.name | test("linux.*(zip|tar.gz)$")) | .name + "|" + .browser_download_url + "|" + (.size|tostring)')

if [ -z "$assets" ]; then
    echo "No Linux downloadable assets found."
    exit 1
fi

echo ""
echo "Available Linux Assets:"
echo ""

i=1
declare -a asset_names
declare -a asset_urls

while IFS="|" read -r name url size; do
    size_mb=$(awk "BEGIN {printf \"%.2f\", $size/1024/1024}")
    printf "[%d] %-40s %6s MB\n" "$i" "$name" "$size_mb"
    asset_names[$i]="$name"
    asset_urls[$i]="$url"
    ((i++))
done <<< "$assets"

echo ""
read -p "Select an option (1-$((i-1))): " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
    echo "Invalid selection."
    exit 1
fi

selected_name=${asset_names[$choice]}
selected_url=${asset_urls[$choice]}

# ------------------------------
# Install path
# ------------------------------

default_path="$HOME/netcoredbg"
echo ""
echo "Warning: The install path will be cleaned and overwritten"
read -p "Enter install path (Press Enter for default: $default_path): " debugger_path

if [ -z "$debugger_path" ]; then
    debugger_path="$default_path"
fi

# Clean old installation
if [ -d "$debugger_path" ]; then
    echo ""
    echo "Existing installation detected. Removing..."
    rm -rf "$debugger_path"
fi

mkdir -p "$debugger_path"

echo ""
echo "Using install path: $debugger_path"

# ------------------------------
# Download
# ------------------------------

archive_path="$debugger_path/$selected_name"

echo ""
echo "Downloading $selected_name..."
curl -L "$selected_url" -o "$archive_path"

# ------------------------------
# Extract
# ------------------------------

echo ""
echo "Extracting files..."

if [[ "$archive_path" == *.zip ]]; then
    sudo apt install -y unzip
    unzip "$archive_path" -d "$debugger_path"
elif [[ "$archive_path" == *.tar.gz ]]; then
    tar -xzf "$archive_path" -C "$debugger_path"
else
    echo "Unsupported archive format."
    exit 1
fi

rm "$archive_path"
echo "Archive cleaned."

# Ensure executable permission
chmod +x "$debugger_path/netcoredbg/netcoredbg"

echo ""
echo "netcoredbg installed at: $debugger_path"

# ------------------------------
# launch.json generation
# ------------------------------

read -p "Enter project root directory (e.g. /home/user/Projects/MyApp): " project_root
project_root="${project_root%/}"

echo ""
read -p "Enter project path after root (e.g. src/MyApp.Api): " project_after_root
project_after_root="${project_after_root#/}"

project_name=$(basename "$project_after_root")

echo ""
echo "Project Name: $project_name"

echo ""
echo "Select .NET version:"
versions=(5 6 7 8 9 10)

for i in "${!versions[@]}"; do
    echo "[$((i+1))] net${versions[$i]}.0"
done

echo ""
read -p "Select version: " version_choice

if ! [[ "$version_choice" =~ ^[0-9]+$ ]] || [ "$version_choice" -lt 1 ] || [ "$version_choice" -gt "${#versions[@]}" ]; then
    echo "Invalid version selection."
    exit 1
fi

selected_version="net${versions[$((version_choice-1))]}.0"

vscode_dir="$project_root/.vscode"
launch_path="$vscode_dir/launch.json"

mkdir -p "$vscode_dir"

# Backup existing launch.json
if [ -f "$launch_path" ]; then
    backup="$vscode_dir/back_$(date +%Y%m%d)_launch.json"
    mv "$launch_path" "$backup"
    echo "Existing launch.json backed up."
fi

cat > "$launch_path" <<EOF
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "netcoredbg",
            "type": "coreclr",
            "request": "launch",
            "program": "\${workspaceFolder}/$project_after_root/bin/Debug/$selected_version/$project_name.dll",
            "cwd": "\${workspaceFolder}/$project_after_root",
            "pipeTransport": {
                "pipeCwd": "\${workspaceFolder}",
                "pipeProgram": "/bin/bash",
                "debuggerPath": "$debugger_path/netcoredbg/netcoredbg",
                "debuggerArgs": [
                    "--interpreter=vscode"
                ],
                "quoteArgs": true
            },
            "env": {
                "DOTNET_ENVIRONMENT": "Development"
            }
        }
    ]
}
EOF

echo ""
echo "Success: launch.json generated at $launch_path"
echo ""
echo "You're ready. Press F5 in your IDE to debug."
echo ""
