#!/usr/bin/env bash
# =====================================================================
#  Weishack - installatie in één stap op een verse Raspberry Pi
#  ------------------------------------------------------------------
#    curl -fsSL https://boysim.github.io/weishack-launch/bootstrap.sh \
#      | sudo bash -s -- <GITHUB_READ_TOKEN> [GRAFANA_LOGS_TOKEN]
#
#    $1  GitHub read-only token   (verplicht) -> privé-repo lezen + OTA
#    $2  Grafana Cloud logs-token (optioneel) -> logverzending meteen aan
#
#  Standaard 'stable' (productie). Voor een testtoestel: WEISHACK_BRANCH=main
#  vooraan (of main-only via de channels/<id>-override achteraf).
# =====================================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Draai met sudo."; exit 1; }

TOKEN="${1:-${WEISHACK_TOKEN:-}}"
GLOKI="${2:-${GCLOUD_LOGS_TOKEN:-}}"
BRANCH="${WEISHACK_BRANCH:-stable}"
OWNER_REPO="boysim/weishack"
[[ -n "$TOKEN" ]] || { echo "Gebruik: sudo bash bootstrap.sh <GITHUB_READ_TOKEN> [GRAFANA_LOGS_TOKEN]"; exit 1; }

REPO_URL="https://x-access-token:${TOKEN}@github.com/${OWNER_REPO}.git"
export DEBIAN_FRONTEND=noninteractive

echo "== 1/6 Pakketten =="
apt-get update -y
apt-get install -y git python3-flask python3-requests curl network-manager
systemctl enable --now NetworkManager 2>/dev/null || true

echo "== 2/6 Tailscale =="
command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh

echo "== 3/6 Repo ophalen ($BRANCH) =="
mkdir -p /opt/weishack
if [[ -d /opt/weishack/repo/.git ]]; then
  git -C /opt/weishack/repo remote set-url origin "$REPO_URL"
  git -C /opt/weishack/repo fetch --quiet origin "$BRANCH"
  git -C /opt/weishack/repo checkout -q "$BRANCH"
  git -C /opt/weishack/repo reset --hard "origin/$BRANCH"
else
  git clone --quiet --branch "$BRANCH" "$REPO_URL" /opt/weishack/repo
fi

echo "== 4/6 Weishack installeren =="
WEISHACK_BRANCH="$BRANCH" bash /opt/weishack/repo/install.sh "$REPO_URL"

echo "== 5/6 BLE + wifi-provisioning =="
bash /opt/weishack/repo/ble/install-weishack-ble.sh   || echo "  (BLE mislukt/overgeslagen - check Bluetooth)"
bash /opt/weishack/repo/wifi/install-weishack-wifi.sh || echo "  (wifi-provisioning mislukt/overgeslagen)"

echo "== 6/6 Logverzending naar Grafana Cloud =="
if [[ -n "$GLOKI" ]]; then
  mkdir -p /opt/weishack/run
  echo "GCLOUD_LOGS_TOKEN=$GLOKI" > /opt/weishack/run/grafana.env
  chmod 600 /opt/weishack/run/grafana.env
  bash /opt/weishack/repo/monitoring/install-alloy.sh || echo "  (Alloy mislukt - later opnieuw proberen)"
else
  echo "  (geen Grafana-token meegegeven -> overgeslagen; later: install-alloy.sh)"
fi

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "================================================================"
echo " KLAAR. Weishack draait op  http://${IP:-<pi-ip>}:8090"
echo " OTA staat aan (branch '$BRANCH', check elk uur)."
echo " Tailscale koppelen:  via de webinterface, of  sudo tailscale up"
[[ -n "$GLOKI" ]] && echo " Logs gaan naar Grafana Cloud."
echo "================================================================"
