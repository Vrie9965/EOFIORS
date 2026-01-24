#!/bin/bash
# */
# Anniversary Mode: Replay episodes in order starting from episode 1
# Reuses existing posting and helper functions from the project
# /*

# Import needed scripts
. config.anniversary.conf
. scripts/helpers.sh
. scripts/post.sh

# Token is provided via environment variable from GitHub Actions
: "${FRMENV_FBTOKEN:=}"

# Check if token is provided
if [[ -z "${FRMENV_FBTOKEN}" ]]; then
	printf '%s\n' "[FATAL ERROR] Facebook token not provided." | tee -a "${FRMENV_LOG_FILE}"
	exit 1
fi

# Check all the dependencies if installed
if ! helper_depcheck curl bc ; then
	printf '%s\n' "[FATAL ERROR] Some dependencies are missing." | tee -a "${FRMENV_LOG_FILE}"
	exit 1
fi

# Validate required variables
helper_varchecker 'anniversary mode config' "${replay_episode}" "${replay_season}" "${replay_message}" || helper_statfailed 1

# Initialize or read frame iterator
if [[ -f "${FRMENV_REPLAY_ITER_FILE}" ]]; then
	CURRENT_FRAME="$(cat "${FRMENV_REPLAY_ITER_FILE}")"
else
	CURRENT_FRAME="${replay_start_frame}"
fi

# Prepare message with current frame info
TEMP_MESSAGE="$(sed -E 's_\{replay_season\}_'"${replay_season}"'_g;s_\{replay_episode\}_'"${replay_episode}"'_g;s_\{replay_frame\}_'"${CURRENT_FRAME}"'_g;s_\{\\n\}_\n_g' <<< "${replay_message}")"

# Check if frame file exists
if [[ ! -f "${FRMENV_FRAME_LOCATION}/frame_${CURRENT_FRAME}.jpg" ]]; then
	printf '%s\n' "[ERROR] Frame file not found: frame_${CURRENT_FRAME}.jpg" | tee -a "${FRMENV_LOG_FILE}"
	printf '%s\n' "[INFO] Anniversary replay completed. All frames posted." | tee -a "${FRMENV_LOG_FILE}"
	exit 0
fi

# Prepare for posting with the message variable
message="${TEMP_MESSAGE}"

# Post the frame to Facebook
if post_fp "${CURRENT_FRAME}"; then
	printf '%s\n' "[$(date '+%Y-%m-%d %H:%M:%S')] Posted: Season ${replay_season}, Episode ${replay_episode}, Frame ${CURRENT_FRAME}" | tee -a "${FRMENV_LOG_FILE}"
else
	printf '%s\n' "[ERROR] Failed to post frame ${CURRENT_FRAME}" | tee -a "${FRMENV_LOG_FILE}"
	helper_statfailed 1 "${replay_episode}" "${CURRENT_FRAME}"
fi

# Increment frame counter
((CURRENT_FRAME++))

# Save current frame position for next execution
printf '%s' "${CURRENT_FRAME}" > "${FRMENV_REPLAY_ITER_FILE}"

printf '%s\n' "[$(date '+%Y-%m-%d %H:%M:%S')] Anniversary replay completed. Next frame: ${CURRENT_FRAME}" | tee -a "${FRMENV_LOG_FILE}"
exit 0
