# Kubernetes Microservices on EKS

```
Dev -> GitHub Actions -> ECR -> helm upgrade -> EKS
Internet -> ALB Ingress -> users / orders pods -> RDS PostgreSQL
Pods /metrics -> Prometheus -> Grafana ; Pod logs -> Promtail -> Loki -> Grafana
```

## Deploy
1. `cd terraform && terraform init && terraform apply` (VPC, EKS with on-demand + spot node groups, ECR, RDS, Secrets Manager)
2. `$(terraform output -raw kubeconfig_cmd)`
3. Install the AWS Load Balancer Controller (see AWS docs) and a ClusterSecretStore named `aws-secrets` pointing at Secrets Manager (IRSA).
4. `./monitoring/install.sh`
5. Set `image.repository` ACCOUNT id in `helm/*/values.yaml`; add `AWS_ROLE_ARN` (GitHub OIDC role) as a repo secret; push to `main`.

## Verify
- `curl http://<alb>/users` / `/orders`; `kubectl scale deploy users --replicas=4`
- Failover: `kubectl delete pod -l app=users` and watch rollout
- Grafana: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`; queries in `monitoring/red-queries.md`

## Local test
`cd services/users && pip install -r requirements.txt && pytest`
