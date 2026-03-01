# 3-ASR-uniovi

Proyecto de automatización de infraestructura en Azure utilizando Terraform y Ansible.

## Descripción

Implementación de infraestructura como código (IaC) que despliega y configura máquinas virtuales Linux en Azure.

**Componentes:**
- **Terraform**: Aprovisionamiento de recursos en Azure
- **Ansible**: Configuración automatizada de servicios

**Recursos desplegados:**
- Virtual Network con subnet
- Network Security Group (SSH restringido, HTTP público)
- Máquina virtual Linux (Ubuntu 22.04 LTS)
- IP pública estática

## Requisitos

- Azure CLI (sesión iniciada con `az login`)
- Terraform >= 1.5
- Ansible >= 2.14
- jq
- Clave SSH pública local

## Uso rápido

```bash
# 1. Configurar variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Editar terraform.tfvars con tus valores

# 2. Desplegar infraestructura
./scripts/terraform-init.sh
./scripts/terraform-apply.sh

# 3. Configurar servicios
./scripts/generate-inventory.sh
./scripts/ansible-run.sh

# 4. Verificar despliegue
./scripts/verify-deployment.sh
```


## Limpieza

```bash
cd terraform
terraform destroy
```

## Autores

* [Angela Nistal Guerrero @UO301919](https://github.com/AngelaNistal) 
* [Sara Naredo Fernandez @UO300563](https://github.com/saranaredo)
* [David Fernando Bolaños Lopez @UO302313](https://github.com/BolanosDavid)