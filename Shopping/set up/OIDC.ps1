az login

# ============================================================
# Configuration
# ============================================================

$RESOURCE_GROUP = "geeks-rg"
$ACR_NAME = "geekscr"
$API_WEB_APP_NAME = "geeks-shopping-api"
$CLIENT_WEB_APP_NAME = "geeks-shopping-client"
$GITHUB_ORG = "MahmoudElgendy"
$GITHUB_REPO = "K8sDemo"
$APP_NAME = "github-k8sdemo-deployment"

# ============================================================
# Get Azure account information
# ============================================================

$TENANT_ID = az account show --query tenantId --output tsv
$SUBSCRIPTION_ID = az account show --query id --output tsv

# ============================================================
# Create Microsoft Entra application and service principal
# ============================================================

$APP_ID = az ad app create --display-name $APP_NAME --query appId --output tsv
az ad sp create --id $APP_ID
$SERVICE_PRINCIPAL_OBJECT_ID = az ad sp show --id $APP_ID --query id --output tsv
$KEY_VAULT_ID = az keyvault show --name geeks-kv-2026 --resource-group geeks-rg --query id --output tsv
# ============================================================
# Create GitHub OIDC federated credential
# ============================================================

az ad app federated-credential create --id $APP_ID --parameters federated-credential_api.json
az ad app federated-credential create --id $APP_ID --parameters federated-credential_client.json

# ============================================================
# Get Azure resource IDs
# ============================================================

$RESOURCE_GROUP_ID = az group show --name $RESOURCE_GROUP --query id --output tsv
$ACR_ID = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query id --output tsv
$API_WEB_APP_ID = az webapp show --name $API_WEB_APP_NAME --resource-group $RESOURCE_GROUP --query id --output tsv
$CLIENT_WEB_APP_ID = az webapp show --name $CLIENT_WEB_APP_NAME --resource-group $RESOURCE_GROUP --query id --output tsv

# ============================================================
# GitHub Actions permissions
# ============================================================

az role assignment create --assignee-object-id $SERVICE_PRINCIPAL_OBJECT_ID --assignee-principal-type ServicePrincipal --role "AcrPush" --scope $ACR_ID
az role assignment create --assignee-object-id $SERVICE_PRINCIPAL_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $KEY_VAULT_ID
az role assignment create --assignee-object-id $SERVICE_PRINCIPAL_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Website Contributor" --scope $API_WEB_APP_ID
az role assignment create --assignee-object-id $SERVICE_PRINCIPAL_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Website Contributor" --scope $CLIENT_WEB_APP_ID

# ============================================================
# Enable managed identities for the Web Apps
# ============================================================

$API_WEB_APP_PRINCIPAL_ID = az webapp identity assign --name $API_WEB_APP_NAME --resource-group $RESOURCE_GROUP --query principalId --output tsv
$CLIENT_WEB_APP_PRINCIPAL_ID = az webapp identity assign --name $CLIENT_WEB_APP_NAME --resource-group $RESOURCE_GROUP --query principalId --output tsv

# ============================================================
# Allow both Web Apps to pull images from ACR
# ============================================================

az role assignment create --assignee-object-id $API_WEB_APP_PRINCIPAL_ID --assignee-principal-type ServicePrincipal --role "AcrPull" --scope $ACR_ID
az role assignment create --assignee-object-id $CLIENT_WEB_APP_PRINCIPAL_ID --assignee-principal-type ServicePrincipal --role "AcrPull" --scope $ACR_ID

# ============================================================
# Display GitHub secret values
# =============================================================

Write-Host ""
Write-Host "Add these values to GitHub repository secrets:"
Write-Host "AZURE_CLIENT_ID=$APP_ID"
Write-Host "AZURE_TENANT_ID=$TENANT_ID"
Write-Host "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"


