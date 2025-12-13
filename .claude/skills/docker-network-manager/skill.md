# Docker Network Manager Skill

Advanced Docker networking troubleshooting, configuration, and optimization.

## Environment

**Docker VM**: 192.168.50.149
- 33 containers across multiple networks
- Complex networking: Supabase internal network, external proxy, isolated services

## Core Capabilities

### 1. Network Discovery & Inspection

#### List Networks

```bash
# List all networks
docker network ls

# Show detailed network info
docker network inspect <network_name>

# List networks with filters
docker network ls --filter driver=bridge
docker network ls --filter type=custom
```

#### Inspect Network Connectivity

```bash
# See which containers are on a network
docker network inspect <network> | jq '.[0].Containers'

# Check container's networks
docker inspect <container> | jq '.[0].NetworkSettings.Networks'

# List all container IPs
docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -q)
```

### 2. Network Creation & Configuration

#### Create Bridge Network

```bash
# Basic bridge network
docker network create app-network

# Bridge with custom subnet
docker network create --driver bridge \
  --subnet=172.20.0.0/16 \
  --ip-range=172.20.240.0/20 \
  --gateway=172.20.0.1 \
  app-network

# Bridge with DNS options
docker network create \
  --driver bridge \
  --opt com.docker.network.bridge.name=br-app \
  --opt com.docker.network.driver.mtu=1450 \
  app-network
```

#### Create Overlay Network (Swarm)

```bash
# Overlay network for multi-host
docker network create \
  --driver overlay \
  --attachable \
  overlay-network

# Encrypted overlay
docker network create \
  --driver overlay \
  --opt encrypted \
  secure-overlay
```

#### Create Macvlan Network

```bash
# Macvlan for direct network access
docker network create -d macvlan \
  --subnet=192.168.50.0/24 \
  --gateway=192.168.50.1 \
  -o parent=eth0 \
  macvlan-network
```

### 3. Connect & Disconnect Containers

```bash
# Connect running container to network
docker network connect app-network container-name

# Connect with specific IP
docker network connect --ip 172.20.0.10 app-network container-name

# Connect with alias (DNS name)
docker network connect --alias api.local app-network container-name

# Disconnect from network
docker network disconnect app-network container-name

# Force disconnect
docker network disconnect -f app-network container-name
```

### 4. Network Troubleshooting

#### Test Connectivity

```bash
# Ping between containers
docker exec container1 ping -c 3 container2

# Test specific port
docker exec container1 nc -zv container2 8080

# DNS resolution test
docker exec container1 nslookup container2

# Trace route
docker exec container1 traceroute container2

# Check listening ports
docker exec container1 netstat -tuln
```

#### Inspect Network Traffic

```bash
# Install tcpdump in container
docker exec -it container apt-get update && apt-get install -y tcpdump

# Capture traffic
docker exec container tcpdump -i eth0 -n

# Capture specific port
docker exec container tcpdump -i eth0 port 8080 -n

# Save pcap file
docker exec container tcpdump -i eth0 -w /tmp/capture.pcap
```

#### Check Network Configuration

```bash
# View container network config
docker exec container ip addr show

# View routing table
docker exec container ip route

# Check iptables rules
docker exec container iptables -L -n

# View DNS configuration
docker exec container cat /etc/resolv.conf
```

### 5. Network Performance Optimization

#### MTU Configuration

```bash
# Create network with custom MTU
docker network create \
  --driver bridge \
  --opt com.docker.network.driver.mtu=1450 \
  optimized-network

# Check current MTU
docker network inspect optimized-network | jq '.[0].Options."com.docker.network.driver.mtu"'
```

#### Network Isolation

```bash
# Create internal network (no external access)
docker network create \
  --internal \
  --driver bridge \
  isolated-network

# Containers can communicate internally but not reach internet
docker run -d --network isolated-network postgres:16
```

## Docker Compose Network Configurations

### Basic Network Setup

```yaml
version: '3.8'

services:
  frontend:
    image: nginx:latest
    networks:
      - frontend-network

  backend:
    image: api:latest
    networks:
      - frontend-network
      - backend-network

  database:
    image: postgres:16
    networks:
      - backend-network

networks:
  frontend-network:
    driver: bridge
  backend-network:
    driver: bridge
    internal: true  # No external access
```

### Advanced Network Configuration

```yaml
networks:
  app-network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br-app
      com.docker.network.driver.mtu: 1450
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
          ip_range: 172.20.240.0/20
    labels:
      environment: production
      team: platform
```

### Service with Static IP

```yaml
services:
  api:
    image: api:latest
    networks:
      app-network:
        ipv4_address: 172.20.0.10
        aliases:
          - api.local
          - backend.local

networks:
  app-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### External Network Connection

```yaml
services:
  app:
    image: myapp:latest
    networks:
      - existing-network

networks:
  existing-network:
    external: true
    name: actual-network-name
```

## Harbor Homelab Network Architecture

### Current Network Topology

```
Internet
  ↓
Nginx Proxy Manager (103) - 192.168.50.103
  ↓
┌─────────────────────────────────────┐
│     Docker VM (192.168.50.149)      │
├─────────────────────────────────────┤
│  Frontend Network                   │
│    - LibreChat                      │
│    - Linkwarden                     │
│    - Postiz                         │
├─────────────────────────────────────┤
│  Backend Network (Internal)         │
│    - Supabase Services              │
│    - N8N                            │
│    - Redis                          │
├─────────────────────────────────────┤
│  Data Network (Isolated)            │
│    - PostgreSQL                     │
│    - MongoDB                        │
│    - Vaultwarden                    │
└─────────────────────────────────────┘
```

### Recommended Network Segmentation

```yaml
# /opt/docker/harbor-networks.yml
version: '3.8'

networks:
  # Public-facing services
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.1.0/24

  # Internal application services
  backend:
    driver: bridge
    internal: false  # Can access external APIs
    ipam:
      config:
        - subnet: 172.20.2.0/24

  # Database and sensitive data
  database:
    driver: bridge
    internal: true  # Fully isolated
    ipam:
      config:
        - subnet: 172.20.3.0/24

  # Monitoring and management
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.4.0/24
```

### Supabase Network Configuration

```yaml
# Supabase specific networking
services:
  kong:
    networks:
      - frontend
      - backend

  auth:
    networks:
      - backend

  rest:
    networks:
      - backend

  db:
    networks:
      - database

  storage:
    networks:
      - backend
      - database

networks:
  frontend:
    external: true
  backend:
    internal: false
  database:
    internal: true
```

## Network Security Best Practices

### 1. Principle of Least Privilege

```yaml
# Only expose necessary ports
services:
  database:
    image: postgres:16
    networks:
      - database  # Internal only
    # No ports exposed to host

  api:
    image: api:latest
    networks:
      - frontend
      - database
    ports:
      - "8080:8080"  # Only API port exposed
```

### 2. Network Segmentation

```yaml
# Separate networks by sensitivity
networks:
  public:      # Internet-facing
  internal:    # Application services
  sensitive:   # Databases, secrets
    internal: true
```

### 3. Use Network Aliases

```yaml
services:
  api:
    networks:
      app-network:
        aliases:
          - api.internal
          - backend.service
```

## Common Network Issues & Solutions

### Issue: Container Can't Reach Internet

```bash
# Check DNS
docker exec container cat /etc/resolv.conf

# Test DNS resolution
docker exec container nslookup google.com

# Check gateway
docker exec container ip route

# Fix: Recreate network
docker network rm app-network
docker network create app-network
```

### Issue: Containers Can't Communicate

```bash
# Verify both on same network
docker network inspect app-network

# Check firewall rules
docker exec container1 ping container2

# Check container names/aliases
docker network inspect app-network | jq '.[0].Containers'

# Fix: Use container names for DNS
# Instead of IP, use: http://container2:8080
```

### Issue: Port Already in Use

```bash
# Find what's using the port
sudo netstat -tulpn | grep :8080
sudo lsof -i :8080

# Fix: Change port mapping
ports:
  - "8081:8080"  # Map to different host port
```

### Issue: Network MTU Mismatch

```bash
# Check MTU
docker network inspect network | jq '.[0].Options."com.docker.network.driver.mtu"'

# Fix: Set correct MTU
docker network create --opt com.docker.network.driver.mtu=1450 network
```

## Advanced Troubleshooting

### Network Performance Testing

```bash
# Install iperf3 in containers
docker exec container1 apt-get install -y iperf3

# Start server
docker exec -d container1 iperf3 -s

# Test from client
docker exec container2 iperf3 -c container1
```

### Network Packet Analysis

```bash
# Capture and analyze traffic
docker exec container tcpdump -i any -w /tmp/capture.pcap

# Copy to host
docker cp container:/tmp/capture.pcap ./

# Analyze with Wireshark or tcpdump
tcpdump -r capture.pcap -n
```

### Check Docker Network Driver

```bash
# View iptables rules created by Docker
sudo iptables -L -n -v -t nat

# Check bridge interfaces
ip link show | grep br-

# Inspect bridge
brctl show
```

## Cleanup & Maintenance

```bash
# Remove unused networks
docker network prune

# Force remove all networks
docker network prune -f

# Remove specific network
docker network rm network-name

# Remove network with containers (force)
docker network rm -f network-name
```

## Integration Points

- **Cortex**: Document network topology and changes
- **AgentDB**: Store network configuration patterns
- **Monitoring**: Track network performance metrics
- **NocoDB**: Log network incidents

## Usage Examples

```bash
Skill({ skill: "docker-network-manager" })

# Request: "Debug why Supabase containers can't communicate"
# - Inspects all Supabase containers
# - Checks network configuration
# - Tests connectivity between services
# - Identifies misconfigured DNS
# - Provides fix

# Request: "Create isolated network for new microservice"
# - Creates internal bridge network
# - Configures subnet and gateway
# - Sets up DNS aliases
# - Documents configuration
# - Provides compose file

# Request: "Why can't container reach internet?"
# - Checks DNS configuration
# - Tests external connectivity
# - Inspects routing table
# - Identifies issue (MTU, firewall, DNS)
# - Applies fix
```
