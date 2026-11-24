# Grafana RED panels (PromQL)
- Rate:     `sum(rate(http_requests_total[1m])) by (job)`
- Errors:   `sum(rate(http_requests_total{status=~"5.."}[1m])) by (job)`
- Duration: `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, job))`
- Logs (Loki): `{app="orders"} |= "ERROR"`
