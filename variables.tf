# VARIABLES DE PROYECTO

variable "project_id" {
  description = "ID del proyecto de GCP donde se desplegará la infraestructura."
  type = string
}

variable "region" {
  description = "Región de GCP donde se crearán los recursos regionales (subred)."
  type = string
  default = "us-central1"
}

# ZONAS DE CÓMPUTO

variable "zone_main" {
  description = "Zona de GCP para la VM del Servicio Principal."
  type = string
  default = "us-central1-a"
}

variable "zone_contingency" {
  description = "Zona de GCP para la VM del Servicio de Contingencia."
  type = string
  default = "us-central1-b"
}

# TAMAÑO DE LAS VMs

variable "machine_type" {
  description = "Tipo de máquina para ambas instancias. Se usa e2-micro para minimizar costos."
  type = string
  default = "e2-micro"
}

# CONTROL DE TRÁFICO  
#  Escenario 1 – Producción total  : main=100, contingency=0
#  Escenario 2 – Mantenimiento total: main=0,   contingency=100
#  Escenario 3 – Balanceo 50/50    : main=50,   contingency=50

variable "main_traffic_weight" {
  description = "Peso de tráfico para el Servicio Principal (0 = sin tráfico, >0 = activo)."
  type = number
  default = 100

  validation {
    condition = var.main_traffic_weight >= 0 && var.main_traffic_weight <= 1000
    error_message = "El peso debe estar entre 0 y 1000."
  }
}

variable "contingency_traffic_weight" {
  description = "Peso de tráfico para el Servicio de Contingencia (0 = sin tráfico, >0 = activo)."
  type = number
  default = 0

  validation {
    condition = var.contingency_traffic_weight >= 0 && var.contingency_traffic_weight <= 1000
    error_message = "El peso debe estar entre 0 y 1000."
  }
}
