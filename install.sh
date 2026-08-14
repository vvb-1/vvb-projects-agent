#!/usr/bin/env bash
# install.sh — install vvb-projects-agent on a single Linux host.
# Run as the user that owns ~/Projects (typically krily).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/vvb-1/vvb-projects-agent/main/install.sh | bash
#   # or, locally:
#   ./install.sh
#
# Idempotent: re-runs replace the binary in place and refresh cron entries.
set -euo pipefail

REPO_URL="${VVB_PROJECTS_REPO:-https://github.com/vvb-1/vvb-projects-agent.git}"
REF="${VVB_PROJECTS_REF:-main}"
INSTALL_DIR="${HOME}/.local/share/vvb-projects"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/vvb-projects"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

say()  { printf '\033[1;34m[vvb-projects]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[vvb-projects]\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "${HOME}/Projects" ] || die "~/Projects missing — create it before installing."
command -v python3 >/dev/null || die "python3 required."
command -v git >/dev/null || die "git required."
command -v gh >/dev/null || say "gh CLI missing — auto-discovery will be skipped."

mkdir -p "${INSTALL_DIR}" "${BIN_DIR}" "${CONFIG_DIR}"

# Refresh the binary source.
if [ -d "${INSTALL_DIR}/.git" ]; then
  if [ -n "$(git -C "${INSTALL_DIR}" status --porcelain)" ]; then
    say "WARNING: ${INSTALL_DIR} has local modifications."
    say "Aborting auto-update to preserve local bugfixes."
    say "Commit/stash them upstream first, then re-run install.sh."
    if [ -t 0 ]; then
      read -rp "Continue anyway and discard local changes? [y/N] " ans
      case "${ans}" in
        y|Y|yes|YES) ;;
        *) die "aborted by user." ;;
      esac
    else
      die "non-interactive shell — refusing to discard local changes."
    fi
  fi
  git -C "${INSTALL_DIR}" fetch --depth=1 origin "${REF}" >/dev/null
  git -C "${INSTALL_DIR}" reset --hard "origin/${REF}" >/dev/null
else
  git clone --depth=1 --branch "${REF}" "${REPO_URL}" "${INSTALL_DIR}"
fi

# Install binary symlink.
ln -sf "${INSTALL_DIR}/vvb-projects" "${BIN_DIR}/vvb-projects"
say "installed ${BIN_DIR}/vvb-projects -> ${INSTALL_DIR}/vvb-projects"

# Seed config if missing.
if [ ! -f "${CONFIG_FILE}" ]; then
  sed -e "s|/home/krily/Projects|${HOME}/Projects|" \
      -e "s|/home/krily/.local/share|${HOME}/.local/share|" \
      "${INSTALL_DIR}/config.yaml" > "${CONFIG_FILE}"
  say "seeded ${CONFIG_FILE} (edit NTFY/telegram block to enable channels)"
else
  say "config exists at ${CONFIG_FILE} — leaving untouched"
fi

# PATH hint.
case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *) say "add to PATH: export PATH=\"${BIN_DIR}:\${PATH}\"" ;;
esac

# Wire a daily cron that emits a report.
CRON_LINE="15 9 * * * PATH=\"${PATH}:${BIN_DIR}\" vvb-projects report"
( crontab -l 2>/dev/null | grep -v 'vvb-projects report' ; echo "${CRON_LINE}" ) | crontab -
say "installed cron: ${CRON_LINE}"

vvb-projects --version
say "done."