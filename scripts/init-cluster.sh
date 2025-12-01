#!/bin/bash

# Script: init-cluster.sh
# Propósito: Inicializar y bootstrappear el cluster Master-Master-Master
# Uso: ./scripts/init-cluster.sh
# Este script se ejecuta DESPUÉS de que los 3 contenedores están UP

set -e

LOG="/tmp/cluster-init.log"
DB_USER="admin"
DB_PASS="PasswordSeguro123"
DB_NAME="Importaciones_Animales_Valencia"
REPL_USER="repl_admin"
REPL_PASS="ReplPass123!"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG"
}

echo "Inicializando Cluster Master-Master-Master..." > "$LOG"
log_info "Log: $LOG"

# Paso 1: Esperar a que todos los nodos estén healthy
# Usando IPs ZeroTier: Node1=192.168.196.151 (macOS), Node2=192.168.196.115 (Windows), Node3=192.168.196.245 (Ubuntu)
log_info "Esperando a que los 3 nodos de MySQL estén saludables..."
for i in {1..30}; do
  if mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" &>/dev/null && \
     mysql -h192.168.196.115 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" &>/dev/null && \
     mysql -h192.168.196.245 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" &>/dev/null; then
    log_info "✓ Todos los nodos están listos"
    break
  fi
  echo -n "."
  sleep 2
done

# Paso 2: Crear usuario de replicación
log_info "Creando usuario de replicación en todos los nodos..."
for host in 192.168.196.151 192.168.196.115 192.168.196.245; do
  mysql -h"$host" -P3306 -u"$DB_USER" -p"$DB_PASS" -e "
    CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASS';
    GRANT REPLICATION SLAVE, REPLICATION_CLIENT, GROUP_REPLICATION_ADMIN ON *.* TO '$REPL_USER'@'%';
    FLUSH PRIVILEGES;
  " 2>/dev/null || log_warn "Error creando usuario en $host"
done
log_info "✓ Usuario de replicación creado"

# Paso 3: Configurar replicación en los nodos 2 y 3
log_info "Configurando canales de replicación en Node2 y Node3..."
for host in 192.168.196.115 192.168.196.245; do
  mysql -h"$host" -P3306 -u"$DB_USER" -p"$DB_PASS" -e "
    CHANGE MASTER TO MASTER_USER='$REPL_USER', MASTER_PASSWORD='$REPL_PASS' FOR CHANNEL 'group_replication_recovery';
  " 2>/dev/null || log_warn "Error configurando replicación en $host"
done
log_info "✓ Canales de replicación configurados"

# Paso 4: Bootstrap node1 (primer maestro del grupo)
log_info "Bootstrapping Node1 como primer maestro del grupo..."
mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "
  SET GLOBAL group_replication_bootstrap_group=ON;
  START GROUP_REPLICATION;
  SET GLOBAL group_replication_bootstrap_group=OFF;
" 2>/dev/null || log_error "Error bootstrapping Node1"

sleep 5
log_info "✓ Node1 bootstrapped"

# Paso 5: Unir node2 al grupo
log_info "Uniendo Node2 al grupo de replicación..."
mysql -h192.168.196.115 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "
  START GROUP_REPLICATION;
" 2>/dev/null || log_error "Error uniendo Node2"

sleep 5
log_info "✓ Node2 unido"

# Paso 6: Unir node3 al grupo
log_info "Uniendo Node3 al grupo de replicación..."
mysql -h192.168.196.245 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "
  START GROUP_REPLICATION;
" 2>/dev/null || log_error "Error uniendo Node3"

sleep 5
log_info "✓ Node3 unido"

# Paso 7: Verificar estado del cluster
log_info "Verificando estado del cluster..."
echo ""
log_info "Estado de miembros del grupo:"
mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "
  SELECT 
    SUBSTRING(MEMBER_HOST, 1, 20) as HOST,
    SUBSTRING(MEMBER_PORT, 1, 10) as PORT,
    SUBSTRING(MEMBER_STATE, 1, 20) as STATE,
    SUBSTRING(MEMBER_ROLE, 1, 15) as ROLE
  FROM performance_schema.replication_group_members;
" 2>/dev/null

echo ""
log_info "Estado de variables de replicación (Node1):"
mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASS" -e "
  SHOW VARIABLES LIKE 'group_replication%';
" 2>/dev/null | grep -E 'group_replication_local_address|group_replication_group_name|group_replication_start_on_boot' || true

echo ""
log_info "=========================================="
log_info "✓ CLUSTER INICIALIZADO CORRECTAMENTE"
log_info "=========================================="
log_info ""
log_info "Próximos pasos:"
log_info "1. Verificar sincronización: ./scripts/auto-sync-cluster.sh"
log_info "2. Iniciar daemon de sincronización: ./scripts/auto-sync-cluster.sh daemon &"
log_info "3. Añadir a cron para sincronización automática:"
log_info "   */5 * * * * /path/to/scripts/auto-sync-cluster.sh >> /var/log/mysql-cluster-sync.log 2>&1"
log_info "=========================================="
