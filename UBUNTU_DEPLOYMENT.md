# Guía: Despliegue en Ubuntu - MySQL Multi-Maestro (Master-Master-Master)

## Resumen
Esta guía describe cómo desplegar una **solución Multi-Maestro** con MySQL Group Replication donde todos los nodos (macOS, Windows, Ubuntu) pueden escribir, y los datos se sincronizan automáticamente cada 5 minutos a través de ZeroTier.

### Arquitectura
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  macOS      │  │  Windows    │  │  Ubuntu     │
│  (node1)    │  │  (node2)    │  │  (node3)    │
│   3307      │  │   3308      │  │   3309      │
│  MASTER     │◄─►│  MASTER     │◄─►│  MASTER     │
│             │  │             │  │             │
└─────────────┘  └─────────────┘  └─────────────┘
       ↑              ↑                   ↑
       └──────────────┴───────────────────┘
            ZeroTier Network 192.168.196.0/24
            Group Replication Sync (auto cada 5 min)
```

---

## 0. Requisitos previos en Ubuntu

```bash
# Actualizar paquetes
sudo apt-get update && sudo apt-get upgrade -y

# Instalar Node.js (v18+)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Instalar Docker y Docker Compose
sudo apt-get install -y docker.io docker-compose git

# Instalar ZeroTier (si no está instalado)
curl https://install.zerotier.com | sudo bash
sudo systemctl enable zerotier-one
sudo systemctl start zerotier-one

# Unirse a la red ZeroTier (sustituye con tu network ID)
sudo zerotier-cli join <NETWORK_ID>

# Verificar IP asignada (debería ser 192.168.196.x)
sudo zerotier-cli status
```

---

## 1. Clonar/descargar el repositorio

```bash
# Si tienes acceso SSH/git
git clone <repo_url> /home/ubuntu/importaciones
cd /home/ubuntu/importaciones

# O copiar archivos manualmente desde macOS (via scp o similar)
# scp -r <local_path> ubuntu@<ubuntu_ip>:/home/ubuntu/importaciones
```

---

## 2. Configurar variables de entorno

### 2.1 Crear archivo `.env` en la raíz (opcional, para compose)
```bash
cat > /home/ubuntu/importaciones/.env <<'ENV'
ZEROTIER_IP=192.168.196.245
MYSQL_ROOT_PASSWORD=PasswordSeguro123
MYSQL_ADMIN_USER=admin
MYSQL_ADMIN_PASSWORD=PasswordSeguro123
MYSQL_WEB_USER=web
MYSQL_WEB_PASSWORD=Importaciones@2025
HOST_SQL_PORT=3307
NODE_ENV=production
ENV
```

### 2.2 Actualizar backend/.env
```bash
cat > /home/ubuntu/importaciones/backend/.env <<'BACKEND_ENV'
DB_HOST=127.0.0.1
DB_PORT=3307
DB_USER=web
DB_PASSWORD=Importaciones@2025
DB_NAME=Importaciones_Animales_Valencia
PORT=4000
NODE_ENV=production
BACKEND_ENV
```

---

## 3. Levantar el Cluster Multi-Maestro en Docker

```bash
cd /home/ubuntu/importaciones

# Opción A: Usar docker-compose-cluster.yml (levanta 3 nodos locales, ideal para testing)
docker-compose -f docker-compose-cluster.yml up -d

# Verifica que los 3 contenedores están corriendo
docker ps | grep importaciones_db

# Esperar a que todos estén healthy (~30 segundos)
sleep 30

# Opción B: Si quieres ejecutar solo node3 en Ubuntu (y node1/node2 en otros hosts)
# docker-compose -f docker-compose.node3.yml up -d
```

### 3.1 Inicializar el Cluster (bootstrap y join)

Después de que los 3 contenedores estén UP, ejecuta el script de inicialización:

```bash
# Hacer script ejecutable
chmod +x /home/ubuntu/importaciones/scripts/init-cluster.sh

# Ejecutar inicialización (bootstrapea node1 y une node2/node3 al grupo)
/home/ubuntu/importaciones/scripts/init-cluster.sh
```

Este script automáticamente:
1. Crea usuario de replicación (`repl_admin`) en todos los nodos
2. Bootstrapea Node1 como primer maestro
3. Une Node2 y Node3 al grupo de replicación
4. Verifica que todos los nodos estén en estado ONLINE

**Esperado en output:**
```
✓ Node1 bootstrapped
✓ Node2 unido
✓ Node3 unido
✓ CLUSTER INICIALIZADO CORRECTAMENTE
```

---

## 4. Verificar conectividad a MySQL

```bash
# Instalar cliente MySQL (si no está)
sudo apt-get install -y mysql-client

# Conectarse como admin
mysql -h127.0.0.1 -P3307 -uadmin -pPasswordSeguro123 -e "SELECT VERSION();"

# Si funciona, verás algo como:
# +-----------+
# | VERSION() |
# +-----------+
# | 8.0.44    |
# +-----------+
```

---

## 5. Crear base de datos e inicializar

```bash
# Ejecutar script de inicialización (init/01-schema.sql)
mysql -h127.0.0.1 -P3307 -uadmin -pPasswordSeguro123 < /home/ubuntu/importaciones/init/01-schema.sql

# Verificar que la base fue creada
mysql -h127.0.0.1 -P3307 -uadmin -pPasswordSeguro123 -e "SHOW DATABASES;" | grep Importaciones
```

---

## 6. Crear usuario web (ya debería existir si usas el script init)

```bash
# Crear usuario si no existe (desde macOS ya se hizo, pero en nueva instancia:)
docker exec -i importaciones_db mysql -uadmin -pPasswordSeguro123 -e "
CREATE USER IF NOT EXISTS 'web'@'%' IDENTIFIED BY 'Importaciones@2025';
GRANT SELECT, INSERT, UPDATE, DELETE ON Importaciones_Animales_Valencia.* TO 'web'@'%';
FLUSH PRIVILEGES;
SELECT User, Host FROM mysql.user WHERE User='web';
"
```

---

## 7. Instalar dependencias del Backend

```bash
cd /home/ubuntu/importaciones/backend

npm install --no-audit --no-fund

# Verificar que se instalaron correctamente
npm list | head -20
```

---

## 8. Arrancar Backend

```bash
# Opción 1: en primer plano (para verificar logs en vivo)
npm run start

# Opción 2: en segundo plano (usando nohup o screen)
nohup npm run start > backend.log 2>&1 &

# Opción 3: usando PM2 para mayor robustez (recomendado para producción)
sudo npm install -g pm2
pm2 start npm --name "importaciones-backend" -- run start
pm2 startup
pm2 save
```

---

## 9. Verificar Backend

```bash
# Esperar unos segundos a que arranque
sleep 3

# Probar GET /clientes
curl -sS http://localhost:4000/clientes | jq '.'

# Debe devolver un JSON con la lista de clientes

# Probar GET /ventas
curl -sS http://localhost:4000/ventas | jq '.'

# Crear un cliente de prueba (POST)
curl -sS -X POST http://localhost:4000/clientes \
  -H 'Content-Type: application/json' \
  -d '{"nombre_completo":"Test Cliente Ubuntu","dni_cif":"12345678Z","email":"test@ubuntu.local","telefono":"+34111222333","sede_registro":"Linux"}' | jq '.'

# Debe devolver: {"cliente_id": <nuevo_id>}
```

---

## 10. Instalar dependencias del Frontend

```bash
cd /home/ubuntu/importaciones/frontend

npm install --no-audit --no-fund
```

---

## 11. Arrancar Frontend (Vite dev server)

```bash
# Opción 1: en primer plano
npm run start

# Debería mostrar: ➜ Local: http://localhost:5173/

# Opción 2: en segundo plano
nohup npm run start > frontend.log 2>&1 &

# Opción 3: con PM2
pm2 start npm --name "importaciones-frontend" -- run start
```

---

## 12. Verificar acceso al frontend

```bash
# Desde el mismo servidor
curl -sS http://localhost:5173/ | head -50

# O desde tu máquina (si tienes SSH a Ubuntu)
ssh ubuntu@<ubuntu_zerotier_ip> "curl -sS http://localhost:5173/" | head -20

# O abrir en navegador:
# http://<ubuntu_zerotier_ip>:5173/
# Ejemplo: http://192.168.196.245:5173/
```

---

## 13. Verificar Replicación (Group Replication - Multi-Maestro)

```bash
# Ver estado de miembros del grupo (ONLINE = OK)
docker exec -i importaciones_db_node1 mysql -uadmin -pPasswordSeguro123 -e "
  SELECT 
    MEMBER_ID, 
    SUBSTRING(MEMBER_HOST, 1, 15) as HOST,
    MEMBER_PORT, 
    MEMBER_STATE,
    MEMBER_ROLE
  FROM performance_schema.replication_group_members;
"

# Esperado: 3 filas, todas con MEMBER_STATE=ONLINE y MEMBER_ROLE=PRIMARY

# Escribir en node1, verificar que se replica en node2 y node3
docker exec -i importaciones_db_node1 mysql -uadmin -pPasswordSeguro123 -e "
  USE Importaciones_Animales_Valencia;
  INSERT INTO clientes (nombre_completo, dni_cif, email, telefono, sede_registro)
  VALUES ('Test Replicación Node1', '99999999X', 'test@node1.local', '+34666777888', 'macOS');
"

# Verificar que aparece en node2
docker exec -i importaciones_db_node2 mysql -uadmin -pPasswordSeguro123 -e "
  SELECT cliente_id, nombre_completo FROM Importaciones_Animales_Valencia.clientes 
  WHERE nombre_completo LIKE 'Test%' LIMIT 1;
"

# Verificar que aparece en node3
docker exec -i importaciones_db_node3 mysql -uadmin -pPasswordSeguro123 -e "
  SELECT cliente_id, nombre_completo FROM Importaciones_Animales_Valencia.clientes 
  WHERE nombre_completo LIKE 'Test%' LIMIT 1;
"

# Si el registro aparece en todos, ¡replicación funcionando! ✓
```

---

## 14. Pruebas funcionales completas

### 14.1 Test 1: Conectividad de bases de datos
```bash
# Verificar que podemos crear un cliente
mysql -h127.0.0.1 -P3307 -uweb -pImportaciones@2025 Importaciones_Animales_Valencia -e "
INSERT INTO clientes (nombre_completo, dni_cif, email, telefono, sede_registro)
VALUES ('Test Cliente 2', '87654321X', 'test2@example.com', '+34222333444', 'Linux');
SELECT * FROM clientes ORDER BY cliente_id DESC LIMIT 1;
"
```

### 14.2 Test 2: Backend API completa
```bash
# GET clientes
echo "=== GET /clientes ==="
curl -sS http://localhost:4000/clientes | jq '.[] | {cliente_id, nombre_completo}' | head -20

# POST cliente
echo -e "\n=== POST /clientes ==="
curl -sS -X POST http://localhost:4000/clientes \
  -H 'Content-Type: application/json' \
  -d '{
    "nombre_completo":"Cliente Ubuntu Prod",
    "dni_cif":"99999999A",
    "email":"prod@ubuntu.test",
    "telefono":"+34666777888",
    "sede_registro":"Linux"
  }' | jq '.'

# GET ventas
echo -e "\n=== GET /ventas ==="
curl -sS http://localhost:4000/ventas | jq '.[] | {venta_id, cliente_id, total}' | head -20

# POST venta
echo -e "\n=== POST /ventas ==="
curl -sS -X POST http://localhost:4000/ventas \
  -H 'Content-Type: application/json' \
  -d '{
    "cliente_id":1,
    "sede_origen":"Sede B (Linux)",
    "total":2999.99
  }' | jq '.'
```

### 14.3 Test 3: Frontend (via curl simulando navegador)
```bash
# Obtener el HTML del frontend
curl -sS http://localhost:5173/ | grep -i "importaciones\|clientes\|ventas" | head -5
```

---

## 15. Monitoreo y logs

### 15.1 Backend logs
```bash
# Si está corriendo con nohup
tail -f /home/ubuntu/importaciones/backend/backend.log

# Si está en PM2
pm2 logs importaciones-backend

# O dentro de Docker (MySQL)
docker logs -f importaciones_db
```

### 15.2 Verificar puertos abiertos
```bash
# Verificar que los puertos están escuchando
netstat -tulpn | grep -E '3307|4000|5173'

# O con ss (más moderno)
ss -tulpn | grep -E '3307|4000|5173'
```

---

## 16. Integración con ZeroTier (acceso remoto)

```bash
# Desde tu máquina macOS, suponiendo que tienes acceso a la red ZeroTier
# (y el servidor Ubuntu también está unido)

# IP del Ubuntu en ZeroTier (ejemplo: 192.168.196.245)
UBUNTU_IP=192.168.196.245

# Acceder al frontend desde macOS
open http://$UBUNTU_IP:5173

# O hacer curl desde macOS
curl -sS http://$UBUNTU_IP:4000/clientes | jq '.'
```

---

## 17. Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| `Connection refused` en puerto 3307 | MySQL no está corriendo | `docker ps` y `docker-compose up -d` |
| `Access denied for user 'web'` | Credenciales incorrectas | Verificar `.env` y contrasena en MySQL |
| Frontend no conecta a backend | Proxy no configurado o puertos bloqueados | Verificar `vite.config.js` y que backend esté en 4000 |
| ZeroTier IP no asignada | Red no unida correctamente | `sudo zerotier-cli join <ID>` y esperar autorización |
| Base de datos no creada | Script init no ejecutó | Ejecutar manualmente `mysql ... < init/01-schema.sql` |

---

## 18. Checklist final (confirmación de que todo funciona)

```bash
# Ejecutar este script para verificar todos los servicios

cat > /tmp/check_deployment.sh <<'CHECK'
#!/bin/bash
echo "=== Verificación de Despliegue en Ubuntu ==="
echo ""

# 1. ZeroTier
echo "1. ZeroTier IP:"
sudo zerotier-cli status 2>/dev/null | grep -o '192\.168\.196\.[0-9]*' || echo "No conectado"

# 2. MySQL
echo ""
echo "2. MySQL (puerto 3307):"
mysql -h127.0.0.1 -P3307 -uweb -pImportaciones@2025 -e "SELECT VERSION();" 2>/dev/null || echo "No accesible"

# 3. Backend
echo ""
echo "3. Backend API (puerto 4000):"
curl -sS http://localhost:4000/clientes 2>/dev/null | jq '. | length' || echo "No responde"

# 4. Frontend
echo ""
echo "4. Frontend (puerto 5173):"
curl -sS http://localhost:5173/ 2>/dev/null | grep -q "site-root" && echo "OK" || echo "No responde"

# 5. Procesos
echo ""
echo "5. Procesos activos:"
ps aux | grep -E '[n]ode|[d]ocker|zerotier' | wc -l

echo ""
echo "=== Fin de verificación ==="
CHECK

chmod +x /tmp/check_deployment.sh
/tmp/check_deployment.sh
```

---

## 19. Operaciones comunes en Cluster Multi-Maestro

### 19.1 Crear cliente desde Node3 (Ubuntu) y verificar replicación en Node1/Node2

```bash
# Crear cliente en Node3 (puerto 3309)
mysql -h127.0.0.1 -P3309 -uadmin -pPasswordSeguro123 Importaciones_Animales_Valencia -e "
  INSERT INTO clientes (nombre_completo, dni_cif, email, telefono, sede_registro)
  VALUES ('Cliente desde Node3 Ubuntu', '77777777Y', 'node3@ubuntu.test', '+34777888999', 'Linux');
"

# Verificar que existe en Node1 (macOS) - debería replicarse automáticamente
mysql -h127.0.0.1 -P3307 -uadmin -pPasswordSeguro123 Importaciones_Animales_Valencia -e "
  SELECT cliente_id, nombre_completo, sede_registro FROM clientes 
  WHERE nombre_completo LIKE '%Node3%' LIMIT 1;
"

# Verificar que existe en Node2 (Windows)
mysql -h127.0.0.1 -P3308 -uadmin -pPasswordSeguro123 Importaciones_Animales_Valencia -e "
  SELECT cliente_id, nombre_completo, sede_registro FROM clientes 
  WHERE nombre_completo LIKE '%Node3%' LIMIT 1;
"
```

### 19.2 Crear venta desde Node2 (Windows) y verificar sincronización

```bash
# En Node2 (Windows, puerto 3308)
mysql -h127.0.0.1 -P3308 -uadmin -pPasswordSeguro123 Importaciones_Animales_Valencia -e "
  INSERT INTO ventas (cliente_id, sede_origen, total, estado)
  VALUES (1, 'Sede A (Windows)', 5999.99, 'COMPLETADO');
"

# Verificar en Node1 y Node3
# (debería estar visible en todos dentro de segundos)
mysql -h127.0.0.1 -P3307 -uadmin -pPasswordSeguro123 Importaciones_Animales_Valencia -e "
  SELECT COUNT(*) as total_ventas FROM ventas;
"
```

### 19.3 Detener y reiniciar cluster

```bash
# Parar todos los contenedores
docker-compose -f docker-compose-cluster.yml down

# Reiniciar
docker-compose -f docker-compose-cluster.yml up -d

# Re-inicializar replicación (si es necesario)
/home/ubuntu/importaciones/scripts/init-cluster.sh
```

---

## 20. Checklist final (confirmación de que todo funciona)

```bash
# Script de verificación completa
cat > /tmp/check_cluster.sh <<'CHECK'
#!/bin/bash
echo "=== Verificación de Cluster Multi-Maestro ==="
echo ""

# 1. Contenedores Docker
echo "1. Estados de contenedores:"
docker ps --format "{{.Names}}\t{{.Status}}" | grep importaciones

# 2. Conexión a los 3 nodos
echo ""
echo "2. Conexión a nodos MySQL:"
for port in 3307 3308 3309; do
  mysql -h127.0.0.1 -P$port -uadmin -pPasswordSeguro123 -e "SELECT 1;" 2>/dev/null && \
    echo "  ✓ Puerto $port: OK" || echo "  ✗ Puerto $port: FALLO"
done

# 3. Estado del grupo de replicación
echo ""
echo "3. Miembros del grupo de replicación:"
mysql -h127.0.0.1 -P3307 -uadmin -pPasswordSeguro123 -e "
  SELECT MEMBER_STATE, COUNT(*) FROM performance_schema.replication_group_members GROUP BY MEMBER_STATE;
" 2>/dev/null || echo "  Error: No se pudo consultar grupo"

# 4. Consistencia de datos
echo ""
echo "4. Consistencia de datos (clientes):"
for port in 3307 3308 3309; do
  count=$(mysql -h127.0.0.1 -P$port -uadmin -pPasswordSeguro123 \
    Importaciones_Animales_Valencia -e "SELECT COUNT(*) FROM clientes;" 2>/dev/null | tail -1)
  echo "  Node (puerto $port): $count clientes"
done

# 5. Backend y Frontend
echo ""
echo "5. Servicios de aplicación:"
curl -sS http://localhost:4000/clientes 2>/dev/null | jq '. | length' >/dev/null && \
  echo "  ✓ Backend API: OK" || echo "  ✗ Backend API: FALLO"
curl -sS http://localhost:5173/ 2>/dev/null | grep -q "site-root" && \
  echo "  ✓ Frontend: OK" || echo "  ✗ Frontend: FALLO"

echo ""
echo "=== Fin de verificación ==="
CHECK

chmod +x /tmp/check_cluster.sh
/tmp/check_cluster.sh
```

---

## Resumen de comandos clave

```bash
# Clonar/actualizar
cd /home/ubuntu/importaciones && git pull

# Levantar Docker
docker-compose -f docker-compose.node3.yml up -d

# Instalar dependencias
npm --prefix backend install
npm --prefix frontend install

# Arrancar servicios (pantalla dividida o en segundo plano)
npm --prefix backend run start &
npm --prefix frontend run start &

# Verificar
curl http://localhost:4000/clientes
curl http://localhost:5173/

# Logs
docker logs importaciones_db
pm2 logs
```

---

**¡Tu despliegue en Ubuntu está listo!**
