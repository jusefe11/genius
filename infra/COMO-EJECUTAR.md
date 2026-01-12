# 🚀 Cómo Ejecutar test-metrics.ps1

## 📋 **Método 1: Desde PowerShell (RECOMENDADO)**

### **Paso a paso:**

1. **Abre PowerShell:**
   - Presiona `Windows + X`
   - Selecciona "Windows PowerShell" o "Terminal"
   - O busca "PowerShell" en el menú de inicio

2. **Navega a la carpeta infra:**
   ```powershell
   cd C:\Users\jusef\OneDrive\Documentos\genius\infra
   ```

3. **Ejecuta el script:**
   ```powershell
   .\test-metrics.ps1
   ```

---

## ⚠️ **Si aparece error de "Política de ejecución"**

Si ves este error:
```
.\test-metrics.ps1 : No se puede cargar el archivo porque la ejecución de scripts está deshabilitada en este sistema.
```

### **Solución rápida (temporal):**

Ejecuta esto en PowerShell (como Administrador):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Luego intenta ejecutar el script de nuevo:
```powershell
.\test-metrics.ps1
```

### **O ejecuta directamente con bypass:**

```powershell
powershell -ExecutionPolicy Bypass -File .\test-metrics.ps1
```

---

## 📋 **Método 2: Desde el Explorador de Archivos**

1. **Abre el Explorador de Archivos**
2. **Navega a:**
   ```
   C:\Users\jusef\OneDrive\Documentos\genius\infra
   ```
3. **Haz clic derecho en `test-metrics.ps1`**
4. **Selecciona "Ejecutar con PowerShell"**

---

## 📋 **Método 3: Desde Visual Studio Code / Cursor**

1. **Abre el archivo `test-metrics.ps1` en tu editor**
2. **Abre la terminal integrada** (Ctrl + ` o Terminal → New Terminal)
3. **Asegúrate de estar en la carpeta correcta:**
   ```powershell
   cd infra
   ```
4. **Ejecuta:**
   ```powershell
   .\test-metrics.ps1
   ```

---

## ✅ **Verificación rápida**

Para verificar que estás en la carpeta correcta:
```powershell
# Ver dónde estás
pwd

# Debería mostrar:
# C:\Users\jusef\OneDrive\Documentos\genius\infra

# Ver si el archivo existe
Test-Path .\test-metrics.ps1

# Debería mostrar: True
```

---

## 🎯 **Ejemplo completo de ejecución**

```powershell
# 1. Abrir PowerShell
# 2. Navegar a la carpeta
cd C:\Users\jusef\OneDrive\Documentos\genius\infra

# 3. Verificar que el archivo existe
ls test-metrics.ps1

# 4. Ejecutar el script
.\test-metrics.ps1

# 5. Seleccionar una opción del menú (1-7)
# 6. Seguir las instrucciones en pantalla
```

---

## ❓ **Problemas comunes**

### **Error: "No se puede cargar el archivo"**
**Solución:** Ejecuta como administrador o usa:
```powershell
powershell -ExecutionPolicy Bypass -File .\test-metrics.ps1
```

### **Error: "No se encuentra el archivo"**
**Solución:** Verifica que estás en la carpeta correcta:
```powershell
cd C:\Users\jusef\OneDrive\Documentos\genius\infra
ls test-metrics.ps1
```

### **Error: "Terraform no encontrado"**
**Solución:** Asegúrate de tener Terraform instalado y en el PATH, o ejecuta desde la carpeta `envs\dev` donde está el estado de Terraform.

---

## 💡 **Tip: Crear un acceso directo**

Puedes crear un acceso directo para ejecutar el script más fácilmente:

1. **Crea un archivo `.bat`** llamado `ejecutar-pruebas.bat`:
   ```batch
   @echo off
   cd /d "C:\Users\jusef\OneDrive\Documentos\genius\infra"
   powershell -ExecutionPolicy Bypass -File .\test-metrics.ps1
   pause
   ```

2. **Guárdalo en la carpeta `infra`**

3. **Haz doble clic en `ejecutar-pruebas.bat`** para ejecutar el script

---

## 🎉 **¡Listo!**

Una vez que ejecutes el script, verás un menú como este:

```
========================================
Pruebas por Métrica del Dashboard
========================================

MÉTRICAS DEL DASHBOARD:
  1. HealthyHostCount (Widget 1 - Hosts Saludables)
  2. UnHealthyHostCount (Widget 1 y 4 - Hosts No Saludables)
  3. CPUUtilization (Widget 2 - Uso de CPU)
  4. HTTPCode_Target_5XX_Count (Widget 3 - Errores 5xx)

PRUEBAS COMBINADAS:
  5. Prueba completa: Todas las métricas

VERIFICACIÓN:
  6. Verificar estado de alarmas
  7. Verificar métricas directamente (AWS CLI)

Selecciona una opción (1-7):
```

¡Solo selecciona el número y presiona Enter! 🚀
