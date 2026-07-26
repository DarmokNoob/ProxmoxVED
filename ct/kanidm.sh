#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../misc/build.func" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main}/misc/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: DarmokNoob (DarmokNoob)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://kanidm.com/

APP="Kanidm"
var_tags="${var_tags:-identity-provider}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if ! dpkg -s kanidmd >/dev/null 2>&1; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP}"
  $STD apt update
  $STD apt --only-upgrade install -y kanidmd
  msg_ok "Updated Packages"

  msg_info "Restarting Service"
  systemctl restart kanidmd
  msg_ok "Restarted Service"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

ADMIN_CRED_LINE=$(pct exec "$CTID" -- grep '^admin:' /root/kanidmd.creds 2>/dev/null)
IDM_ADMIN_CRED_LINE=$(pct exec "$CTID" -- grep '^idm_admin:' /root/kanidmd.creds 2>/dev/null)
KANIDM_DOMAIN=$(pct exec "$CTID" -- grep '^domain = ' /etc/kanidmd/server.toml 2>/dev/null | sed -E 's/^domain = "(.*)"/\1/')

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}API/LDAP/CLI reachable at:${CL}"
echo -e "${GATEWAY}${BGN}https://${IP}:8443${CL}"
echo -e "${INFO}${YW} Web UI login needs the hostname, not the IP:${CL}"
echo -e "${TAB}${BGN}https://${KANIDM_DOMAIN}:8443${CL}"
echo -e "${TAB}Kanidm's session cookie is scoped to Domain=${KANIDM_DOMAIN}, so browsers${CL}"
echo -e "${TAB}silently refuse it over the raw IP -- login will fail with an${CL}"
echo -e "${TAB}\"InvalidAuthState\" error unless DNS (or a hosts-file entry) points${CL}"
echo -e "${TAB}${KANIDM_DOMAIN} at ${IP}. Everything else (API, LDAP, CLI) works fine by IP.${CL}"
echo -e "${INFO}${YW} Break-glass credentials:${CL}"
echo -e "${TAB}${BGN}${ADMIN_CRED_LINE}${CL}"
echo -e "${TAB}${BGN}${IDM_ADMIN_CRED_LINE}${CL}"
echo -e "${TAB}(full detail saved in /root/kanidmd.creds)${CL}"
echo -e "${INFO}${YW} Lost them? Regenerate anytime with:${CL}"
echo -e "${TAB}pct exec ${CTID} -- kanidmd recover-account admin -c /etc/kanidmd/server.toml${CL}"
echo -e "${INFO}${YW} domain/origin default to this container's hostname with a self-signed cert. If you point real DNS at it, edit${CL}"
echo -e "${TAB}/etc/kanidmd/server.toml${CL}${YW}, re-run${CL} ${TAB}kanidmd cert-generate -c /etc/kanidmd/server.toml${CL}${YW}, then${CL} ${TAB}kanidmd domain rename${CL}"
