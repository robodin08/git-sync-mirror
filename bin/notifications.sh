#!/usr/bin/env bash

INCIDENT_ACTIVE="${INCIDENT_ACTIVE:-false}"

notify() {
  local title="$1"
  local message="$2"

  if [[ -z "${SHOUTRRR_URL:-}" ]]; then
    echo "SHOUTRRR_URL is not configured; skipping notification."
    return 0
  fi

  shoutrrr send \
    --url "${SHOUTRRR_URL}" \
    --title "${title}" \
    --message "${message}" ||
    echo "WARNING: Shoutrrr notification failed." >&2

  return 0
}

report_failure() {
    local message="$1"

    if [[ "${INCIDENT_ACTIVE}" != "true" ]]; then
        INCIDENT_ACTIVE=true

        if [[ "${NOTIFY_ON_FAILURE:-true}" == "true" ]]; then
            notify \
                "Git mirror failure: ${SRC_REPO}" \
                "${message}"
        fi
    fi
}

report_recovery() {
  if [[ "${INCIDENT_ACTIVE}" == "true" ]]; then
    INCIDENT_ACTIVE=false
    if [[ "${NOTIFY_ON_RECOVERY:-true}" == "true" ]]; then
      notify \
        "Git mirror recovered: ${SRC_REPO}" \
        "Repository synchronization is working again."
    fi
  fi
}
