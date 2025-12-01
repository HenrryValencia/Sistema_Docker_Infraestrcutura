# ZEROTIER SETUP - IP Configuration

## ZeroTier IPs (as of 2025-11-28)

```
Node1 (macOS):      192.168.196.151:3306 (port 3307 exposed)
Node2 (Windows):    192.168.196.115:3306 (port 3308 exposed)
Node3 (Ubuntu):     192.168.196.245:3306 (port 3309 exposed)
```

## Network Architecture

```
                    ┌─────────────────────────────────┐
                    │    ZeroTier Network              │
                    │  192.168.196.0/24                │
                    └─────────────┬───────────────────┘
                                  │
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
      ┌─────▼────┐          ┌─────▼────┐          ┌─────▼────┐
      │  macOS   │          │ Windows  │          │  Ubuntu  │
      │ Node1    │          │ Node2    │          │ Node3    │
      │ .151     │──────────│ .115     │──────────│ .245     │
      └──────────┘          └──────────┘          └──────────┘
      (Bootstrap)          (Join Group)         (Join Group)
```

## How to Execute on Ubuntu (Node3: 192.168.196.245)

### Step 1: Ensure ZeroTier is Joined
```bash
sudo zerotier-cli join aaaaaaaa-bbbb-cccc-dddd-eeeeffff0000
# Authorize the Ubuntu node in ZeroTier Central if needed
```

### Step 2: Verify ZeroTier IP
```bash
ip addr show | grep 192.168.196
# Should show: inet 192.168.196.245/29 ...
```

### Step 3: Prepare Project Directory
```bash
cd ~/mysql-cluster
chmod +x scripts/init-cluster.sh
chmod +x scripts/auto-sync-cluster.sh
```

### Step 4: Start Docker Containers
```bash
docker-compose -f docker-compose-cluster.yml up -d
sleep 30
docker ps | grep importaciones
```

### Step 5: Initialize Cluster (Run ONLY on Ubuntu first)
```bash
./scripts/init-cluster.sh
```

### Step 6: Verify Cluster Status
```bash
mysql -h192.168.196.151 -P3306 -uadmin -pPasswordSeguro123 -e "
  SELECT MEMBER_STATE, COUNT(*) 
  FROM performance_schema.replication_group_members 
  GROUP BY MEMBER_STATE;
"
```

Expected output: Should show 3 ONLINE members

### Step 7: Setup Auto-Sync (Optional but Recommended)
```bash
# Option A: Run once to verify
./scripts/auto-sync-cluster.sh

# Option B: Run as daemon in background
./scripts/auto-sync-cluster.sh daemon &

# Option C: Add to crontab for automatic sync every 5 minutes
crontab -e
# Add: */5 * * * * /home/ubuntu/mysql-cluster/scripts/auto-sync-cluster.sh >> /var/log/mysql-cluster-sync.log 2>&1
```

## Troubleshooting on Ubuntu

### Problem: "Cannot connect to 192.168.196.151"
```bash
# Check ZeroTier connectivity
sudo zerotier-cli listnetworks
# Should show: aaaaaaaa-bbbb-cccc-dddd-eeeeffff0000 OK PRIVATE ...

# Check if macOS node is reachable
ping -c 3 192.168.196.151

# If no response, ZeroTier may not be properly configured on macOS
```

### Problem: MySQL containers fail to start
```bash
docker logs importaciones_db_node1
docker logs importaciones_db_node2
docker logs importaciones_db_node3

# Common issue: Port already in use (3307, 3308, 3309)
sudo lsof -i :3307
sudo lsof -i :3308
sudo lsof -i :3309
```

### Problem: Group Replication won't start
```bash
# Check if mysql client can connect to all nodes
mysql -h192.168.196.151 -P3306 -uadmin -pPasswordSeguro123 -e "SELECT 1;"
mysql -h192.168.196.115 -P3306 -uadmin -pPasswordSeguro123 -e "SELECT 1;"
mysql -h192.168.196.245 -P3306 -uadmin -pPasswordSeguro123 -e "SELECT 1;"

# Check replication user exists
mysql -h192.168.196.151 -P3306 -uadmin -pPasswordSeguro123 -e "SELECT USER FROM mysql.user WHERE USER='repl_admin';"
```

### Problem: Data not syncing
```bash
# Check if all nodes are in ONLINE state
mysql -h192.168.196.151 -P3306 -uadmin -pPasswordSeguro123 -e "
  SELECT * FROM performance_schema.replication_group_members;
"

# Run sync verification
./scripts/auto-sync-cluster.sh

# Check logs
tail -50 /var/log/mysql-cluster-sync.log
```

## Important Notes

⚠️ **ZeroTier IP Dependencies:**
- Node1 (macOS) must be at 192.168.196.151
- Node2 (Windows) must be at 192.168.196.115
- Node3 (Ubuntu) must be at 192.168.196.245

If your actual ZeroTier IPs differ, update:
1. `conf/mysqld.node*.cnf` (group_replication_group_seeds and group_replication_local_address)
2. `scripts/init-cluster.sh` (all mysql -h commands)
3. `scripts/auto-sync-cluster.sh` (all mysql -h commands)

⚠️ **MySQL Credentials:**
- root: PasswordSeguro123
- admin: PasswordSeguro123
- repl_admin: ReplPass123!

🔒 **Security Note:**
Change these passwords for production!
