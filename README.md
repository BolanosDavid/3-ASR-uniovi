# 3-ASR-uniovi

Proyecto de automatización de infraestructura en Azure utilizando Terraform y Ansible.

## Descripción

Este proyecto implementa una solución de **Infraestructura como Código (IaC)** para desplegar y configurar automáticamente **3 máquinas virtuales Linux en Azure**.

La infraestructura se aprovisiona con **Terraform** y la configuración de los servidores se aplica con **Ansible**, permitiendo automatizar todo el proceso de despliegue, configuración y verificación. Adicionalmente, las máquinas están interconectadas mediante una **VPN WireGuard full-mesh** y disponen de un stack completo de observabilidad basado en **Prometheus, Grafana y Loki**, desplegado con **Docker Compose**.

## Componentes

- **Terraform**: aprovisionamiento de recursos en Azure
- **Ansible**: configuración automatizada de servicios
- **WireGuard**: VPN cifrada full-mesh entre las 3 VMs (red overlay `10.8.0.0/24`)
- **Docker + Docker Compose**: contenerización de los servicios de observabilidad
- **Prometheus + Grafana**: monitorización de métricas de red y sistema
- **Loki + Promtail**: agregación centralizada de logs del sistema
- **Azure CLI**: autenticación y acceso a la suscripción de Azure

## Recursos desplegados

- Resource Group
- Virtual Network con subnet compartida
- Network Security Group
  - SSH restringido al CIDR configurado
  - HTTP público
  - UDP 51820 público (WireGuard)
  - TCP 9090, 3000, 3100, 9100 restringidos a la red overlay WireGuard
- 3 máquinas virtuales Linux (**Ubuntu 22.04 LTS**)
- 3 IPs públicas estáticas
- 3 interfaces de red

## Arquitectura de red

Sobre la infraestructura Azure se levanta una red overlay WireGuard que cifra todo el tráfico interno entre las VMs:

| VM | IP privada (Azure) | IP overlay (WireGuard) | Servicios |
|---|---|---|---|
| vm-asr-01 | 10.0.1.10 | 10.8.0.1 | Nginx, Prometheus, Grafana, node_exporter |
| vm-asr-02 | 10.0.1.11 | 10.8.0.2 | Nginx, Promtail, node_exporter |
| vm-asr-03 | 10.0.1.12 | 10.8.0.3 | Nginx, Loki, Promtail, node_exporter |

Todo el tráfico de métricas y logs circula exclusivamente por el túnel WireGuard, nunca expuesto directamente a Internet.
## Requisitos

Antes de ejecutar el proyecto, asegúrate de tener instalado lo siguiente:

- **Azure CLI** con sesión iniciada (`az login`)
- **Terraform** >= 1.5
- **Ansible** >= 2.14
- **jq**
- **timeout**
- **ssh-keygen**
- Sistema Linux o entorno compatible (por ejemplo, **WSL**)
- **wireguard-tools** (`wg`) instalado en la máquina desde la que lanzas el despliegue

## Estructura general de ejecución

El proyecto se ejecuta mediante un único script principal que:

1. Genera una clave SSH RSA dedicada para el proyecto (si no existe).
2. Prepara el fichero `terraform.tfvars` si es necesario.
3. Actualiza la ruta de la clave pública en Terraform.
4. Inicializa y aplica Terraform.
5. Genera el inventario dinámico de Ansible (con asignación automática de IPs WireGuard).
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
3. Genera automáticamente un cliente local de WireGuard para el operador si no existe.
4. Actualiza `ssh_public_key_path` en `terraform.tfvars`.
5. Inicializa y aplica Terraform.
6. Genera el inventario de Ansible con las IPs WireGuard asignadas por orden de nombre.
7. Espera a que las máquinas virtuales acepten conexiones SSH.
8. Ejecuta el playbook principal de Ansible, añadiendo al operador como peer de WireGuard.
9. Genera el fichero cliente WireGuard listo para importar.
10. Verifica el despliegue final por HTTP.

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

Los hosts se ordenan alfabéticamente y se les asigna una IP WireGuard secuencial (`10.8.0.1`, `10.8.0.2`, `10.8.0.3`...). No es necesario editarlo manualmente.

## Acceso a los servicios de observabilidad

Los servicios de observabilidad son accesibles únicamente desde la red overlay WireGuard (`10.8.0.0/24`):

- **Grafana**: `http://10.8.0.1:3000`
- **Prometheus**: `http://10.8.0.1:9090`
- **Loki**: `http://10.8.0.3:3100`
## Acceso del operador a Grafana vía VPN

El script `./scripts/deploy-all.sh` genera automáticamente un cliente WireGuard local para el operador y lo añade como peer en todos los nodos.

Al finalizar, se genera un fichero de configuración listo para importar en:

```bash
ansible/inventories/generated/wireguard-client/operator.conf
```
Pasos: 
1. Ejecuta el despliegue (recuerda darle permisos de ejecución a los scripts):  

```bash
./scripts/deploy-all.sh
```
2. Importa el fichero operator.conf en tu cliente WireGuard.
3. Conecta la VPN.
4. Accede a Grafana en:
```bash
http://10.8.0.1:3000
```
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
- La asignación de IPs WireGuard es determinista por orden alfabético de nombre de VM. Si renombras o añades VMs, revisa que el orden sea el esperado en el inventario generado.

## Autores

* [Angela Nistal Guerrero @UO301919](https://github.com/AngelaNistal)
* [Sara Naredo Fernandez @UO300563](https://github.com/saranaredo)
* [David Fernando Bolaños Lopez @UO302313](https://github.com/BolanosDavid)