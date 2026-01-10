# Tabla de Recursos Desplegados - Ambiente DEV

Esta tabla muestra todos los recursos de AWS que se crean al ejecutar `terraform apply` en el ambiente de desarrollo.

## 📊 Resumen General

| Categoría | Cantidad | Descripción |
|-----------|----------|-------------|
| **Red y Conectividad** | 10 | VPC, IGW, Subredes, NAT Gateways, Route Tables |
| **Seguridad** | 4 | Security Groups (alb, web, app, db) |
| **Load Balancer** | 3 | ALB, Target Group, Listener HTTP |
| **Auto Scaling** | 4 | Launch Template, ASG, 2 Políticas |
| **Instancias EC2** | 2 | Instancias creadas por el ASG (desired_capacity) |
| **Data Sources** | 1 | AMI más reciente de Amazon Linux 2 |
| **TOTAL** | **24** | Recursos principales |

---

## 🔷 RED Y CONECTIVIDAD

| # | Recurso AWS | Tipo | Nombre | Configuración | Descripción |
|---|-------------|------|--------|---------------|-------------|
| 1 | `aws_vpc.main` | VPC | `genius-dev-vpc` | CIDR: `10.0.0.0/16` | VPC dedicada con DNS habilitado |
| 2 | `aws_internet_gateway.main` | Internet Gateway | `genius-dev-igw` | Asociado a VPC | Gateway para acceso público a Internet |
| 3 | `aws_subnet.public[0]` | Subnet | `genius-dev-public-subnet-1` | CIDR: `10.0.1.0/24`<br>AZ: `us-east-1a`<br>`map_public_ip_on_launch = true` | Subred pública en AZ 1 |
| 4 | `aws_subnet.public[1]` | Subnet | `genius-dev-public-subnet-2` | CIDR: `10.0.2.0/24`<br>AZ: `us-east-1b`<br>`map_public_ip_on_launch = true` | Subred pública en AZ 2 |
| 5 | `aws_subnet.private[0]` | Subnet | `genius-dev-private-subnet-1` | CIDR: `10.0.10.0/24`<br>AZ: `us-east-1a` | Subred privada en AZ 1 |
| 6 | `aws_subnet.private[1]` | Subnet | `genius-dev-private-subnet-2` | CIDR: `10.0.20.0/24`<br>AZ: `us-east-1b` | Subred privada en AZ 2 |
| 7 | `aws_eip.nat[0]` | Elastic IP | `genius-dev-nat-eip-1` | Domain: VPC | IP elástica para NAT Gateway 1 |
| 8 | `aws_eip.nat[1]` | Elastic IP | `genius-dev-nat-eip-2` | Domain: VPC | IP elástica para NAT Gateway 2 |
| 9 | `aws_nat_gateway.main[0]` | NAT Gateway | `genius-dev-nat-1` | Subnet: `public[0]`<br>EIP: `nat[0]` | NAT Gateway en AZ 1 |
| 10 | `aws_nat_gateway.main[1]` | NAT Gateway | `genius-dev-nat-2` | Subnet: `public[1]`<br>EIP: `nat[1]` | NAT Gateway en AZ 2 |
| 11 | `aws_route_table.public` | Route Table | `genius-dev-public-rt` | Ruta: `0.0.0.0/0` → IGW | Tabla de ruteo para subredes públicas |
| 12 | `aws_route_table.private[0]` | Route Table | `genius-dev-private-rt-1` | Ruta: `0.0.0.0/0` → NAT[0] | Tabla de ruteo para subred privada 1 |
| 13 | `aws_route_table.private[1]` | Route Table | `genius-dev-private-rt-2` | Ruta: `0.0.0.0/0` → NAT[1] | Tabla de ruteo para subred privada 2 |
| 14 | `aws_route_table_association.public[0]` | Route Table Association | - | Subnet: `public[0]`<br>RT: `public` | Asociación subred pública 1 |
| 15 | `aws_route_table_association.public[1]` | Route Table Association | - | Subnet: `public[1]`<br>RT: `public` | Asociación subred pública 2 |
| 16 | `aws_route_table_association.private[0]` | Route Table Association | - | Subnet: `private[0]`<br>RT: `private[0]` | Asociación subred privada 1 |
| 17 | `aws_route_table_association.private[1]` | Route Table Association | - | Subnet: `private[1]`<br>RT: `private[1]` | Asociación subred privada 2 |

---

## 🔒 SEGURIDAD

| # | Recurso AWS | Tipo | Nombre | Reglas de Entrada | Reglas de Salida | Descripción |
|---|-------------|------|--------|-------------------|------------------|-------------|
| 18 | `aws_security_group.alb` | Security Group | `genius-dev-alb-sg` | • HTTP (80) desde `0.0.0.0/0`<br>• HTTPS (443) desde `0.0.0.0/0` | • Todo el tráfico (`0.0.0.0/0`) | Security Group para Application Load Balancer |
| 19 | `aws_security_group.web` | Security Group | `genius-dev-web-sg` | • HTTP (80) desde `0.0.0.0/0`<br>• HTTPS (443) desde `0.0.0.0/0` | • Todo el tráfico (`0.0.0.0/0`) | Alias para compatibilidad (mismo que alb-sg) |
| 20 | `aws_security_group.app` | Security Group | `genius-dev-app-sg` | • Puerto 8080 desde `alb-sg`<br>• Puerto 8080 desde `self` | • Todo el tráfico (`0.0.0.0/0`) | Security Group para instancias de aplicación |
| 21 | `aws_security_group.db` | Security Group | `genius-dev-db-sg` | • Puerto 3306 desde `app-sg`<br>• Puerto 3306 desde `self` | • Puerto 3306 hacia `app-sg`<br>• Puerto 3306 hacia `self` | Security Group para bases de datos (futuro) |

**Nota:** Los Security Groups `redis-sg` y `bastion-sg` NO se crean en DEV porque `enable_redis = false` y `enable_ssh = false` por defecto.

---

## ⚖️ LOAD BALANCER

| # | Recurso AWS | Tipo | Nombre | Configuración | Descripción |
|---|-------------|------|--------|---------------|-------------|
| 22 | `aws_lb.main` | Application Load Balancer | `genius-dev-alb` | • Tipo: Application<br>• Internal: `false` (público)<br>• Subredes: Públicas (2 AZs)<br>• Security Groups: `alb-sg`<br>• Deletion Protection: `false` | Load Balancer público en subredes públicas |
| 23 | `aws_lb_target_group.app` | Target Group | `genius-dev-tg` | • Puerto: `8080`<br>• Protocolo: HTTP<br>• Health Check: `/` cada 30s<br>• Healthy Threshold: 2<br>• Unhealthy Threshold: 2 | Grupo de destino para instancias EC2 |
| 24 | `aws_lb_listener.http` | Listener | `genius-dev-http-listener` | • Puerto: `80`<br>• Protocolo: HTTP<br>• Acción: Forward a Target Group | Listener HTTP que redirige al Target Group |

**Nota:** El Listener HTTPS NO se crea en DEV porque `enable_https = false` por defecto.

---

## 💻 AUTO SCALING Y COMPUTO

| # | Recurso AWS | Tipo | Nombre | Configuración | Descripción |
|---|-------------|------|--------|---------------|-------------|
| 25 | `aws_launch_template.app` | Launch Template | `genius-dev-*` | • AMI: Amazon Linux 2 (más reciente)<br>• Instance Type: `t3.micro`<br>• Security Groups: `app-sg`<br>• User Data: Script de inicialización | Template para lanzar instancias EC2 |
| 26 | `aws_autoscaling_group.app` | Auto Scaling Group | `genius-dev-asg` | • Min Size: `1`<br>• Desired Capacity: `2`<br>• Max Size: `5`<br>• Health Check: ELB<br>• Subredes: Privadas (2 AZs)<br>• Target Groups: `genius-dev-tg` | Grupo de Auto Scaling que gestiona instancias |
| 27 | `aws_autoscaling_policy.scale_up` | Auto Scaling Policy | `genius-dev-scale-up` | • Tipo: SimpleScaling<br>• Ajuste: `+1` instancia<br>• Cooldown: `300` segundos | Política para escalar hacia arriba |
| 28 | `aws_autoscaling_policy.scale_down` | Auto Scaling Policy | `genius-dev-scale-down` | • Tipo: SimpleScaling<br>• Ajuste: `-1` instancia<br>• Cooldown: `300` segundos | Política para escalar hacia abajo |
| 29-30 | `aws_instance` (vía ASG) | EC2 Instance | `genius-dev-app-*` | • Tipo: `t3.micro`<br>• AMI: Amazon Linux 2<br>• Subred: Privada<br>• Security Group: `app-sg`<br>• User Data: Instala Docker y Nginx | **2 instancias** creadas por el ASG (desired_capacity = 2) |

---

## 📊 DATA SOURCES

| # | Data Source | Tipo | Descripción |
|---|-------------|------|-------------|
| 31 | `data.aws_ami.amazon_linux[0]` | Data Source | Obtiene la AMI más reciente de Amazon Linux 2 (solo si `ami_id = ""`) |

---

## 📋 Configuración Específica del Ambiente DEV

### Red
- **VPC CIDR**: `10.0.0.0/16`
- **Subredes Públicas**: 
  - `10.0.1.0/24` (us-east-1a)
  - `10.0.2.0/24` (us-east-1b)
- **Subredes Privadas**: 
  - `10.0.10.0/24` (us-east-1a)
  - `10.0.20.0/24` (us-east-1b)
- **NAT Gateways**: 2 (uno por AZ)

### Aplicación
- **Puerto de Aplicación**: `8080`
- **Instance Type**: `t3.micro`
- **Auto Scaling**: 
  - Mínimo: `1` instancia
  - Deseado: `2` instancias
  - Máximo: `5` instancias
- **HTTPS**: Deshabilitado (solo HTTP)
- **Deletion Protection**: Desactivado

### Base de Datos (Preparado para futuro)
- **Puerto DB**: `3306` (MySQL)
- **Security Group**: `db-sg` creado pero sin recursos asociados aún

---

## 🔄 Flujo de Tráfico

```
Internet (0.0.0.0/0)
  ↓ [HTTP - Puerto 80]
Application Load Balancer (ALB)
  ├─ Ubicación: Subredes Públicas (us-east-1a, us-east-1b)
  ├─ Security Group: alb-sg
  └─ Listener HTTP (puerto 80)
      ↓ [HTTP - Puerto 8080]
Target Group (genius-dev-tg)
  ├─ Health Check: / (cada 30s)
  └─ Protocolo: HTTP
      ↓ [Solo desde alb-sg]
Auto Scaling Group (ASG)
  ├─ Ubicación: Subredes Privadas (us-east-1a, us-east-1b)
  ├─ Security Group: app-sg
  └─ Instancias: 2 (desired_capacity)
      ↓
EC2 Instances (2 instancias t3.micro)
  ├─ Puerto: 8080
  ├─ User Data: Docker + Nginx
  └─ Acceso a Internet: Vía NAT Gateway
```

---

## 💰 Costos Estimados (Mensual)

| Recurso | Cantidad | Costo Unitario | Costo Total |
|---------|----------|----------------|-------------|
| NAT Gateway | 2 | ~$32/mes | ~$64/mes |
| Application Load Balancer | 1 | ~$16/mes | ~$16/mes |
| EC2 Instances (t3.micro) | 2 | ~$7.50/mes | ~$15/mes |
| Elastic IPs | 2 | Gratis (en uso) | $0 |
| **TOTAL ESTIMADO** | | | **~$95/mes** |

*Nota: Los costos varían según uso, transferencia de datos y región.*

---

## ✅ Recursos Opcionales NO Desplegados en DEV

Los siguientes recursos NO se crean en DEV porque están deshabilitados:

- ❌ **Listener HTTPS** (`enable_https = false`)
- ❌ **Security Group Redis** (`enable_redis = false`)
- ❌ **Security Group Bastion** (`enable_ssh = false`)
- ❌ **Clave SSH** (`key_name = ""`)

---

## 📝 Notas Importantes

1. **Instancias en Subredes Privadas**: Las instancias EC2 NO tienen IPs públicas y solo acceden a Internet vía NAT Gateway.

2. **Principio de Mínimo Acceso**: El `app-sg` solo acepta tráfico desde `alb-sg`, no desde Internet directamente.

3. **Multi-AZ**: Todos los recursos están distribuidos en al menos 2 zonas de disponibilidad para alta disponibilidad.

4. **Health Checks**: El ALB verifica la salud de las instancias cada 30 segundos en la ruta `/`.

5. **Auto Scaling**: El ASG mantendrá entre 1 y 5 instancias según la carga, con 2 instancias como objetivo.

---

**Última actualización**: Generado automáticamente desde la configuración de Terraform del ambiente DEV.
