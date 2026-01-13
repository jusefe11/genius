#!/bin/bash
# Script para saturar la CPU en el servidor
# Uso: ./saturar-cpu.sh [minutos] [metodo]

MINUTOS=${1:-5}  # Default: 5 minutos
METODO=${2:-stress-ng}  # Default: stress-ng

echo "Saturando CPU por $MINUTOS minutos usando metodo: $METODO"

# Detener procesos anteriores
sudo pkill -9 stress-ng yes 2>/dev/null || true

case $METODO in
    stress-ng)
        # Método 1: stress-ng (requiere instalación)
        if command -v stress-ng &> /dev/null; then
            CPU_COUNT=$(nproc)
            echo "Usando stress-ng con $CPU_COUNT CPUs"
            sudo nohup stress-ng --cpu $CPU_COUNT --timeout ${MINUTOS}m > /tmp/stress-ng.log 2>&1 &
            echo "stress-ng iniciado (PID: $!)"
        else
            echo "ERROR: stress-ng no esta instalado. Instalando..."
            sudo yum install -y stress-ng
            CPU_COUNT=$(nproc)
            sudo nohup stress-ng --cpu $CPU_COUNT --timeout ${MINUTOS}m > /tmp/stress-ng.log 2>&1 &
            echo "stress-ng iniciado (PID: $!)"
        fi
        ;;
    
    yes)
        # Método 2: yes (siempre disponible)
        CPU_COUNT=$(nproc)
        echo "Usando procesos 'yes' con $CPU_COUNT CPUs"
        for i in $(seq 1 $CPU_COUNT); do
            nohup yes > /dev/null 2>&1 &
            echo "Proceso yes $i iniciado (PID: $!)"
        done
        echo "Total procesos yes: $(pgrep yes | wc -l)"
        ;;
    
    dd)
        # Método 3: dd (siempre disponible)
        CPU_COUNT=$(nproc)
        echo "Usando procesos 'dd' con $CPU_COUNT CPUs"
        for i in $(seq 1 $CPU_COUNT); do
            nohup dd if=/dev/zero of=/dev/null bs=1M 2>/dev/null &
            echo "Proceso dd $i iniciado (PID: $!)"
        done
        ;;
    
    *)
        echo "Metodo desconocido: $METODO"
        echo "Metodos disponibles: stress-ng, yes, dd"
        exit 1
        ;;
esac

echo ""
echo "CPU saturada. Para detener:"
echo "  sudo pkill stress-ng  # Si usaste stress-ng"
echo "  pkill yes             # Si usaste yes"
echo "  pkill dd              # Si usaste dd"
echo ""
echo "Verificar CPU: top -bn1 | head -5"
