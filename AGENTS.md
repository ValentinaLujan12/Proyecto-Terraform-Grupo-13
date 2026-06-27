# AGENTS.md — Documentación para herramientas de IA

Este documento describe la estructura y lógica del proyecto para que un agente
de IA pueda entenderlo, desplegarlo y validar su funcionamiento correctamente.

---

## Descripción general

El proyecto crea un Load Balancer HTTP global en GCP que distribuye el tráfico
entre dos servicios web alojados en VMs separadas. La proporción de tráfico hacia
cada servicio se controla con dos variables numéricas en `terraform.tfvars`.
Todo se despliega con `terraform apply` sin ninguna configuración manual posterior.

Los dos servicios son:
- Servicio Principal: muestra "Bienvenido al Servicio Principal - Versión Producción"
- Servicio de Contingencia: muestra "Error 503 - Sitio en Mantenimiento Programado"

---

## Archivos y su función

| Archivo | Descripción |
|---|---|
| `main.tf` | Configura el provider de Google y habilita la API de Compute Engine |
| `variables.tf` | Define todas las variables con tipos, valores por defecto y validaciones |
| `terraform.tfvars` | Valores activos de las variables, incluyendo los pesos de tráfico |
| `network.tf` | VPC personalizada y subred privada (10.10.0.0/24) |
| `firewall.tf` | Permite tráfico TCP:80 desde los rangos del health checker de GCP |
| `nat.tf` | Cloud Router y Cloud NAT para dar salida a internet a las VMs sin IP externa |
| `compute.tf` | Dos VMs (e2-micro, Debian 12) con startup script de nginx, y sus instance groups |
| `load_balancer.tf` | Health checks, backend services, URL map con pesos, proxy y forwarding rule |
| `outputs.tf` | Expone la IP pública del LB, zonas, IPs internas y el escenario activo |

---

## Variables de control de tráfico

El comportamiento del sistema depende exclusivamente de estas dos variables:

```hcl
main_traffic_weight = 100 # peso del Servicio Principal
contingency_traffic_weight = 0 # peso del Servicio de Contingencia
```

El porcentaje real de tráfico se calcula como `peso / (suma de pesos) * 100`.
Los tres escenarios de evaluación son:

| Escenario | main_traffic_weight | contingency_traffic_weight |
|---|---|---|
| Producción total | 100 | 0 |
| Mantenimiento total | 0 | 100 |
| Balanceo equitativo | 50 | 50 |

Ambas variables en 0 es inválido. El URL Map tiene un bloque `lifecycle.precondition`
que detiene el apply con un mensaje de error claro antes de intentar crear el recurso.

---

## Recursos creados (18 en total)

```
google_project_service.compute
google_compute_network.vpc
google_compute_subnetwork.subnet
google_compute_firewall.allow_lb_and_health_check
google_compute_router.nat_router
google_compute_router_nat.nat_config
google_compute_instance.main_service
google_compute_instance.contingency_service
google_compute_instance_group.main_group
google_compute_instance_group.contingency_group
google_compute_health_check.main_hc
google_compute_health_check.contingency_hc
google_compute_backend_service.main_backend
google_compute_backend_service.contingency_backend
google_compute_url_map.lb_url_map
google_compute_target_http_proxy.lb_http_proxy
google_compute_global_address.lb_ip
google_compute_global_forwarding_rule.lb_forwarding_rule
```

---

## Recurso clave: URL Map con distribución ponderada

El mecanismo central del proyecto es el bloque `default_route_action` en 
`google_compute_url_map`. GCP distribuye el tráfico entre backends proporcionalmente
a los pesos declarados:

```hcl
resource "google_compute_url_map" "lb_url_map" {
  default_route_action {
    weighted_backend_services {
      backend_service = google_compute_backend_service.main_backend.id
      weight = var.main_traffic_weight
    }
    weighted_backend_services {
      backend_service = google_compute_backend_service.contingency_backend.id
      weight = var.contingency_traffic_weight
    }
  }

  lifecycle {
    precondition {
      condition = (var.main_traffic_weight + var.contingency_traffic_weight) > 0
      error_message = "Al menos uno de los pesos debe ser mayor que cero."
    }
  }
}
```

Este recurso requiere que los backend services usen `load_balancing_scheme = "EXTERNAL_MANAGED"`.
El esquema clásico `EXTERNAL` no soporta `weighted_backend_services` en `default_route_action`.

---

## Decisiones de diseño relevantes

**VMs sin IP externa:** Las instancias no tienen `access_config` en su `network_interface`,
lo que significa que GCP no les asigna IP pública. Los usuarios no pueden acceder
directamente a las VMs, solo a través del Load Balancer.

**Cloud NAT:** Sin IP externa, las VMs tampoco pueden hacer conexiones salientes
a internet por defecto. El Cloud NAT en `nat.tf` les da esa salida para que el
startup script pueda ejecutar `apt-get install nginx`. Sin este recurso, nginx
nunca se instala y los health checks fallan indefinidamente.

**Zonas distintas:** La VM del Servicio Principal está en `us-central1-a` y la
del Servicio de Contingencia en `us-central1-b`. Esto garantiza aislamiento físico:
si una zona tiene un problema, la otra sigue operando.

**Startup script:** La configuración de nginx y el HTML de cada página se hace
enteramente a través del campo `metadata.startup-script` de las instancias. No
se usa SSH ni ninguna configuración posterior al despliegue.

---

## Procedimiento de validación

### Requisitos previos

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project PROJECT_ID
```

### Despliegue

```bash
# Editar terraform.tfvars y poner el project_id correcto antes de continuar
terraform init
terraform apply -auto-approve
```

### Obtener la IP del Load Balancer

```bash
terraform output load_balancer_ip
```

La IP también aparece en los outputs al final del apply. Para acceder al servicio,
abrir `http://<IP>` en un navegador. Esperar entre 3 y 5 minutos después del
apply para que el LB active los backends. Si responde 502, es normal durante
ese periodo de inicialización.

### Validar los tres escenarios

**Escenario 1 — Producción total:**

```bash
terraform apply -auto-approve -var="main_traffic_weight=100" -var="contingency_traffic_weight=0"
# Esperar 1-2 minutos
curl http://$(terraform output -raw load_balancer_ip)
# Debe contener: Bienvenido al Servicio Principal - Versión Producción
```

**Escenario 2 — Mantenimiento total:**

```bash
terraform apply -auto-approve -var="main_traffic_weight=0" -var="contingency_traffic_weight=100"
# Esperar 1-2 minutos
curl http://$(terraform output -raw load_balancer_ip)
# Debe contener: Error 503 - Sitio en Mantenimiento Programado
```

**Escenario 3 — Balanceo 50/50:**

```bash
terraform apply -auto-approve -var="main_traffic_weight=50" -var="contingency_traffic_weight=50"
# Esperar 1-2 minutos
IP=$(terraform output -raw load_balancer_ip)
for i in $(seq 1 10); do curl -s http://$IP | grep -o '<h1>[^<]*</h1>'; done
# Debe alternar entre los dos mensajes
```

### Destrucción

```bash
terraform destroy -auto-approve
# Debe terminar con: Destroy complete! Resources: 18 destroyed.
```

---