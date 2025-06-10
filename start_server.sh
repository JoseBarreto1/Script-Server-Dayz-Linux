#!/bin/bash

# ===== CONFIGURATION =====
PROTON_DIR="$HOME/.steam/steam/steamapps/common/Proton 9.0 (Beta)"
PROTON_RUN="$PROTON_DIR/proton"
SERVER_DIR="$HOME/.steam/steam/steamapps/common/DayZServer"
SERVER_EXE="DayZServer_x64.exe"
SCRIPT_DIR="$SERVER_DIR/script_server_linux"
MOD_ID_FILE="mod_ids.txt"

SERVER_MODS='-serverMod=servermod'
SERVER_PORT='-port=2302'
SERVER_CPU='-cpuCount=2'
SERVER_OTHERS='-dologs -adminlog -netlog -freezecheck'

CONFIG="-config=serverDZ.cfg"
PROFILES="-profiles=profiles"

# ===== PREPARE MOD LIST =====
MODS_SUBDIR="mods/"

if [ ! -f "$SCRIPT_DIR/$MOD_ID_FILE" ]; then
    echo "❌ File mod_ids.txt not found!"
    exit 1
fi

MODS_ID=$(<"$SCRIPT_DIR/$MOD_ID_FILE")
MODS_ID="${MODS_ID//\"/}"  # Remove quotes
MODS_ID="${MODS_ID// /}"   # Remove spaces
MODS_ID="${MODS_ID//$'\n'/}"  # Remove newlines
MODS_ID="${MODS_ID//$'\t'/}"  # (Optional) Remove tabs

MODS_PARAM_TEMP=""
IFS=';' read -ra IDS <<< "$MODS_ID"
for id in "${IDS[@]}"; do
    MODS_PARAM_TEMP+="${MODS_SUBDIR}${id};"
done

if [[ -z "$MODS_PARAM_TEMP" ]]; then
    echo "⚠️ No mod was loaded, check the mod_ids.txt file"
    exit 1
fi

# ===== Remove last semicolon =====
MODS_PARAM_TEMP="${MODS_PARAM_TEMP::-1}"

MODS="-mod=${MODS_PARAM_TEMP}"
echo "✅ All mods have been formatted."

# ===== PREFIX AND REQUIRED VARIABLES =====
STEAM_COMPAT_DATA_PATH="$HOME/.steam/steam/steamapps/compatdata"
STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"

export STEAM_COMPAT_DATA_PATH
export STEAM_COMPAT_CLIENT_INSTALL_PATH

# ===== CLEANUP LOGS =====
echo "🧹 Deleting .RPT, .log and .mdmp files in: $SERVER_DIR/profiles"
rm -f "$SERVER_DIR"/profiles/*.RPT "$SERVER_DIR"/profiles/*.ADM "$SERVER_DIR"/profiles/*.log "$SERVER_DIR"/profiles/*.mdmp
echo "✅ Cleanup completed."

# ===== EXECUTION =====
cd "$SERVER_DIR" || { echo "❌ Could not enter server directory."; exit 1; }

echo "🚀 Starting DayZ server with Proton..."
"$PROTON_RUN" run "./$SERVER_EXE" $CONFIG $PROFILES "$MODS" "$SERVER_MODS" "$SERVER_PORT" "$SERVER_CPU" "$SERVER_OTHERS" &

SERVER_LAUNCH_PID=$!

if ! kill -0 "$SERVER_LAUNCH_PID" 2>/dev/null; then
    echo "❌ Failed to start server with Proton."
    exit 1
fi

# Wait a bit for the process to start
sleep 5

# Capture all real process PIDs (children of Proton)
SERVER_PIDS=$(pgrep -u "$USER" -f "$SERVER_EXE")

# Check if PID was successfully captured
if [[ -n "$SERVER_PIDS" ]]; then
    echo "✅ Server started with PIDs: $SERVER_PIDS"
else
    echo "❌ Could not capture the server PID."
fi

# ===== TIME UNTIL NEXT RESTART =====

# Get current hour and minute
nowHour=$((10#$(date +%H)))
nowMin=$((10#$(date +%M)))

echo "Current time: $nowHour:$nowMin"

# Convert current time to minutes since midnight
totalNowMins=$((nowHour * 60 + nowMin))
echo "Minutes since midnight: $totalNowMins"

# Restart interval (every 6 hours = 360 minutes)
interval=360

# Calculate next restart time in minutes since midnight
nextRestart=$(( (totalNowMins / interval + 1) * interval ))

# Adjust for end of day (1440 minutes)
if [ "$nextRestart" -ge 1440 ]; then
    nextRestart=1440
    echo "Adjusting to midnight restart: $nextRestart"
fi

# Calculate remaining minutes until next restart
waitMins=$((nextRestart - totalNowMins))
echo "Remaining minutes: $waitMins"

# Convert to seconds
waitSecs=$((waitMins * 60))
echo "Next restart in $waitMins minutes ($waitSecs seconds)."

# Wait until next restart
sleep "$waitSecs"

# Shutdown processes (adjust based on real process name)
echo "Shutting down server..."

if [[ -n "$SERVER_PIDS" ]]; then
    echo "🛑 Shutting down the following PIDs: $SERVER_PIDS"
    kill $SERVER_PIDS
    sleep 2
    for pid in $SERVER_PIDS; do
        if ps -p "$pid" > /dev/null; then
            kill -9 "$pid"
        fi
    done
else
    echo "⚠️ No server process found to terminate."
fi

echo "$(date +%T) Server restarting..."

# Wait 10 seconds before restarting
sleep 10

# ===== Restart =====
exec "$SCRIPT_DIR/start_server.sh"
