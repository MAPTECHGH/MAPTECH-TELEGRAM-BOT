#!/bin/bash

TOKEN="7398127644:AAG63cejxNRpHFj8BiL_Vmo4QJGCezbhyfU"
CHAT_ID=""
DB_FILE="db.json"
LOG_FILE="bot.log"

# Initialize the database file
if [[ ! -f "$DB_FILE" ]]; then
  echo "{}" > "$DB_FILE"
fi

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

# Generate a six-digit alphanumeric code
generate_code() {
  echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)
}

# Send a message via Telegram
send_message() {
  local chat_id=$1
  local text=$2
  curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d "chat_id=$chat_id&text=$text" > /dev/null
}

# Add user with access duration
grant_access() {
  local user_id=$1
  local duration=$2
  local access_code=$(generate_code)
  local expiry_date=$(date -d "+$duration days" +"%Y-%m-%d %H:%M:%S")
  jq --arg id "$user_id" --arg code "$access_code" --arg expiry "$expiry_date" \
    '.users[$id] = {code: $code, expiry: $expiry}' "$DB_FILE" > tmp.json && mv tmp.json "$DB_FILE"
  send_message "$user_id" "Access granted. Your code is: $access_code, valid until: $expiry_date"
  log "Granted access to $user_id for $duration days. Code: $access_code"
}

# Show users with access
show_users() {
  local users=$(jq '.users' "$DB_FILE")
  send_message "$CHAT_ID" "Users with access: $users"
}

# Show access code
show_code() {
  local user_id=$1
  local code=$(jq -r --arg id "$user_id" '.users[$id].code' "$DB_FILE")
  send_message "$user_id" "Your access code is: $code"
}

# Grant sub-admin access
grant_subadmin() {
  local user_id=$1
  jq --arg id "$user_id" '.subadmins[$id] = true' "$DB_FILE" > tmp.json && mv tmp.json "$DB_FILE"
  send_message "$user_id" "You have been granted sub-admin access."
  log "Granted sub-admin access to $user_id"
}

# Delete user access
delete_user() {
  local user_id=$1
  jq 'del(.users[$user_id])' "$DB_FILE" > tmp.json && mv tmp.json "$DB_FILE"
  send_message "$user_id" "Your access has been revoked."
  log "Deleted access for user $user_id"
}

# Backup database
backup_db() {
  cp "$DB_FILE" "$DB_FILE.bak"
  send_message "$CHAT_ID" "Backup created."
  log "Database backup created"
}

# Restore database
restore_db() {
  cp "$DB_FILE.bak" "$DB_FILE"
  send_message "$CHAT_ID" "Backup restored."
  log "Database restored from backup"
}

# Handle incoming updates
handle_updates() {
  local update_id=$(jq '.result[-1].update_id' "$LOG_FILE")
  local updates=$(curl -s "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$update_id")

  echo "$updates" | jq -c '.result[]' | while read update; do
    update_id=$(echo "$update" | jq '.update_id')
    CHAT_ID=$(echo "$update" | jq -r '.message.chat.id')
    local message=$(echo "$update" | jq -r '.message.text')

    case "$message" in
      "/start")
        send_message "$CHAT_ID" "Welcome to the bot. Use /menu to see available commands."
        ;;
      "/menu")
        send_message "$CHAT_ID" "Available commands: /grant_access, /show_users, /show_code, /grant_subadmin, /delete_user, /backup_db, /restore_db"
        ;;
      "/grant_access")
        grant_access "$CHAT_ID" 7  # Example: Granting 7 days access
        ;;
      "/show_users")
        show_users
        ;;
      "/show_code")
        show_code "$CHAT_ID"
        ;;
      "/grant_subadmin")
        grant_subadmin "$CHAT_ID"
        ;;
      "/delete_user")
        delete_user "$CHAT_ID"
        ;;
      "/backup_db")
        backup_db
        ;;
      "/restore_db")
        restore_db
        ;;
      *)
        send_message "$CHAT_ID" "Unknown command. Use /menu to see available commands."
        ;;
    esac
  done
}

# Main loop
while true; do
  handle_updates
  sleep 1
done
