#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="/home/fang/dorminet_workspace"
archive_path="${WORKSPACE_DIR}/dorminet-flex-source.tar.gz"
timestamp="$(date +%Y%m%d-%H%M%S)"
build_dir="${WORKSPACE_DIR}/dorminet-flex-build-${timestamp}"
backup_dir="${WORKSPACE_DIR}/backups/${timestamp}-pre-flex-ui"
live_binary="/opt/dormitory/server_debian"
master_database="/opt/dormitory/dormitory.db"
tenant_database_dir="/opt/dormitory/dorm_data"
ocr_directory="/opt/dormitory/ocr-bot"
ocr_unit="/etc/systemd/system/dormitory-ocr.service"
deploy_lock="${WORKSPACE_DIR}/.dorminet-flex-deploy.lock"

# Agents share this deployment path. Serialize deploys so a second agent
# cannot replace the source archive or service binary while one deploy is in
# progress.
exec 9>"$deploy_lock"
if ! flock -n 9; then
  echo "Another DormiNetX deploy is already running" >&2
  exit 1
fi

mkdir -p "$build_dir" "$backup_dir"
tar -xzf "$archive_path" -C "$build_dir"
cd "$build_dir/backend-dorm"
CGO_ENABLED=1 /usr/local/go/bin/go build -trimpath -o server_debian .
new_sha="$(sha256sum server_debian | awk '{print $1}')"

sudo cp -p "$live_binary" "$backup_dir/server_debian"
if command -v sqlite3 >/dev/null 2>&1; then
  sudo sqlite3 "$master_database" ".backup '$backup_dir/dormitory.db'"
  if sudo test -d "$tenant_database_dir"; then
    sudo mkdir -p "$backup_dir/dorm_data"
    while IFS= read -r tenant_database; do
      tenant_name="$(basename "$tenant_database")"
      sudo sqlite3 "$tenant_database" ".backup '$backup_dir/dorm_data/$tenant_name'"
    done < <(sudo find "$tenant_database_dir" -maxdepth 1 -type f -name 'tenant_*.db' -print)
  fi
else
  sudo cp -p "$master_database" "$backup_dir/dormitory.db"
  if sudo test -d "$tenant_database_dir"; then
    sudo cp -a "$tenant_database_dir" "$backup_dir/dorm_data"
  fi
fi

# OCR is updated later in this deploy, so keep its runtime files and unit next
# to the binary/database backup. This gives operators a concrete rollback
# source even though OCR restoration is still a manual operation.
if sudo test -d "$ocr_directory"; then
  sudo cp -a "$ocr_directory" "$backup_dir/ocr-bot"
fi
if sudo test -f "$ocr_unit"; then
  sudo cp -p "$ocr_unit" "$backup_dir/dormitory-ocr.service"
fi

rollback() {
  echo "Health check failed; restoring the previous binary" >&2
  sudo install -m 0755 "$backup_dir/server_debian" "$live_binary"
  sudo systemctl restart dormitory.service
}

sudo systemctl stop dormitory.service
if ! sudo install -m 0755 server_debian "$live_binary"; then
  rollback
  exit 1
fi
if ! sudo systemctl start dormitory.service; then
  rollback
  exit 1
fi

healthy=false
for _ in $(seq 1 15); do
  if sudo systemctl is-active --quiet dormitory.service && \
    curl --fail --silent --show-error http://127.0.0.1:4283/api/system/ping >/dev/null; then
    healthy=true
    break
  fi
  sleep 1
done

if [[ "$healthy" != "true" ]]; then
  rollback
  exit 1
fi

echo "Setting up OCR Bot..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y tesseract-ocr tesseract-ocr-tha python3-pip python3-venv >/dev/null || true
sudo mkdir -p /opt/dormitory/ocr-bot
sudo cp -r "$build_dir/backend-dorm/ocr-bot/"* /opt/dormitory/ocr-bot/
if sudo test ! -d "/opt/dormitory/ocr-bot/venv"; then
  sudo python3 -m venv /opt/dormitory/ocr-bot/venv
fi
sudo /opt/dormitory/ocr-bot/venv/bin/pip install -r /opt/dormitory/ocr-bot/requirements.txt >/dev/null || echo "Failed to install Python dependencies, OCR might not work"

sudo bash -c 'cat <<EOF > /etc/systemd/system/dormitory-ocr.service
[Unit]
Description=Dormitory OCR Bot
After=network.target

[Service]
User=root
WorkingDirectory=/opt/dormitory/ocr-bot
Environment="BACKEND_DIR=/opt/dormitory"
ExecStart=/opt/dormitory/ocr-bot/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable dormitory-ocr.service
sudo systemctl restart dormitory-ocr.service

echo "DEPLOY_SUCCESS"
echo "NEW_SHA=${new_sha}"
echo "BACKUP_DIR=${backup_dir}"
echo "OCR_BACKUP_DIR=${backup_dir}/ocr-bot"
sudo systemctl is-active dormitory.service
curl --fail --silent --show-error http://127.0.0.1:4283/api/system/ping
echo
sudo sqlite3 "$master_database" \
  "SELECT name FROM pragma_table_info('line_notification_outbox') WHERE name IN ('cost','reported_at','resolved_at','payment_method','maintenance_updated_at','maintenance_record_id') ORDER BY name;"
if sudo test -f "$tenant_database_dir/tenant_1.db"; then
  sudo sqlite3 "$tenant_database_dir/tenant_1.db" \
    "SELECT name FROM pragma_table_info('maintenances') WHERE name = 'quote_approved_at';"
fi

# Keep storage bounded after a fully successful deploy. A `.retain` marker
# exempts milestone directories from rotation. Named/manual backups outside
# the timestamped pre-flex-ui pattern are never touched.
cleanup_deploy_artifacts() {
  local build_keep_count=2
  local backup_keep_count=10
  local delete_count index candidate resolved
  local removed_builds=0
  local removed_backups=0
  local -a builds automated_backups

  mapfile -d '' -t builds < <(
    find "${WORKSPACE_DIR}" -maxdepth 1 -type d -name 'dorminet-flex-build-*' \
      -printf '%p\0' | sort -z
  )
  delete_count=$((${#builds[@]} - build_keep_count))
  if (( delete_count < 0 )); then delete_count=0; fi
  for ((index=0; index<delete_count; index++)); do
    candidate="${builds[$index]}"
    [[ "$candidate" == "$build_dir" || -e "$candidate/.retain" ]] && continue
    [[ ! -L "$candidate" && -d "$candidate/backend-dorm" ]] || continue
    [[ "$(basename "$candidate")" =~ ^dorminet-flex-build-[0-9]{8}-[0-9]{6}$ ]] || continue
    resolved="$(realpath "$candidate")"
    [[ "$(dirname "$resolved")" == "${WORKSPACE_DIR}" ]] || continue
    sudo rm -rf --one-file-system -- "$candidate"
    removed_builds=$((removed_builds + 1))
  done

  mapfile -d '' -t automated_backups < <(
    find "${WORKSPACE_DIR}/backups" -mindepth 1 -maxdepth 1 -type d \
      -regextype posix-extended \
      -regex '.*/[0-9]{8}-[0-9]{6}-pre-flex-ui' \
      -printf '%p\0' | sort -z
  )
  delete_count=$((${#automated_backups[@]} - backup_keep_count))
  if (( delete_count < 0 )); then delete_count=0; fi
  for ((index=0; index<delete_count; index++)); do
    candidate="${automated_backups[$index]}"
    [[ "$candidate" == "$backup_dir" || -e "$candidate/.retain" ]] && continue
    [[ ! -L "$candidate" && -f "$candidate/server_debian" && -f "$candidate/dormitory.db" ]] || continue
    [[ "$(basename "$candidate")" =~ ^[0-9]{8}-[0-9]{6}-pre-flex-ui$ ]] || continue
    resolved="$(realpath "$candidate")"
    [[ "$(dirname "$resolved")" == "${WORKSPACE_DIR}/backups" ]] || continue
    sudo rm -rf --one-file-system -- "$candidate"
    removed_backups=$((removed_backups + 1))
  done

  echo "RETENTION_REMOVED_BUILDS=${removed_builds}"
  echo "RETENTION_REMOVED_BACKUPS=${removed_backups}"
}

if ! cleanup_deploy_artifacts; then
  echo "Warning: deploy succeeded but artifact retention cleanup failed" >&2
fi
