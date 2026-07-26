#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: DarmokNoob (DarmokNoob)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://kanidm.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Adding Kanidm PPA (community-supported)"
curl -fsSL "https://kanidm.github.io/kanidm_ppa/kanidm_ppa.asc" \
  -o /etc/apt/trusted.gpg.d/kanidm_ppa.asc
CODENAME="$( . /etc/os-release && echo "$VERSION_CODENAME")"
curl -fsSL "https://kanidm.github.io/kanidm_ppa/kanidm_ppa.list" |
  grep "$CODENAME" | grep stable |
  tee /etc/apt/sources.list.d/kanidm_ppa.list >/dev/null
$STD apt update
msg_ok "Added Kanidm PPA"

msg_info "Installing Kanidm Server"
$STD apt install -y kanidmd
msg_ok "Installed Kanidm Server"

KANIDM_DOMAIN="$(hostname -f 2>/dev/null || hostname)"
KANIDM_DOMAIN="${KANIDM_DOMAIN,,}"

msg_info "Configuring Kanidm (${KANIDM_DOMAIN})"
sed -i \
  -e "s|^bindaddress = .*|bindaddress = \"0.0.0.0:8443\"|" \
  -e "s|^#domain = .*|domain = \"${KANIDM_DOMAIN}\"|" \
  -e "s|^#origin = .*|origin = \"https://${KANIDM_DOMAIN}:8443\"|" \
  -e '/^\[online_backup\]/i\
#   Read-only LDAP/LDAPS gateway - disabled by default.\
#   Uncomment to expose the directory over LDAP (e.g. for a NAS,\
#   UniFi, or anything that only speaks classic directory bind).\
# ldapbindaddress = "0.0.0.0:3636"\

' \
  /etc/kanidmd/server.toml
chown root:kanidmd /etc/kanidmd/server.toml
chmod 640 /etc/kanidmd/server.toml
msg_ok "Configured Kanidm"

msg_info "Generating Self-Signed TLS Certificate"
mkdir -p /var/lib/private/kanidmd
chown root:kanidmd /var/lib/private/kanidmd
chmod 750 /var/lib/private/kanidmd
ln -sfn private/kanidmd /var/lib/kanidmd
$STD kanidmd cert-generate -c /etc/kanidmd/server.toml
chown root:kanidmd /etc/kanidmd/chain.pem /etc/kanidmd/key.pem
chmod 640 /etc/kanidmd/chain.pem /etc/kanidmd/key.pem
msg_ok "Generated Self-Signed TLS Certificate"

msg_info "Validating Configuration"
$STD kanidmd configtest -c /etc/kanidmd/server.toml
msg_ok "Configuration Valid"

msg_info "Starting Kanidm"
systemctl enable -q --now kanidmd
msg_ok "Started Kanidm"

msg_info "Bootstrapping Break-Glass Admin Accounts"
ADMIN_OUTPUT=$(kanidmd recover-account admin -c /etc/kanidmd/server.toml 2>&1)
IDM_ADMIN_OUTPUT=$(kanidmd recover-account idm_admin -c /etc/kanidmd/server.toml 2>&1)
ADMIN_PASS=$(echo "$ADMIN_OUTPUT" | sed -n 's/.*new_password: "\(.*\)".*/\1/p')
IDM_ADMIN_PASS=$(echo "$IDM_ADMIN_OUTPUT" | sed -n 's/.*new_password: "\(.*\)".*/\1/p')
{
  echo "Kanidm break-glass credentials"
  echo "Bootstraps 'admin' (server config) and 'idm_admin' (people/groups)."
  echo "Re-run: kanidmd recover-account <name> -c /etc/kanidmd/server.toml  (anytime, regenerates)"
  echo
  echo "admin:     ${ADMIN_PASS:-see raw output below}"
  echo "idm_admin: ${IDM_ADMIN_PASS:-see raw output below}"
  echo
  echo "-- raw 'recover-account admin' output --"
  echo "$ADMIN_OUTPUT"
  echo
  echo "-- raw 'recover-account idm_admin' output --"
  echo "$IDM_ADMIN_OUTPUT"
} >~/kanidmd.creds
msg_ok "Bootstrapped Admin Accounts"

motd_ssh
customize
cleanup_lxc
