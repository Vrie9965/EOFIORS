#!/bin/bash
# File: scripts/anniversary_replay.sh

: "${FRMENV_FBTOKEN:=${TOK_FB:-}}"

if [[ -z "$FRMENV_FBTOKEN" ]]; then
  echo "[FATAL ERROR] FRMENV_FBTOKEN is empty!"
  exit 1
fi

. "$(dirname "$0")/../config.anniversary.conf"

LOG_FILE="$(dirname "$0")/../fb/log.txt"

# initialize/read iterator
if [[ -f "${FRMENV_REPLAY_ITER_FILE}" ]]; then
	CURRENT_FRAME="$(cat "${FRMENV_REPLAY_ITER_FILE}")"
else
	CURRENT_FRAME="${replay_start_frame}"
	printf '%s' "${CURRENT_FRAME}" > "${FRMENV_REPLAY_ITER_FILE}"
fi

# validate iterator
{ [[ -z "$(<"${FRMENV_REPLAY_ITER_FILE}")" ]] || [[ "$(<"${FRMENV_REPLAY_ITER_FILE}")" -lt 1 ]] ;} && printf '%s' "1" > "${FRMENV_REPLAY_ITER_FILE}"

CURRENT_FRAME="$(<"${FRMENV_REPLAY_ITER_FILE}")"

# Search pattern: "Frame: X, Episode YY"
replay_line=$(grep "Frame: ${CURRENT_FRAME}, Episode ${replay_episode}" "$LOG_FILE" | head -n 1)

if [[ -z "$replay_line" ]]; then
	echo "[INFO] No more frames found for Episode ${replay_episode}. Anniversary replay completed."
	exit 0
fi

frame_info=$(echo "$replay_line" | awk -F 'https' '{print $1}' | sed 's/\[√\] *//')
frame_url=$(echo "$replay_line" | awk '{print $NF}')

message="Season ${replay_season}, Episode ${replay_episode}, Frame ${CURRENT_FRAME} - ${replay_message}"

echo "DEBUG: Posting to page URL: ${FRMENV_API_ORIGIN}/${FRMENV_FBAPI_VER}/194597373745170/feed?access_token=${FRMENV_FBTOKEN}"
echo "DEBUG: Replaying Season ${replay_season}, Episode ${replay_episode}, Frame ${CURRENT_FRAME}"

response=$(
  curl -s -w "\n%{http_code}" -X POST \
    -F "message=${message}" \
    -F "link=${frame_url}" \
    "${FRMENV_API_ORIGIN}/${FRMENV_FBAPI_VER}/194597373745170/feed?access_token=${FRMENV_FBTOKEN}"
)

body=$(echo "$response" | head -n 1)
status=$(echo "$response" | tail -n 1)

if [[ "$status" != "200" ]]; then
  echo "[ERROR] Failed to share $frame_url"
  echo "Facebook response: $body"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Shared: $frame_info $frame_url" | tee -a "${FRMENV_LOG_FILE}"

# increment
NEXT_FRAME="$((CURRENT_FRAME + 1))"

# save
printf '%s' "${NEXT_FRAME}" > "${FRMENV_REPLAY_ITER_FILE}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Anniversary replay completed. Next frame: ${NEXT_FRAME}" | tee -a "${FRMENV_LOG_FILE}"
exit 0
