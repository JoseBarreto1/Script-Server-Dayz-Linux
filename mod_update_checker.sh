#!/bin/bash

# ===== CONFIGURATION =====
SERVER_DIR="$HOME/.steam/steam/steamapps/common/DayZServer"
SCRIPT_DIR="$SERVER_DIR/script_server_linux"
MOD_ID_FILE="mod_ids.txt"

MODS_ID=$(<"$SCRIPT_DIR/$MOD_ID_FILE")
MODS_ID="${MODS_ID//\"/}"  # Remove quotes
MODS_ID="${MODS_ID// /}"   # Remove spaces
MODS_ID="${MODS_ID//$'\n'/}"  # Remove line breaks
MODS_ID="${MODS_ID//$'\t'/}"  # (Optional) Remove tabs

IFS=';' read -ra IDS <<< "$MODS_ID"

WEBHOOK_URL="" # add your discord webhook URL here
CACHE_FILE="$HOME/.cache/dayz_mods_update_check"
mkdir -p "$(dirname "$CACHE_FILE")"
touch "$CACHE_FILE"

echo "🚀 Starting continuous check for Steam Workshop mod updates..."
echo "⏱️ Interval: every 10 minutes"
echo "📅 Start: $(date)"
echo "------------------------------------------"

while true; do
    echo "🔄 Checking for updates... ($(date))"
    
    for id in "${IDS[@]}"; do
    	[[ -z "$id" ]] && continue  # skip empty entries (like the last one)
    	
        MOD_URL="https://steamcommunity.com/sharedfiles/filedetails/?id=$id"
        
        HTML=$(curl -s "$MOD_URL")

        # Extract mod name
        MOD_NAME=$(echo "$HTML" | grep -oP '<div class="workshopItemTitle">.*?</div>' | sed -e 's/<[^>]*>//g' | xargs)

        # Extract last updated date
        UPDATED_DATE=$(echo "$HTML" | grep -oP '<div class="detailsStatRight">.*?</div>' | sed -e 's/<[^>]*>//g' | sed -n '3p' | xargs)

        # Convert date to Unix timestamp
        if [[ -n "$UPDATED_DATE" ]]; then
            UPDATED_DATE_EN=$(echo "$UPDATED_DATE" | sed -e 's/jan\./Jan/' -e 's/fev\./Feb/' -e 's/mar\./Mar/' -e 's/abr\./Apr/' \
                                              -e 's/mai\./May/' -e 's/jun\./Jun/' -e 's/jul\./Jul/' -e 's/ago\./Aug/' \
                                              -e 's/set\./Sep/' -e 's/out\./Oct/' -e 's/nov\./Nov/' -e 's/dez\./Dec/')

	    # Remove commas and "@"
	    UPDATED_DATE_CLEAN=$(echo "$UPDATED_DATE" | sed -E 's/,//g; s/@//g' | xargs)

	    # If the year is already present
	    if [[ "$UPDATED_DATE_CLEAN" =~ [0-9]{4} ]]; then
	        DATE_TO_PARSE="$UPDATED_DATE_CLEAN"
	    else
	        CURRENT_YEAR=$(date +%Y)
	        # Move time to the end: e.g. "28 Feb 8:02am" -> "28 Feb 2025 8:02am"
	        DATE_TO_PARSE=$(echo "$UPDATED_DATE_CLEAN $CURRENT_YEAR" | awk '{print $1, $2, $4, $3}')
	    fi

	    # Convert to timestamp
	    MOD_TIMESTAMP=$(date -d "$DATE_TO_PARSE" +%s 2>/dev/null)
        
        else
            MOD_TIMESTAMP=0
        fi
        
        # Check if conversion was successful
	if [[ -z "$MOD_TIMESTAMP" ]]; then
	    echo "⚠️ [$id] $MOD_NAME — Failed to convert date: '$UPDATED_DATE' (processed: '$DATE_TO_PARSE')"
	fi

        # Load saved timestamp
        LAST_TIMESTAMP=$(grep "^$id:" "$CACHE_FILE" | cut -d: -f2)

        # Update check
        if [[ -z "$LAST_TIMESTAMP" ]]; then
            echo "📌 [$id] $MOD_NAME — First check, updated on: $UPDATED_DATE"
            if [[ "$MOD_TIMESTAMP" -gt 0 ]]; then
	        echo "$id:$MOD_TIMESTAMP" >> "$CACHE_FILE"
	    fi
        elif [[ "$MOD_TIMESTAMP" -gt "$LAST_TIMESTAMP" ]]; then
            echo "✅ [$id] $MOD_NAME — HAS BEEN UPDATED! New date: $UPDATED_DATE"
            sed -i "s/^$id:.*/$id:$MOD_TIMESTAMP/" "$CACHE_FILE"

            # Send Discord notification
            curl -s -X POST "$WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d @- <<EOF
{
  "username": "DayZ Mod Watcher",
  "content": "🧩 **Mod updated!**\n📌 Name: **$MOD_NAME**\n🆔 ID: \`$id\`\n📅 Updated on: $UPDATED_DATE\n🔗 $MOD_URL\n@everyone"
}
EOF
        else
            echo "⏸️ [$id] $MOD_NAME — No changes since: $UPDATED_DATE"
        fi

        sleep 2  # Delay between requests
    done

    echo "🕔 Waiting 10 minutes until next check..."
    echo "------------------------------------------"
    sleep 600
done
