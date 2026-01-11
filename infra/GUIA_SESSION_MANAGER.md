# Guía: Configuración y Uso de AWS Systems Manager Session Manager

## Problema: Session Manager no está habilitado

Si intentas conectarte a una instancia EC2 y Session Manager no está habilitado, esto puede deberse a varias razones:

### 1. Instancias Existentes sin IAM Role

**Problema:** Las instancias que ya están ejecutándose fueron creadas antes de aplicar los cambios de configuración del IAM Role, por lo que no tienen el IAM Instance Profile asociado.

**Solución:**
- **Opción A (Recomendada):** Recrear las instancias para que usen el nuevo Launch Template con el IAM Role
  - Terminar las instancias existentes
  - El Auto Scaling Group creará nuevas instancias automáticamente con el Launch Template actualizado
  ```bash
  # En la consola de AWS, seleccionar las instancias y terminarlas
  # O usar AWS CLI:
  aws autoscaling terminate-instance-in-auto-scaling-group --instance-id i-xxxxx --should-decrement-desired-capacity
  ```

- **Opción B:** Asociar manualmente el IAM Instance Profile a instancias existentes
  - En la consola de EC2, seleccionar la instancia
  - Acciones → Seguridad → Modificar IAM role
  - Seleccionar el IAM Role: `genius-{ambiente}-ssm-role`
  - Guardar

### 2. Usar la Pestaña Correcta en la Consola

**Importante:** Debes usar la pestaña "**Administrador de sesiones**" (Session Manager), NO "Conexión de la instancia EC2" (EC2 Instance Connect).

**Pasos para conectarse:**
1. Consola de AWS → EC2 → Instancias
2. Seleccionar la instancia
3. Clic en "**Conectar**"
4. Seleccionar la pestaña "**Administrador de sesiones**" (Session Manager)
5. Clic en "**Conectar**"

### 3. Verificar Configuración de la Instancia

Para verificar si una instancia está correctamente configurada para Session Manager:

1. **Verificar IAM Role asociado:**
   - En la consola EC2, seleccionar la instancia
   - Ir a la pestaña "Seguridad"
   - Verificar que el IAM role sea `genius-{ambiente}-ssm-role`

2. **Verificar SSM Agent (desde otra instancia o usando AWS CLI):**
   ```bash
   aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-xxxxx"
   ```
   - Si la instancia aparece en los resultados, el SSM Agent está funcionando
   - Si no aparece, el SSM Agent no puede comunicarse con el servicio SSM

3. **Verificar conectividad de red:**
   - Las instancias deben estar en subredes privadas
   - Las subredes privadas deben tener rutas al NAT Gateway
   - El NAT Gateway permite salida a Internet (requerido para SSM)

### 4. Verificar Permisos IAM del Usuario

El usuario de AWS que intenta conectarse necesita permisos para usar Session Manager:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:StartSession"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ssm:*:*:document/AWS-StartSSMSession"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeInstanceInformation",
                "ssm:DescribeInstanceProperties"
            ],
            "Resource": "*"
        }
    ]
}
```

### 5. Aplicar Cambios de Terraform

Si aún no has aplicado los cambios de Terraform:

```bash
# Navegar al ambiente correspondiente (dev, qa, prod)
cd infra/envs/dev  # o qa/prod

# Inicializar (si es necesario)
terraform init

# Plan para ver los cambios
terraform plan

# Aplicar los cambios
terraform apply
```

**Importante:** Después de aplicar los cambios, las instancias existentes NO se actualizarán automáticamente. Necesitas recrearlas o asociar manualmente el IAM Role.

### 6. Verificar Instancias Nuevas

Para verificar que las nuevas instancias tengan la configuración correcta:

1. **Verificar en la consola:**
   - Nueva instancia creada después de aplicar Terraform
   - Pestaña "Seguridad" → Verificar IAM role: `genius-{ambiente}-ssm-role`
   - Pestaña "Conectar" → La pestaña "Administrador de sesiones" debe estar disponible

2. **Verificar SSM Agent:**
   ```bash
   aws ssm describe-instance-information \
     --filters "Key=InstanceIds,Values=i-xxxxx" \
     --query "InstanceInformationList[0].PingStatus"
   ```
   - Debe retornar "Online" si está funcionando correctamente

### 7. Diagnóstico Rápido

**Checklist de verificación:**

- [ ] IAM Role `genius-{ambiente}-ssm-role` existe en IAM
- [ ] IAM Role tiene la política `AmazonSSMManagedInstanceCore` adjunta
- [ ] IAM Instance Profile `genius-{ambiente}-ssm-profile` existe
- [ ] Instancia tiene el IAM Role asociado
- [ ] Instancia está en una subred privada (sin IP pública)
- [ ] Subred privada tiene ruta al NAT Gateway
- [ ] NAT Gateway está activo y configurado correctamente
- [ ] SSM Agent está instalado y ejecutándose en la instancia
- [ ] Usuario tiene permisos IAM para usar Session Manager
- [ ] Estás usando la pestaña "Administrador de sesiones" en la consola

### 8. Solución Rápida: Recrear Instancias

Si las instancias existentes no tienen el IAM Role, la forma más rápida es recrearlas:

```bash
# Opción 1: Desde la consola
# - Seleccionar todas las instancias del ASG
# - Acciones → Estado de la instancia → Terminar
# - El ASG creará nuevas instancias automáticamente

# Opción 2: Desde AWS CLI
INSTANCE_ID="i-xxxxx"
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id $INSTANCE_ID \
  --should-decrement-desired-capacity false

# Esperar a que el ASG cree nuevas instancias con el Launch Template actualizado
```

### 9. Verificar Logs del SSM Agent (si puedes acceder)

Si tienes otra forma de acceder a la instancia, puedes verificar los logs del SSM Agent:

```bash
# En Amazon Linux 2
sudo tail -f /var/log/amazon/ssm/amazon-ssm-agent.log

# Verificar estado del servicio
sudo systemctl status amazon-ssm-agent
```

## Comandos Útiles

### Listar instancias registradas en SSM:
```bash
aws ssm describe-instance-information \
  --query "InstanceInformationList[*].[InstanceId,ComputerName,PingStatus]" \
  --output table
```

### Iniciar sesión desde AWS CLI:
```bash
aws ssm start-session --target i-xxxxx
```

### Verificar permisos del IAM Role:
```bash
aws iam get-role --role-name genius-dev-ssm-role
aws iam list-attached-role-policies --role-name genius-dev-ssm-role
```

## Notas Importantes

1. **Las instancias deben tener salida a Internet** para que el SSM Agent pueda comunicarse con el servicio SSM. Esto se logra mediante NAT Gateway (ya configurado).

2. **No se requieren IPs públicas** para Session Manager. Las instancias pueden estar en subredes privadas.

3. **El SSM Agent viene preinstalado** en Amazon Linux 2, pero el user_data script ahora lo asegura iniciado y habilitado.

4. **Las instancias creadas ANTES de aplicar los cambios de Terraform** necesitarán ser recreadas o tener el IAM Role asociado manualmente.

## Referencias

- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Configurar Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started.html)
- [Requisitos para Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html)
