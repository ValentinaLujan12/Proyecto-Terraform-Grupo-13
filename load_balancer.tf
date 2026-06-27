# LOAD BALANCER GLOBAL HTTP — 

# Health Checks
resource "google_compute_health_check" "main_hc" {
  name = "main-health-check"
  description = "Health check para el Servicio Principal."
  check_interval_sec = 10
  timeout_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 3

  http_health_check {
    port = 80
    request_path = "/"
  }
}

resource "google_compute_health_check" "contingency_hc" {
  name = "contingency-health-check"
  description = "Health check para el Servicio de Contingencia."
  check_interval_sec = 10
  timeout_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 3

  http_health_check {
    port = 80
    request_path = "/"
  }
}

# Backend Services 
# EXTERNAL_MANAGED para usar weighted_backend_services en el URL Map. 

resource "google_compute_backend_service" "main_backend" {
  name = "main-backend-service"
  description = "Backend del Servicio Principal."
  port_name = "http"
  protocol = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks = [google_compute_health_check.main_hc.id]
  session_affinity = "NONE"

  backend {
    group = google_compute_instance_group.main_group.id
    balancing_mode = "RATE"
    max_rate_per_instance = 100
  }
}

resource "google_compute_backend_service" "contingency_backend" {
  name = "contingency-backend-service"
  description = "Backend del Servicio de Contingencia."
  port_name = "http"
  protocol = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks = [google_compute_health_check.contingency_hc.id]
  session_affinity = "NONE"

  backend {
    group = google_compute_instance_group.contingency_group.id
    balancing_mode = "RATE"
    max_rate_per_instance = 100
  }
}

# URL Map con distribución ponderada de tráfico
# Pesos definidos en variables.tf (main_traffic_weight / contingency_traffic_weight).

resource "google_compute_url_map" "lb_url_map" {
  name = "lb-url-map"
  description = "URL Map con distribución de tráfico ponderada entre main y contingency."

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

  # Validación: GCP rechaza un URL Map donde AMBOS pesos sean 0.
  lifecycle {
    precondition {
      condition = (var.main_traffic_weight + var.contingency_traffic_weight) > 0
      error_message = "ERROR: main_traffic_weight y contingency_traffic_weight no pueden ser ambos 0. Al menos uno debe ser mayor que cero."
    }
  }
}

# Target HTTP Proxy
resource "google_compute_target_http_proxy" "lb_http_proxy" {
  name = "lb-http-proxy"
  description = "Proxy HTTP que conecta la IP pública con el URL Map."
  url_map = google_compute_url_map.lb_url_map.id
}

# Global Forwarding Rule (Punto de Entrada Único) 
resource "google_compute_global_address" "lb_ip" {
  name = "lb-global-ip"
  description = "IP pública global y única para el punto de entrada del LB."
}

resource "google_compute_global_forwarding_rule" "lb_forwarding_rule" {
  name = "lb-forwarding-rule"
  description = "Forwarding rule que expone la IP global en el puerto 80."
  target = google_compute_target_http_proxy.lb_http_proxy.id
  ip_address = google_compute_global_address.lb_ip.id
  port_range = "80"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
