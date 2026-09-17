#!/usr/bin/env bash
set -euo pipefail

archive_path="/home/fang/dorminet-flex-source.tar.gz"
timestamp="$(date +%Y%m%d-%H%M%S)"
build_dir="/home/fang/dorminet-flex-build-${timestamp}"
backup_dir="/home/fang/line_migration_backups/${timestamp}-pre-flex-ui"
live_binary="/opt/dormitory/server_debian"
master_database="/opt/dormitory/dormitory.db"
tenant_database_dir="/opt/dormitory/dorm_data"

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

echo "DEPLOY_SUCCESS"
echo "NEW_SHA=${new_sha}"
echo "BACKUP_DIR=${backup_dir}"
sudo systemctl is-active dormitory.service
curl --fail --silent --show-error http://127.0.0.1:4283/api/system/ping
echo
sudo sqlite3 "$master_database" \
  "SELECT name FROM pragma_table_info('line_notification_outbox') WHERE name IN ('cost','reported_at','resolved_at','payment_method','maintenance_updated_at','maintenance_record_id') ORDER BY name;"
if sudo test -f "$tenant_database_dir/tenant_1.db"; then
  sudo sqlite3 "$tenant_database_dir/tenant_1.db" \
    "SELECT name FROM pragma_table_info('maintenances') WHERE name = 'quote_approved_at';"
fi
