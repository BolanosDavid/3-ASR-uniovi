# 3-ASR-uniovi

Proyecto de automatización de infraestructura en Azure utilizando Terraform y Ansible.

## Descripción

Este proyecto implementa una solución de **Infraestructura como Código (IaC)** para desplegar y configurar automáticamente **3 máquinas virtuales Linux en Azure**.

La infraestructura se aprovisiona con **Terraform** y la configuración de los servidores se aplica con **Ansible**, permitiendo automatizar todo el proceso de despliegue, configuración y verificación.

## Componentes

- **Terraform**: aprovisionamiento de recursos en Azure
- **Ansible**: configuración automatizada de servicios
- **Azure CLI**: autenticación y acceso a la suscripción de Azure

## Recursos desplegados

- Resource Group
- Virtual Network con subnet compartida
- Network Security Group
    - SSH restringido al CIDR configurado
    - HTTP público
- 3 máquinas virtuales Linux (**Ubuntu 22.04 LTS**)
- 3 IPs públicas estáticas
- 3 interfaces de red

## Requisitos

Antes de ejecutar el proyecto, asegúrate de tener instalado lo siguiente:

- **Azure CLI** con sesión iniciada (`az login`)
- **Terraform** >= 1.5
- **Ansible** >= 2.14
- **jq**
- **timeout**
- **ssh-keygen**
- Sistema Linux o entorno compatible (por ejemplo, **WSL**)

## Estructura general de ejecución

El proyecto se ejecuta mediante un único script principal que:

1. Genera una clave SSH RSA dedicada para el proyecto (si no existe).
2. Prepara el fichero `terraform.tfvars` si es necesario.
3. Actualiza la ruta de la clave pública en Terraform.
4. Inicializa y aplica Terraform.
5. Genera el inventario dinámico de Ansible.
6. Espera a que las máquinas virtuales acepten conexiones SSH.
7. Ejecuta el playbook principal de Ansible.
8. Verifica el despliegue final por HTTP.

## Configuración inicial

Si es la primera vez que ejecutas el proyecto, crea tu fichero de variables a partir del ejemplo:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Después, revisa y ajusta manualmente los valores necesarios en:

```bash
terraform/terraform.tfvars
```

> Importante: el script de despliegue **no modifica** `allowed_ssh_cidr`. Ese valor debe estar correctamente configurado en `terraform.tfvars`.

## Despliegue completo

Desde la raíz del proyecto:

```bash
./scripts/deploy-all.sh
```

Este script realiza automáticamente todo el flujo:

1. Comprueba dependencias.
2. Genera una clave SSH RSA dedicada para el proyecto si no existe.
3. Actualiza `ssh_public_key_path` en `terraform.tfvars`.
4. Inicializa y aplica Terraform.
5. Genera el inventario de Ansible.
6. Espera a que las máquinas virtuales acepten conexiones SSH.
7. Ejecuta el playbook principal de Ansible.
8. Verifica el despliegue final por HTTP.

## Claves SSH

Por defecto, el script utiliza una clave RSA dedicada en:

```bash
~/.ssh/asr_azure_rsa
~/.ssh/asr_azure_rsa.pub
```

Si quieres usar otro nombre de clave:

```bash
ASR_KEY_NAME=mi_clave_asr ./scripts/deploy-all.sh
```

## Ejecución de Ansible con otra clave

El script de Ansible también permite sobrescribir la clave privada manualmente mediante variable de entorno:

```bash
ANSIBLE_PRIVATE_KEY_FILE="$HOME/.ssh/mi_otra_clave_rsa" ./scripts/ansible-run.sh
```

## Inventario generado

El inventario de Ansible se genera automáticamente en:

```bash
ansible/inventories/generated/inventory.ini
```

No es necesario editarlo manualmente.

## Verificación del despliegue

Si quieres repetir solo la comprobación final:

```bash
./scripts/verify-deployment.sh
```

## Limpieza

Para destruir toda la infraestructura desplegada:

```bash
./scripts/destroy-all.sh
```

Si quieres destruir la infraestructura **sin eliminar** el inventario generado:

```bash
CLEAN_INVENTORY=0 ./scripts/destroy-all.sh
```

## Notas importantes

- El proyecto utiliza claves **RSA**, ya que la configuración actual de `azurerm_linux_virtual_machine` espera este formato para `admin_ssh_key.public_key`.
- Si cambias la clave SSH después de haber creado las máquinas virtuales, puede ser necesario destruir y volver a desplegar la infraestructura.
- Si cambias de red o de IP pública, revisa manualmente el valor de `allowed_ssh_cidr` en `terraform.tfvars`.

## Autores

* [Angela Nistal Guerrero @UO301919](https://github.com/AngelaNistal)
* [Sara Naredo Fernandez @UO300563](https://github.com/saranaredo)
* [David Fernando Bolaños Lopez @UO302313](https://github.com/BolanosDavid)
