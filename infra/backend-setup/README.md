# Setup del Backend Remoto de Terraform

Este directorio contiene la configuración para crear los recursos necesarios para el backend remoto de Terraform (S3 + DynamoDB).

## ⚠️ IMPORTANTE

**Ejecuta esto UNA SOLA VEZ antes de usar los backends remotos en los ambientes.**

Este setup se ejecuta con **backend local** porque estamos creando los recursos que luego almacenarán el estado.

## 📋 Prerrequisitos

1. AWS CLI configurado con credenciales válidas
2. Terraform instalado (>= 1.0)
3. Permisos para crear recursos en AWS:
   - S3: Crear buckets, configurar versionado y encriptación
   - DynamoDB: Crear tablas

## 🚀 Cómo ejecutar

```bash
# 1. Navega al directorio
cd infra/backend-setup

# 2. Inicializa Terraform (con backend local por defecto)
terraform init

# 3. Revisa el plan
terraform plan

# 4. Crea los recursos
terraform apply
```

## 📦 Recursos creados

1. **Bucket S3**: `genius-terraform-state`
   - Versionado habilitado
   - Encriptación habilitada (AES256)
   - Bloqueo de acceso público

2. **Tabla DynamoDB**: `terraform-locks`
   - Modo PAY_PER_REQUEST (sin capacidad reservada)
   - Clave primaria: `LockID` (String)

## ✅ Después de ejecutar

Una vez creados estos recursos, los archivos `backend.tf` en cada ambiente (dev/qa/prod) podrán usar el backend remoto.

**Pasos siguientes:**

1. Para cada ambiente (dev, qa, prod), ejecuta:
   ```bash
   cd infra/envs/<environment>
   terraform init -migrate-state
   ```
   Esto migrará el estado local al backend remoto.

2. Verifica que el estado se haya migrado correctamente:
   ```bash
   terraform state list
   ```

## 🔒 Seguridad

- El bucket S3 bloquea el acceso público
- El estado está encriptado automáticamente
- La tabla DynamoDB previene modificaciones concurrentes (state locking)

## 🗑️ Eliminación

**⚠️ CUIDADO**: Estos recursos tienen `prevent_destroy = true` para evitar eliminaciones accidentales.

Para eliminarlos, primero:
1. Comenta `prevent_destroy = true` en `main.tf`
2. Ejecuta `terraform destroy`