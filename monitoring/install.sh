#!/usr/bin/env bash
set -euo pipefail
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/prometheus-values.yaml
helm upgrade --install loki grafana/loki-stack -n monitoring \
  --set promtail.enabled=true --set grafana.enabled=false
helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
kubectl apply -f monitoring/alerts.yaml
