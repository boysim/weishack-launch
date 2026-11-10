#!/usr/bin/env bash
# =====================================================================
#  Weishack - installatie in één stap op een verse Raspberry Pi
#  ------------------------------------------------------------------
#  Met een READ-ONLY token (fijnmazig, enkel Contents: read op de repo):
#
#    curl -fsSL https://boysim.github.io/weishack-launch/bootstrap.sh \
#      | sudo bash -s -- <GITHUB_READ_TOKEN>
#
#  of, als je het script al op de Pi hebt staan:
#    sudo bash weishack-bootstrap.sh <GITHUB_READ_TOKEN>
#
#  Optioneel: WEISHACK_BRANCH=stable vooraan om de productie-branch te nemen
#  (standaard 'main' = test).
# =====================================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Draai met sudo."; exit 1; }

TOKEN="${1:-${WEISHACK_TOKEN:-}}"
BRANCH="${WEISHACK_BRANCH:-main}"
OWNER_REPO="boysim/weishack"
[[ -n "$TOKEN" ]] || { echo "Gebruik: sudo bash bootstrap.sh <GITHUB_READ_TOKEN>"; exit 1; }

REPO_URL="https://x-access-token:${TOKEN}@github.com/${OWNER_REPO}.git"
export DEBIAN_FRONTEND=noninteractive

echo "== 1/5 Pakketten =="
apt-get update -y
apt-get install -y git python3-flask python3-requests curl network-manager
systemctl enable --now NetworkManager 2>/dev/null || true

echo "== 2/5 Tailscale =="
command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh

echo "== 3/5 Repo ophalen ($BRANCH) =="
mkdir -p /opt/weishack
if [[ -d /opt/weishack/repo/.git ]]; then
  git -C /opt/weishack/repo remote set-url origin "$REPO_URL"
  git -C /opt/weishack/repo fetch --quiet origin "$BRANCH"
  git -C /opt/weishack/repo checkout -q "$BRANCH"
  git -C /opt/weishack/repo reset --hard "origin/$BRANCH"
else
  git clone --quiet --branch "$BRANCH" "$REPO_URL" /opt/weishack/repo
fi

echo "== 4/5 Weishack installeren =="
WEISHACK_BRANCH="$BRANCH" bash /opt/weishack/repo/install.sh "$REPO_URL"

echo "== 5/5 BLE + wifi-provisioning =="
bash /opt/weishack/repo/ble/install-weishack-ble.sh   || echo "  (BLE mislukt/overgeslagen - check Bluetooth)"
bash /opt/weishack/repo/wifi/install-weishack-wifi.sh || echo "  (wifi-provisioning mislukt/overgeslagen)"

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "================================================================"
echo " KLAAR. Weishack draait op  http://${IP:-<pi-ip>}:8090"
echo " OTA staat aan (branch '$BRANCH', check elk uur)."
echo " Nog koppelen aan je tailnet:   sudo tailscale up"
echo "================================================================"
