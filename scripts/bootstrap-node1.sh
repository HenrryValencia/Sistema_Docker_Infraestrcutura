#!/usr/bin/env bash
set -euo pipefail
# Run on node1 (macOS) after docker compose up and ZeroTier ready
CONTAINER=importaciones_db
ROOT_PASS=${ROOT_PASS:-PasswordSeguro123}
REPL_USER=${REPL_USER:-repl_admin}
REPL_PASS=${REPL_PASS:-ReplPass123!}

echo "Setting root password (if needed) and creating replication user..."
docker exec -i $CONTAINER sh -c "mysql -uroot <<'SQL'
ALTER USER IF EXISTS 'root'@'localhost' IDENTIFIED BY '$ROOT_PASS';
CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASS';
GRANT REPLICATION SLAVE, REPLICATION_CLIENT, GROUP_REPLICATION_ADMIN ON *.* TO '$REPL_USER'@'%';
FLUSH PRIVILEGES;
SQL"

echo "Bootstrapping group replication (run ONCE on node1)..."
docker exec -i $CONTAINER sh -c "mysql -uroot -p$ROOT_PASS -e \"SET GLOBAL group_replication_bootstrap_group=ON; START GROUP_REPLICATION; SET GLOBAL group_replication_bootstrap_group=OFF;\" || true"

echo "Check group members:"
docker exec -i $CONTAINER mysql -uroot -p$ROOT_PASS -e "SELECT member_id, member_host, member_port, member_state FROM performance_schema.replication_group_members;"

echo "Done"
