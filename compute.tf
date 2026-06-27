# CÓMPUTO: VMs independientes para cada servicio

# Servicio Principal 
resource "google_compute_instance" "main_service" {
  name = "main-service-vm"
  machine_type = var.machine_type
  zone = var.zone_main
  description = "VM del Servicio Principal (producción). Sin IP externa."

  tags = ["web-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size = 10
      type = "pd-standard"
    }
  }

  network_interface {
    network = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
  }

  # Startup script: instala nginx y configura la página de producción.
  metadata = {
    startup-script = <<-STARTUP
      #!/bin/bash
      set -euo pipefail
      apt-get update -y
      apt-get install -y nginx
      cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Servicio Principal</title>
  <style>
    body { font-family: Arial, sans-serif; display:flex; justify-content:center;
           align-items:center; height:100vh; margin:0; background:#e8f5e9; }
    .box { text-align:center; padding:40px; background:#fff;
           border-radius:12px; box-shadow:0 4px 20px rgba(0,0,0,0.1); }
    h1 { color:#2e7d32; }
    p  { color:#555; }
  </style>
</head>
<body>
  <div class="box">
    <h1>Bienvenido al Servicio Principal - Versión Producción</h1>
    <p>Esta instancia opera en la zona: <strong>us-central1-a</strong></p>
  </div>
</body>
</html>
HTMLEOF
      systemctl enable nginx
      systemctl restart nginx
    STARTUP
  }

  # Permite que terraform destroy funcione sin errores
  allow_stopping_for_update = true

  depends_on = [google_project_service.compute]
}

# Servicio de Contingencia
resource "google_compute_instance" "contingency_service" {
  name = "contingency-service-vm"
  machine_type = var.machine_type
  zone = var.zone_contingency
  description = "VM del Servicio de Contingencia (mantenimiento). Sin IP externa."

  tags = ["web-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size = 10
      type = "pd-standard"
    }
  }

  network_interface {
    network = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
  }

  metadata = {
    startup-script = <<-STARTUP
      #!/bin/bash
      set -euo pipefail
      apt-get update -y
      apt-get install -y nginx
      cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>503 - Mantenimiento</title>
  <style>
    body { font-family: Arial, sans-serif; display:flex; justify-content:center;
           align-items:center; height:100vh; margin:0; background:#fff3e0; }
    .box { text-align:center; padding:40px; background:#fff;
           border-radius:12px; box-shadow:0 4px 20px rgba(0,0,0,0.1); }
    h1 { color:#e65100; }
    p  { color:#555; }
  </style>
</head>
<body>
  <div class="box">
    <h1>Error 503 - Sitio en Mantenimiento Programado</h1>
    <p>Esta instancia opera en la zona: <strong>us-central1-b</strong></p>
    <p>Estamos trabajando para restaurar el servicio. Intente más tarde.</p>
  </div>
</body>
</html>
HTMLEOF
      systemctl enable nginx
      systemctl restart nginx
    STARTUP
  }

  allow_stopping_for_update = true

  depends_on = [google_project_service.compute]
}

# INSTANCE GROUPS no administrados (uno por VM, en su zona)
# El LB referencia estos grupos como backends

resource "google_compute_instance_group" "main_group" {
  name = "main-instance-group"
  description = "Grupo de instancias para el Servicio Principal."
  zone = var.zone_main
  instances = [google_compute_instance.main_service.id]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_instance_group" "contingency_group" {
  name  = "contingency-instance-group"
  description = "Grupo de instancias para el Servicio de Contingencia."
  zone = var.zone_contingency
  instances = [google_compute_instance.contingency_service.id]

  named_port {
    name = "http"
    port = 80
  }
}
