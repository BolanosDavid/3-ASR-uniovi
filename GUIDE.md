# Guía de uso: Terraform + Ansible en Azure

## Índice

1. [Introducción](#introducción)
2. [Objetivos de aprendizaje](#objetivos-de-aprendizaje)
3. [Arquitectura del proyecto](#arquitectura-del-proyecto)
4. [Requisitos previos](#requisitos-previos)
5. [Instalación de dependencias](#instalación-de-dependencias)
6. [Configuración inicial](#configuración-inicial)
7. [Fase 1: Despliegue con Terraform](#fase-1-despliegue-con-terraform)
8. [Fase 2: Configuración con Ansible](#fase-2-configuración-con-ansible)
9. [Verificación del despliegue](#verificación-del-despliegue)
10. [Gestión de costes](#gestión-de-costes)
11. [Solución de problemas](#solución-de-problemas)
12. [Ampliaciones futuras](#ampliaciones-futuras)

---

## Introducción

Esta plantilla implementa un flujo completo de **Infraestructura como Código (IaC)** dividido en dos fases:

1. **Terraform** → Aprovisiona recursos en Azure
2. **Ansible** → Configura servicios y despliega aplicaciones

El objetivo es entender el proceso completo sin ocultarlo con automatización excesiva. Cada paso se ejecuta manualmente para visualizar qué ocurre en cada fase.

---

## Objetivos de aprendizaje

### Conceptos técnicos

- **Separación de responsabilidades**: Aprovisionamiento vs Configuración
- **Orden de creación de recursos**: RG → Red → Seguridad → VM
- **Seguridad básica**: NSG con reglas restrictivas
- **Integración entre herramientas**: Terraform outputs → Ansible inventory
- **Idempotencia**: Ejecuciones repetibles sin efectos secundarios

### Habilidades prácticas

- Escribir código Terraform para Azure
- Configurar playbooks y roles de Ansible
- Gestionar secretos y variables de entorno
- Verificar conectividad SSH y servicios HTTP
- Depurar errores de despliegue

---

## Arquitectura del proyecto

### Diagrama de recursos

```
Azure Resource Group
├── Virtual Network (10.10.0.0/16)
│   └── Subnet (10.10.1.0/24)
├── Network Security Group
│   ├── Regla: SSH desde IP específica (puerto 22)
│   └── Regla: HTTP desde cualquier origen (puerto 80)
├── Public IP (Estática, Standard SKU)
├── Network Interface
└── Linux VM (Ubuntu 22.04 LTS)
    ├── Autenticación: SSH con clave pública
    └── Servicios: Nginx + página web personalizada
```

### Flujo de trabajo

```
1. terraform init    → Descarga providers de Azure
2. terraform plan    → Previsualiza cambios
3. terraform apply   → Crea recursos en Azure
4. generate-inventory → Extrae IP pública para Ansible
5. ansible-playbook  → Configura VM y despliega web
6. verify-deployment → Comprueba accesibilidad HTTP
```

---

## Requisitos previos

### Cuenta de Azure

- Suscripción activa (puede ser gratuita de estudiante)
- Permisos para crear recursos (Resource Groups, VMs, redes)

### Software necesario

| Herramienta | Versión mínima | Propósito |
|-------------|----------------|------------|
| Azure CLI | 2.50+ | Autenticación con Azure |
| Terraform | 1.5+ | Aprovisionamiento de infraestructura |
| Ansible | 2.14+ | Configuración de servidores |
| jq | 1.6+ | Procesamiento de JSON |
| SSH client | OpenSSH 8+ | Conexión a VM |

---

## Instalación de dependencias

### En Ubuntu/Debian

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Ansible
sudo apt install ansible jq
```

### En macOS

```bash
brew install azure-cli terraform ansible jq
```

### Verificación

```bash
az --version
terraform version
ansible --version
jq --version
```

---

## Configuración inicial

### 1. Autenticación en Azure

```bash
az login
az account show  # Verifica la suscripción activa
```

### 2. Generar clave SSH (si no tienes)

```bash
ssh-keygen -t rsa -b 4096 -C "tu@email.com" -f ~/.ssh/id_rsa
```

### 3. Configurar variables de Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edita `terraform/terraform.tfvars` con tus valores:

```hcl
resource_group_name = "rg-asr-lab-01"
location            = "westeurope"
prefix              = "asr"
vm_size             = "Standard_B1s"  # Tamaño económico
admin_username      = "azureuser"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
allowed_ssh_cidr    = "TU_IP/32"  # Cambia por tu IP pública
```

**⚠️ Importante**: Obtén tu IP pública con `curl ifconfig.me` y reemplaza `TU_IP`.

---

## Fase 1: Despliegue con Terraform

### Paso 1: Inicializar Terraform

```bash
./scripts/terraform-init.sh
```

**Qué hace:**
- Descarga el provider `azurerm`
- Crea directorio `.terraform/` con plugins
- Inicializa el backend local

### Paso 2: Revisar el plan de ejecución

```bash
./scripts/terraform-plan.sh
```

**Qué hace:**
- Compara estado actual vs código
- Muestra recursos a crear/modificar/destruir
- No realiza cambios reales

**Revisa la salida:**
- ✅ 8 recursos a crear (RG, VNet, Subnet, NSG, IP, NIC, VM, NSG association)
- ✅ 0 a modificar o destruir

### Paso 3: Aplicar cambios

```bash
./scripts/terraform-apply.sh
```

**Qué hace:**
- Crea recursos en Azure según el plan
- Guarda el estado en `terraform.tfstate`
- Muestra outputs (IP pública, nombre VM)

**Duración aproximada:** 3-5 minutos

**Captura de pantalla recomendada:**
- Output de `terraform apply` mostrando recursos creados
- Portal de Azure con el Resource Group y recursos

---

## Fase 2: Configuración con Ansible

### Paso 4: Generar inventario dinámico

```bash
./scripts/generate-inventory.sh
```

**Qué hace:**
- Extrae la IP pública de Terraform outputs
- Genera `ansible/inventories/generated/inventory.ini`

**Contenido generado:**

```ini
[webservers]
asr-vm01 ansible_host=X.X.X.X ansible_user=azureuser
```

### Paso 5: Verificar conectividad SSH

```bash
cd ansible
ansible webservers -m ping
```

**Salida esperada:**

```
asr-vm01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**Si falla:**
- Verifica que tu IP esté en `allowed_ssh_cidr`
- Comprueba que la clave SSH sea correcta
- Espera 1-2 minutos si la VM acaba de crearse

### Paso 6: Ejecutar playbook principal

```bash
./scripts/ansible-run.sh
```

**Qué hace:**
1. **Rol `common`**: Actualiza paquetes, configura firewall
2. **Rol `webserver`**: Instala Nginx, despliega página HTML personalizada

**Duración aproximada:** 2-3 minutos

**Captura de pantalla recomendada:**
- Output de Ansible mostrando tareas ejecutadas (CHANGED/OK)
- Sin fallos (0 failed)

---

## Verificación del despliegue

### Método 1: Script automático

```bash
./scripts/verify-deployment.sh
```

**Qué hace:**
- Obtiene la IP pública de Terraform
- Realiza petición HTTP
- Muestra título de la página

### Método 2: Navegador web

1. Obtén la IP pública:
   ```bash
   cd terraform
   terraform output public_ip
   ```

2. Abre en el navegador: `http://X.X.X.X`

**Deberías ver:** Página HTML con mensaje de bienvenida personalizado

### Método 3: SSH manual

```bash
cd terraform
ssh azureuser@$(terraform output -raw public_ip)
```

Dentro de la VM:

```bash
sudo systemctl status nginx
curl http://localhost
```

**Captura de pantalla recomendada:**
- Navegador mostrando la página web desplegada
- Output de `curl` con el HTML

---

## Gestión de costes

### Costes estimados (región West Europe)

| Recurso | SKU | Coste mensual aprox. |
|---------|-----|----------------------|
| VM Linux | Standard_B1s (1 vCPU, 1 GB RAM) | ~8 EUR |
| IP Pública | Standard (Estática) | ~3 EUR |
| Disco OS | Standard HDD 30 GB | ~1 EUR |
| **TOTAL** | | **~12 EUR/mes** |

**⚠️ Importante para laboratorios:**
- Destruye recursos al terminar la práctica
- Los recursos detenidos (stopped) siguen generando costes

### Limpieza completa

```bash
cd terraform
terraform destroy
```

**Qué hace:**
- Elimina todos los recursos de Azure
- Solicita confirmación antes de borrar
- Actualiza `terraform.tfstate`

**Duración aproximada:** 2-3 minutos

---

## Solución de problemas

### Error: "Subscription not found"

**Causa:** Azure CLI no está autenticado

**Solución:**
```bash
az login
az account set --subscription "NOMBRE_O_ID_SUSCRIPCION"
```

### Error: "SSH connection failed"

**Causa:** IP no permitida en NSG o clave incorrecta

**Solución:**
1. Verifica tu IP pública: `curl ifconfig.me`
2. Actualiza `terraform.tfvars` con `allowed_ssh_cidr = "TU_IP/32"`
3. Aplica cambios: `terraform apply`

### Error: "Resource quota exceeded"

**Causa:** Límite de vCPUs en la región

**Solución:**
- Cambia `location` a otra región (ej: `northeurope`)
- O solicita aumento de cuota en el portal de Azure

### Ansible no encuentra el inventario

**Causa:** El script `generate-inventory.sh` no se ejecutó

**Solución:**
```bash
./scripts/generate-inventory.sh
ls -la ansible/inventories/generated/
```

---

## Ampliaciones futuras

### Nivel básico

1. **Segunda VM**: Añade otra VM en el mismo VNet para practicar comunicación interna
2. **Variables personalizadas**: Cambia el mensaje de bienvenida usando variables de Ansible
3. **Monitoreo básico**: Instala `htop` y configura logs de Nginx

### Nivel intermedio

4. **Load Balancer**: Distribuye tráfico entre 2 VMs web
5. **HTTPS con Let's Encrypt**: Configura certificado SSL gratuito
6. **Backend remoto**: Almacena estado de Terraform en Azure Storage
7. **Ansible Vault**: Encripta variables sensibles

### Nivel avanzado

8. **Pipeline CI/CD**: Automatiza despliegue con GitHub Actions
9. **Terraform Modules**: Refactoriza código en módulos reutilizables
10. **Monitoreo avanzado**: Integra Azure Monitor y Log Analytics
11. **Multi-entorno**: Separa workspaces para dev/staging/prod
12. **Compliance**: Añade Azure Policy y escaneo con Checkov

---

## Recursos adicionales

### Documentación oficial

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Ansible Azure Guide](https://docs.ansible.com/ansible/latest/scenario_guides/guide_azure.html)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)

### Comandos útiles

```bash
# Listar recursos en el Resource Group
az resource list --resource-group rg-asr-lab-01 --output table

# Ver estado de Terraform en formato legible
cd terraform && terraform show

# Ejecutar solo un rol específico de Ansible
cd ansible && ansible-playbook playbooks/site.yml --tags webserver

# Ver outputs de Terraform sin ejecutar apply
cd terraform && terraform output
```

---

## Preguntas frecuentes

**¿Puedo usar otra distribución Linux?**

Sí, modifica el bloque `source_image_reference` en `terraform/main.tf`. Consulta imágenes disponibles:

```bash
az vm image list --output table
```

**¿Cómo cambio el tamaño de VM?**

Edita `vm_size` en `terraform.tfvars`. Tamaños recomendados para laboratorio:
- `Standard_B1s`: 1 vCPU, 1 GB RAM (más económico)
- `Standard_B2s`: 2 vCPU, 4 GB RAM (mejor rendimiento)

**¿Puedo desplegar en otra región?**

Sí, cambia `location` en `terraform.tfvars`. Regiones con buenos precios:
- `westeurope`, `northeurope` (Europa)
- `eastus`, `westus2` (EE.UU.)

**¿Necesito crear el Resource Group manualmente?**

No, Terraform lo crea automáticamente según `resource_group_name` en las variables.

---

## Conclusión

Esta plantilla proporciona una base sólida para entender el flujo completo de IaC en Azure. El enfoque manual de cada fase (en lugar de scripts todo-en-uno) permite visualizar y depurar cada paso.

**Próximos pasos sugeridos:**

1. Documenta capturas de pantalla de cada fase
2. Implementa al menos 2 ampliaciones de las sugeridas
3. Redacta el informe técnico explicando decisiones de diseño
4. Destruye recursos al terminar para evitar costes

**Recuerda:** La práctica deliberada con estas herramientas es clave para dominar DevOps e IaC. ¡Experimenta y aprende de los errores!
