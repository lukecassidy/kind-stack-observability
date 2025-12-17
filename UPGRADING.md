# Upgrading Helm Charts

## Check for Updates

```bash
# Update Helm repositories
helm repo update

# Check available versions for a chart
helm search repo prometheus-community/prometheus --versions | head -5
helm search repo grafana/grafana --versions | head -5
helm search repo opensearch/opensearch --versions | head -5
```

## Upgrade Process

1. **Update version in helmfile.yaml**
   ```yaml
   - name: prometheus
     version: 27.51.0  # Update this version number
   ```

2. **Review release notes** for breaking changes at the chart repository

3. **Apply the upgrade**
   ```bash
   # Validate first
   make validate

   # Upgrade specific component
   helmfile -l name=prometheus apply

   # Or upgrade all
   make deploy
   ```

4. **Verify**
   ```bash
   make health-check
   kubectl get pods -n observability
   ```

## Rollback

If an upgrade fails:
```bash
helm rollback <release-name> -n <namespace>

# Example
helm rollback prometheus -n observability
```
