# OUTPUTS

locals {
  total_weight = var.main_traffic_weight + var.contingency_traffic_weight
  pct_main = local.total_weight > 0 ? floor(var.main_traffic_weight * 100 / local.total_weight) : 0
  pct_cont = local.total_weight > 0 ? ceil(var.contingency_traffic_weight * 100 / local.total_weight) : 0
}

output "load_balancer_ip" {
  description = "IP pública del Load Balancer. Acceder desde el navegador: http://<ip>"
  value = google_compute_global_address.lb_ip.address
}

output "escenario_activo" {
  description = "Resumen de la distribución de tráfico configurada actualmente."
  value = local.total_weight > 0 ? format(
    "Servicio Principal: %d%% | Servicio de Contingencia: %d%%",
    local.pct_main,
    local.pct_cont
  ) : "CONFIGURACIÓN INVÁLIDA: ambos pesos son 0. El apply fallará."
}

output "main_service_zone" {
  description = "Zona de la VM del Servicio Principal."
  value = google_compute_instance.main_service.zone
}

output "contingency_service_zone" {
  description = "Zona de la VM del Servicio de Contingencia."
  value = google_compute_instance.contingency_service.zone
}

output "main_service_internal_ip" {
  description = "IP interna de la VM del Servicio Principal (no accesible desde internet)."
  value = google_compute_instance.main_service.network_interface[0].network_ip
}

output "contingency_service_internal_ip" {
  description = "IP interna de la VM del Servicio de Contingencia (no accesible desde internet)."
  value = google_compute_instance.contingency_service.network_interface[0].network_ip
}
