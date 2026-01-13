# Resumen: Fix para que las Pruebas se Vean en CloudWatch

## Problemas Identificados

1. **Script envía métricas con `AutoScalingGroupName=unknown`** - El comando `aws autoscaling describe-auto-scaling-instances` falla por falta de permisos IAM
2. **Problema con `sudo`** - Algunos comandos Docker requieren sudo pero está deshabilitado en algunas instancias
3. **Métricas no aparecen en el dashboard** - Las métricas se envían con dimensión incorrecta

## Soluciones Aplicadas

### 1. Permisos IAM Agregados
✅ Agregado permiso `autoscaling:DescribeAutoScalingInstances` en `infra/modules/autoscaling/main.tf`

### 2. Script de Monitoreo Mejorado
✅ Script actualizado en `infra/modules/autoscaling/user_data.sh` para:
- Intentar usar `docker` sin sudo primero
- Obtener ASG name con múltiples métodos (autoscaling API, tags EC2, fallback a "genius-dev-asg")
- Mejor logging de errores

### 3. Script de Pruebas Mejorado
✅ `test-metrics.ps1` actualizado para:
- Intentar comandos Docker sin sudo primero
- Manejar errores de sudo correctamente

## Pasos para Aplicar el Fix

### Opción 1: Aplicar Terraform (Recomendado para nuevas instancias)
```bash
cd infra/envs/dev
terraform plan
terraform apply
```
Esto actualizará los permisos IAM. Las nuevas instancias tendrán el script corregido.

### Opción 2: Actualizar Instancias Existentes Manualmente

Ejecuta este comando en cada instancia vía SSM:

```bash
aws ssm send-command \
  --instance-ids i-XXXXXXXXX \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["/usr/local/bin/monitor-docker-containers.sh"]'
```

O ejecuta el script de diagnóstico para verificar:
```powershell
.\diagnostico-alarmas.ps1
```

## Verificación

1. **Espera 2-3 minutos** después de aplicar los cambios
2. **Verifica el dashboard**: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=genius-dev-application-status
3. **Ejecuta las pruebas** con `.\test-metrics.ps1`
4. **Deberías ver**:
   - Widget CPU: Aumento de CPU cuando ejecutas opción 1
   - Widget Docker: Cambios en contenedores cuando ejecutas opción 2

## Notas Importantes

- Las métricas pueden tardar 1-2 minutos en aparecer en CloudWatch
- El dashboard muestra datos con un delay de ~1 minuto
- Si no ves datos, verifica los logs: `/var/log/docker-monitor.log` y `/var/log/docker-monitor-errors.log`
