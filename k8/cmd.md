# Create resource group
az group create --name rg-dotnet-k8s-demo --location eastasia

# Create AKS cluster
az aks create --resource-group rg-dotnet-k8s-demo --name aks-dotnet-demo --node-count 2 --enable-addons monitoring --generate-ssh-keys

# Attach ACR to AKS (so pods can pull images)
az aks update --resource-group rg-dotnet-k8s-demo --name aks-dotnet-demo --attach-acr acrdemosourav

# Get AKS credentials locally
az aks get-credentials --resource-group rg-dotnet-k8s-demo --name aks-dotnet-demo

# Verify nodes
kubectl get nodes -o wide
# Build amd64 image (important for AKS compatibility)
docker buildx build --platform linux/amd64 -f .\docker\DemoApi.Dockerfile -t acrdemosourav.azurecr.io/demoapi:v1 --push .
# Apply manifests
kubectl apply -f k8/deployment.yaml
kubectl apply -f k8/service.yaml

# Restart deployment after pushing new image
kubectl rollout restart deployment demoapi-deployment
# Check pods
kubectl get pods

# Check service and get external IP
kubectl get service demoapi-service

# Test API endpoint
curl http://<EXTERNAL-IP>/weatherforecast
