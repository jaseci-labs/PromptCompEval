#!/usr/bin/env bash
# Simple test to verify Terminal tab polling works

echo "Opening Terminal window and waiting for it to close..."

# Open a new Terminal tab
TAB_INFO=$(osascript <<'APPLESCRIPT'
tell application "Terminal"
    activate
    set newTab to do script "echo 'Test window - close this to continue'; exec $SHELL -l"
    return id of newTab
end tell
APPLESCRIPT
)

echo "Terminal tab ID: $TAB_INFO"
echo "Waiting for tab to close..."

# Poll until closed
while true; do
    TAB_EXISTS=$(osascript <<APPLESCRIPT 2>/dev/null
tell application "Terminal"
    set tabFound to false
    repeat with w in windows
        repeat with t in tabs of w
            try
                if id of t is equal to ${TAB_INFO} then
                    set tabFound to true
                    exit repeat
                end if
            end try
        end repeat
        if tabFound then exit repeat
    end repeat
    return tabFound
end tell
APPLESCRIPT
) || TAB_EXISTS="false"
    
    if [ "$TAB_EXISTS" != "true" ]; then
        echo "Terminal tab closed!"
        break
    fi
    echo "Still waiting... (tab exists)"
    sleep 2
done

echo "Done! The script waited until the terminal was closed."
