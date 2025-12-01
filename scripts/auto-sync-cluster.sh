#!/bin/bash

# Script: auto-sync-cluster.sh
# Propósito: Sincronizar y verificar estado del cluster Master-Master-Master cada 5 minutos
# Uso: ./scripts/auto-sync-cluster.sh &
# O con cron: */5 * * * * /home/ubuntu/importaciones/scripts/auto-sync-cluster.sh >> /var/log/mysql-cluster-sync.log 2>&1

set -e

LOG_FILE="${LOG_FILE:-/var/log/mysql-cluster-sync.log}"
DB_USER="${DB_USER:-admin}"
DB_PASSWORD="${DB_PASSWORD:-PasswordSeguro123}"
DB_NAME="${DB_NAME:-Importaciones_Animales_Valencia}"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}" # 5 minutos en segundos

# Asegurar que el directorio de logs existe
mkdir -p "$(dirname "$LOG_FILE")"

# Función: registrar con timestamp
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función: verificar estado de un nodo MySQL
check_node_health() {
  local node_host=$1
  local node_port=$2
  local node_name=$3
  
  if mysql -h"$node_host" -P"$node_port" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" &>/dev/null; then
    log_message "✓ Nodo $node_name ($node_host:$node_port) está HEALTHY"
    return 0
  else
    log_message "✗ Nodo $node_name ($node_host:$node_port) NO responde"
    return 1
  fi
}

# Función: obtener estado del grupo de replicación
check_replication_group() {
  log_message "--- Verificando estado del Grupo de Replicación ---"
  
  mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" -e "
    SELECT 
      MEMBER_ID, 
      MEMBER_HOST, 
      MEMBER_PORT, 
      MEMBER_STATE,
      MEMBER_ROLE,
      MEMBER_VERSION
    FROM performance_schema.replication_group_members;
  " 2>/dev/null || log_message "Error: No se pudo consultar replication_group_members"
}

# Función: verificar que todas las tablas están sincronizadas
check_data_consistency() {
  log_message "--- Verificando consistencia de datos ---"
  
  # Contar filas en tabla clientes
  CLIENTES_NODE1=$(mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) FROM clientes;" 2>/dev/null | tail -1)
  CLIENTES_NODE2=$(mysql -h192.168.196.115 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) FROM clientes;" 2>/dev/null | tail -1)
  CLIENTES_NODE3=$(mysql -h192.168.196.245 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) FROM clientes;" 2>/dev/null | tail -1)
  
  log_message "Clientes - Node1: $CLIENTES_NODE1, Node2: $CLIENTES_NODE2, Node3: $CLIENTES_NODE3"
  
  # Contar filas en tabla ventas
  VENTAS_NODE1=$(mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) FROM ventas;" 2>/dev/null | tail -1)
  VENTAS_NODE2=$(mysql -h192.168.196.115 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) FROM ventas;" 2>/dev/null | tail -1)
  VENTAS_NODE3=$(mysql -h192.168.196.245 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) FROM ventas;" 2>/dev/null | tail -1)
  
  log_message "Ventas - Node1: $VENTAS_NODE1, Node2: $VENTAS_NODE2, Node3: $VENTAS_NODE3"
  
  # Verificar consistencia
  if [ "$CLIENTES_NODE1" -eq "$CLIENTES_NODE2" ] && [ "$CLIENTES_NODE2" -eq "$CLIENTES_NODE3" ]; then
    log_message "✓ Tabla clientes SINCRONIZADA en todos los nodos"
  else
    log_message "⚠ Inconsistencia en tabla clientes detectada"
  fi
  
  if [ "$VENTAS_NODE1" -eq "$VENTAS_NODE2" ] && [ "$VENTAS_NODE2" -eq "$VENTAS_NODE3" ]; then
    log_message "✓ Tabla ventas SINCRONIZADA en todos los nodos"
  else
    log_message "⚠ Inconsistencia en tabla ventas detectada"
  fi
}

# Función: obtener estadísticas de replicación
get_replication_stats() {
  log_message "--- Estadísticas de Replicación ---"
  
  mysql -h192.168.196.151 -P3306 -u"$DB_USER" -p"$DB_PASSWORD" -e "
    SELECT 
      COUNT(*) as TRANSACTIONS_RECEIVED
    FROM performance_schema.replication_group_member_stats;
  " 2>/dev/null || log_message "Error: No se pudo obtener estadísticas"
}

# Función principal: ejecutar todas las verificaciones
main() {
  log_message "=========================================="
  log_message "Iniciando sincronización del cluster..."
  log_message "=========================================="
  
  # Verificar salud de cada nodo
  check_node_health "192.168.196.151" "3306" "Node1 (macOS/Master)"
  check_node_health "192.168.196.115" "3306" "Node2 (Windows/Master)"
  check_node_health "192.168.196.245" "3306" "Node3 (Ubuntu/Master)"
  
  log_message ""
  
  # Verificar estado del grupo
  check_replication_group
  
  log_message ""
  
  # Verificar consistencia
  check_data_consistency
  
  log_message ""
  
  # Estadísticas
  get_replication_stats
  
  log_message "=========================================="
  log_message "Sincronización completada"
  log_message "=========================================="
  log_message ""
}

# Ejecutar una vez o en bucle según argumento
if [ "$1" = "daemon" ]; then
  # Modo daemon: ejecutar cada SYNC_INTERVAL segundos
  while true; do
    main
    sleep "$SYNC_INTERVAL"
  done
else
  # Modo una sola vez
  main
fi
