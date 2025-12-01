# Comandos Exactos para Ejecutar en Ubuntu

Tu IP ZeroTier en Ubuntu es: **192.168.196.245**

## Paso 1: Descarga los archivos (si no los tienes ya)

```bash
# Opción A: Si tienes acceso Git
cd ~
git clone <tu-repo> mysql-cluster

# Opción B: Si tienes los archivos en comprimido
unzip mysql-cluster.zip -d ~
cd ~/mysql-cluster
```

## Paso 2: Permisos de ejecución

```bash
chmod +x scripts/init-cluster.sh
chmod +x scripts/auto-sync-cluster.sh
```

## Paso 3: Verifica que existe `conf/mysqld.node1.cnf`

```bash
ls -la conf/mysqld.node*.cnf
# Deberías ver:
# -rw-r--r-- ... conf/mysqld.node1.cnf
# -rw-r--r-- ... conf/mysqld.node2.cnf
# -rw-r--r-- ... conf/mysqld.node3.cnf
```

**Si NO existen**, créalos con este contenido:

### conf/mysqld.node1.cnf (macOS - 192.168.196.151)
```
[mysqld]
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
bind-address    = 0.0.0.0
port            = 3306
default_authentication_plugin = mysql_native_password

gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
log_bin = binlog
binlog_format = ROW
binlog_checksum = NONE
master_info_repository = TABLE
relay_log_info_repository = TABLE
transaction_write_set_extraction = XXHASH64

plugin_load_add = 'group_replication.so'
group_replication_group_name = "aaaaaaaa-bbbb-cccc-dddd-eeeeffff0000"
group_replication_start_on_boot = OFF
group_replication_bootstrap_group = OFF
group_replication_exit_state_action = READ_ONLY
group_replication_flow_control_mode = "QUOTA"
group_replication_transaction_size_limit = 150000000
group_replication_ip_whitelist = "192.168.196.0/24,127.0.0.1/8,172.16.0.0/12"
group_replication_group_seeds = "192.168.196.151:33061,192.168.196.115:33061,192.168.196.245:33061"

server_id = 1
auto_increment_increment = 3
auto_increment_offset = 1
report_host = 192.168.196.151
group_replication_local_address = "192.168.196.151:33061"
```

### conf/mysqld.node2.cnf (Windows - 192.168.196.115)
```
[mysqld]
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
bind-address    = 0.0.0.0
port            = 3306
default_authentication_plugin = mysql_native_password

gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
log_bin = binlog
binlog_format = ROW
binlog_checksum = NONE
master_info_repository = TABLE
relay_log_info_repository = TABLE
transaction_write_set_extraction = XXHASH64

plugin_load_add = 'group_replication.so'
group_replication_group_name = "aaaaaaaa-bbbb-cccc-dddd-eeeeffff0000"
group_replication_start_on_boot = OFF
group_replication_bootstrap_group = OFF
group_replication_exit_state_action = READ_ONLY
group_replication_flow_control_mode = "QUOTA"
group_replication_transaction_size_limit = 150000000
group_replication_ip_whitelist = "192.168.196.0/24,127.0.0.1/8,172.16.0.0/12"
group_replication_group_seeds = "192.168.196.151:33061,192.168.196.115:33061,192.168.196.245:33061"

server_id = 2
auto_increment_increment = 3
auto_increment_offset = 2
report_host = 192.168.196.115
group_replication_local_address = "192.168.196.115:33061"
```

### conf/mysqld.node3.cnf (Ubuntu - 192.168.196.245)
```
[mysqld]
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
bind-address    = 0.0.0.0
port            = 3306
default_authentication_plugin = mysql_native_password

gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
log_bin = binlog
binlog_format = ROW
binlog_checksum = NONE
master_info_repository = TABLE
relay_log_info_repository = TABLE
transaction_write_set_extraction = XXHASH64

plugin_load_add = 'group_replication.so'
group_replication_group_name = "aaaaaaaa-bbbb-cccc-dddd-eeeeffff0000"
group_replication_start_on_boot = OFF
group_replication_bootstrap_group = OFF
group_replication_exit_state_action = READ_ONLY
group_replication_flow_control_mode = "QUOTA"
group_replication_transaction_size_limit = 150000000
group_replication_ip_whitelist = "192.168.196.0/24,127.0.0.1/8,172.16.0.0/12"
group_replication_group_seeds = "192.168.196.151:33061,192.168.196.115:33061,192.168.196.245:33061"

server_id = 3
auto_increment_increment = 3
auto_increment_offset = 3
report_host = 192.168.196.245
group_replication_local_address = "192.168.196.245:33061"
```

## Paso 4: Levantar los 3 contenedores

```bash
cd ~/mysql-cluster
docker-compose -f docker-compose-cluster.yml up -d
```

Espera 30 segundos y verifica:

```bash
docker ps | grep importaciones
```

Deberías ver 3 contenedores:
- importaciones_db_node1 (puerto 3307)
- importaciones_db_node2 (puerto 3308)  
- importaciones_db_node3 (puerto 3309)

## Paso 5: Inicializar el cluster

```bash
./scripts/init-cluster.sh
```

Este script:
✅ Espera a que los 3 nodos estén saludables
✅ Crea usuario repl_admin en todos
✅ Configura Group Replication
✅ Arranca Node1 como BOOTSTRAP
✅ Arranca Node2 y Node3 como JOINS
✅ Verifica que los 3 estén ONLINE

## Paso 6: Verificar que funciona

```bash
mysql -h192.168.196.151 -P3306 -uadmin -pPasswordSeguro123 -e "
  SELECT MEMBER_STATE, COUNT(*) 
  FROM performance_schema.replication_group_members 
  GROUP BY MEMBER_STATE;
"
```

Deberías ver:
```
MEMBER_STATE | COUNT(*)
ONLINE       | 3
```

## Paso 7: Configurar auto-sincronización (Opcional)

### Opción A: Una sola verificación
```bash
./scripts/auto-sync-cluster.sh
```

### Opción B: Como daemon (corre cada 5 min en background)
```bash
./scripts/auto-sync-cluster.sh daemon &
# Ver logs
tail -f /var/log/mysql-cluster-sync.log
```

### Opción C: Cron (automático cada 5 minutos)
```bash
crontab -e
# Agregar esta línea:
*/5 * * * * /home/ubuntu/mysql-cluster/scripts/auto-sync-cluster.sh >> /var/log/mysql-cluster-sync.log 2>&1
```

---

## Próximos pasos en macOS y Windows

Una vez que Ubuntu esté funcionando:

### En macOS (Node1):
1. Descarga los mismos archivos
2. Cambia IP en las configuraciones si es diferente (ahora asume 192.168.196.151)
3. Levantar: `docker-compose -f docker-compose-cluster.yml up -d`
4. **NO ejecutes init-cluster.sh en macOS** (ya se ejecutó en Ubuntu)

### En Windows (Node2):
1. Descarga los mismos archivos
2. Instala Docker Desktop
3. Levantar: `docker-compose -f docker-compose-cluster.yml up -d`
4. **NO ejecutes init-cluster.sh en Windows**

Una vez que los 3 nodos estén UP, deberían conectarse automáticamente vía ZeroTier.

---

¿Necesitas ayuda con alguno de estos pasos?
