# Node Cahaya CLI LayerEdge

Terapkan node lampu LayerEdge CLI ke sistem Ubuntu dengan satu klik

## Fitur
- Secara otomatis menginstal Go/Rust dan dependensi kompilasi lainnya
- Konfigurasikan lingkungan bukti tanpa pengetahuan Risc0
- Menyebarkan layanan verifikasi Merkle
- Menyediakan skrip manajemen node (tampilan mulai/berhenti/status)
- Koneksi Dasbor LayerEdge Terintegrasi

## System Requirements
- Ubuntu 20.04/22.04 LTS
- 4-core CPU / 8GB RAM / 50GB storage

## Quick Installation
```bash
# Single command installation
curl -sL https://raw.githubusercontent.com/fishzone24/layeredge-CLI/refs/heads/master/install_layeredge.sh | sudo bash

# Alternative step-by-step installation (if needed):
# wget https://raw.githubusercontent.com/fishzone24/layeredge-CLI/refs/heads/master/install_layeredge.sh
# chmod +x install_layeredge.sh
# sudo ./install_layeredge.sh
```
## Instructions
After installation:
1. Edit the .env file to configure the private key
```nano .env```
2. Use the management script:
- Check the status ```./status_layeredge.sh```
- Stop the service ```./stop_layeredge.sh```
- Restart the service ```./restart_layeredge.sh```

## Security Tips
⚠️ Please keep the PRIVATE_KEY configuration properly
⚠️ It is recommended to open port 3001 (TCP) in the firewall

## Technical Support
Visit [LayerEdge Dashboard](https://dashboard.layeredge.io) to view the node status
