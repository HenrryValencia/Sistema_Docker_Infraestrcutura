#!/usr/bin/env bash
set -euo pipefail
# Usage: join-replica.sh <container_name> [root_pass]
CONTAINER=${1:-importaciones_db}
ROOT_PASS=${2:-PasswordSeguro123}
REPL_USER=${REPL_USER:-repl_admin}
REPL_PASS=${REPL_PASS:-ReplPass123!}

echo "Creating replication user (if not exists) and joining group..."
docker exec -i $CONTAINER sh -c "mysql -uroot -p$ROOT_PASS <<'SQL'
CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASS';
GRANT REPLICATION SLAVE, REPLICATION_CLIENT, GROUP_REPLICATION_ADMIN ON *.* TO '$REPL_USER'@'%';
FLUSH PRIVILEGES;
SQL"

echo "Configure recovery channel and start group replication"
docker exec -i $CONTAINER mysql -uroot -p$ROOT_PASS -e "CHANGE MASTER TO MASTER_USER='$REPL_USER', MASTER_PASSWORD='$REPL_PASS', MASTER_AUTO_POSITION=1 FOR CHANNEL 'group_replication_recovery'; START GROUP_REPLICATION;"

echo "Check group members:"
docker exec -i $CONTAINER mysql -uroot -p$ROOT_PASS -e "SELECT member_id, member_host, member_port, member_state FROM performance_schema.replication_group_members;"

echo "Done"
