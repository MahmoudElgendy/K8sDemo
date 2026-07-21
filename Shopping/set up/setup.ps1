# ============================================================
# Shopping application Azure deployment script
# Run in PowerShell after:
#   az login
#   docker compose build
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

$RESOURCE_GROUP = "geeks-rg"
$LOCATION = "centralus"

$ACR_NAME = "geekscr"
$IMAGE_NAME_API = "shoppingapi"
$IMAGE_NAME_CLIENT = "shoppingclient"
$IMAGE_TAG = "1.0"

# These must match your local Docker image names
$LOCAL_IMAGE_API = "shopping-shopping.api"
$LOCAL_IMAGE_CLIENT = "shopping-shopping.client"

$KEYVAULT_NAME = "geeks-kv-2026"
$SECRET_NAME = "DefaultConnection"

$APP_SERVICE_PLAN = "geeks-plan"
$WEB_APP_NAME_API = "geeks-shopping-api"
$WEB_APP_NAME_CLIENT = "geeks-shopping-client"

$SQL_SERVER = "geeks-sql-server-2026"
$SQL_DB = "GeeksDb"
$SQL_ADMIN = "sqladmin"

# Use 80 only if both containers listen on port 80.
# Change this to 8080 if your Dockerfiles/apps listen on 8080.
$CONTAINER_PORT = "80"

# Do not hardcode the password in a committed script.
$SQL_PASSWORD = Read-Host "Enter the Azure SQL administrator password"

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Test-AzResource {
    param(
        [Parameter(Mandatory)]
        [string]$ResourceId
    )

    az resource show --ids $ResourceId --only-show-errors 1>$null 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Add-RoleAssignmentIfMissing {
    param(
        [Parameter(Mandatory)]
        [string]$AssigneeObjectId,

        [Parameter(Mandatory)]
        [string]$AssigneePrincipalType,

        [Parameter(Mandatory)]
        [string]$RoleName,

        [Parameter(Mandatory)]
        [string]$Scope
    )

    $existingAssignment = az role assignment list `
        --assignee-object-id $AssigneeObjectId `
        --scope $Scope `
        --query "[?roleDefinitionName=='$RoleName'].id | [0]" `
        --output tsv `
        --only-show-errors

    if ([string]::IsNullOrWhiteSpace($existingAssignment)) {
        Write-Host "Assigning role '$RoleName'..."

        az role assignment create `
            --assignee-object-id $AssigneeObjectId `
            --assignee-principal-type $AssigneePrincipalType `
            --role $RoleName `
            --scope $Scope `
            --only-show-errors

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to assign role '$RoleName'."
        }
    }
    else {
        Write-Host "Role '$RoleName' is already assigned."
    }
}

function Set-KeyVaultSecretWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$VaultName,

        [Parameter(Mandatory)]
        [string]$SecretName,

        [Parameter(Mandatory)]
        [string]$SecretValue,

        [int]$MaximumAttempts = 10,

        [int]$DelaySeconds = 20
    )

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        Write-Host "Creating Key Vault secret: attempt $attempt of $MaximumAttempts..."

        $secretUri = az keyvault secret set `
            --vault-name $VaultName `
            --name $SecretName `
            --value $SecretValue `
            --query id `
            --output tsv `
            --only-show-errors 2>$null

        if (($LASTEXITCODE -eq 0) -and -not [string]::IsNullOrWhiteSpace($secretUri)) {
            return $secretUri.Trim()
        }

        if ($attempt -lt $MaximumAttempts) {
            Write-Host "Key Vault permission may still be propagating. Retrying..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw "Failed to create the Key Vault secret after $MaximumAttempts attempts."
}

# ------------------------------------------------------------
# Validate Azure login
# ------------------------------------------------------------

Write-Host "`nChecking Azure login..."

$SUBSCRIPTION_ID = az account show --query id --output tsv --only-show-errors

if ([string]::IsNullOrWhiteSpace($SUBSCRIPTION_ID)) {
    throw "No active Azure login was found. Run: az login"
}

Write-Host "Subscription: $SUBSCRIPTION_ID"

# ------------------------------------------------------------
# Validate local Docker images
# ------------------------------------------------------------

Write-Host "`nChecking local Docker images..."

docker image inspect $LOCAL_IMAGE_API 1>$null 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Local image '$LOCAL_IMAGE_API' was not found. Build your Docker images first."
}

docker image inspect $LOCAL_IMAGE_CLIENT 1>$null 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Local image '$LOCAL_IMAGE_CLIENT' was not found. Build your Docker images first."
}

# ------------------------------------------------------------
# Create resource group
# ------------------------------------------------------------

Write-Host "`nCreating or updating resource group..."

az group create `
    --name $RESOURCE_GROUP `
    --location $LOCATION `
    --output none `
    --only-show-errors

# ------------------------------------------------------------
# Create Azure Container Registry
# ------------------------------------------------------------

Write-Host "`nChecking Azure Container Registry..."

$ACR_EXISTS = az acr show `
    --resource-group $RESOURCE_GROUP `
    --name $ACR_NAME `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($ACR_EXISTS)) {
    Write-Host "Creating Azure Container Registry..."

    az acr create `
        --resource-group $RESOURCE_GROUP `
        --name $ACR_NAME `
        --sku Basic `
        --location $LOCATION `
        --output none `
        --only-show-errors
}
else {
    Write-Host "Azure Container Registry already exists."
}

$ACR_LOGIN_SERVER = az acr show `
    --resource-group $RESOURCE_GROUP `
    --name $ACR_NAME `
    --query loginServer `
    --output tsv `
    --only-show-errors

$ACR_ID = az acr show `
    --resource-group $RESOURCE_GROUP `
    --name $ACR_NAME `
    --query id `
    --output tsv `
    --only-show-errors

if ([string]::IsNullOrWhiteSpace($ACR_ID)) {
    throw "Failed to retrieve the Azure Container Registry resource ID."
}

# ------------------------------------------------------------
# Sign in to ACR and push Docker images
# ------------------------------------------------------------

Write-Host "`nSigning in to Azure Container Registry..."

az acr login --name $ACR_NAME --only-show-errors

if ($LASTEXITCODE -ne 0) {
    throw "Failed to sign in to Azure Container Registry."
}

$API_IMAGE = "${ACR_LOGIN_SERVER}/${IMAGE_NAME_API}:${IMAGE_TAG}"
$CLIENT_IMAGE = "${ACR_LOGIN_SERVER}/${IMAGE_NAME_CLIENT}:${IMAGE_TAG}"

Write-Host "`nTagging and pushing API image..."

docker tag $LOCAL_IMAGE_API $API_IMAGE

if ($LASTEXITCODE -ne 0) {
    throw "Failed to tag the API Docker image."
}

docker push $API_IMAGE

if ($LASTEXITCODE -ne 0) {
    throw "Failed to push the API Docker image."
}

Write-Host "`nTagging and pushing client image..."

docker tag $LOCAL_IMAGE_CLIENT $CLIENT_IMAGE

if ($LASTEXITCODE -ne 0) {
    throw "Failed to tag the client Docker image."
}

docker push $CLIENT_IMAGE

if ($LASTEXITCODE -ne 0) {
    throw "Failed to push the client Docker image."
}

# ------------------------------------------------------------
# Create Linux App Service plan
# ------------------------------------------------------------

Write-Host "`nChecking App Service plan..."

$PLAN_EXISTS = az appservice plan show `
    --resource-group $RESOURCE_GROUP `
    --name $APP_SERVICE_PLAN `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($PLAN_EXISTS)) {
    Write-Host "Creating Linux App Service plan..."

    az appservice plan create `
        --resource-group $RESOURCE_GROUP `
        --name $APP_SERVICE_PLAN `
        --location $LOCATION `
        --sku B1 `
        --is-linux `
        --output none `
        --only-show-errors
}
else {
    Write-Host "App Service plan already exists."
}

# ------------------------------------------------------------
# Create API Web App
# ------------------------------------------------------------

Write-Host "`nChecking API Web App..."

$API_WEB_APP_EXISTS = az webapp show `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_API `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($API_WEB_APP_EXISTS)) {
    Write-Host "Creating API Web App..."

    az webapp create `
        --resource-group $RESOURCE_GROUP `
        --plan $APP_SERVICE_PLAN `
        --name $WEB_APP_NAME_API `
        --container-image-name $API_IMAGE `
        --output none `
        --only-show-errors
}
else {
    Write-Host "API Web App already exists."
}

# ------------------------------------------------------------
# Create client Web App
# ------------------------------------------------------------

Write-Host "`nChecking client Web App..."

$CLIENT_WEB_APP_EXISTS = az webapp show `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_CLIENT `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($CLIENT_WEB_APP_EXISTS)) {
    Write-Host "Creating client Web App..."

    az webapp create `
        --resource-group $RESOURCE_GROUP `
        --plan $APP_SERVICE_PLAN `
        --name $WEB_APP_NAME_CLIENT `
        --container-image-name $CLIENT_IMAGE `
        --output none `
        --only-show-errors
}
else {
    Write-Host "Client Web App already exists."
}

# ------------------------------------------------------------
# Enable system-assigned managed identities
# ------------------------------------------------------------

Write-Host "`nEnabling managed identities..."

$PRINCIPAL_ID_API = az webapp identity assign `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_API `
    --query principalId `
    --output tsv `
    --only-show-errors

$PRINCIPAL_ID_CLIENT = az webapp identity assign `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_CLIENT `
    --query principalId `
    --output tsv `
    --only-show-errors

if ([string]::IsNullOrWhiteSpace($PRINCIPAL_ID_API)) {
    throw "Failed to get the API Web App managed identity."
}

if ([string]::IsNullOrWhiteSpace($PRINCIPAL_ID_CLIENT)) {
    throw "Failed to get the client Web App managed identity."
}

# ------------------------------------------------------------
# Allow managed identities to pull images from ACR
# ------------------------------------------------------------

Write-Host "`nAssigning ACR pull permissions..."

Add-RoleAssignmentIfMissing `
    -AssigneeObjectId $PRINCIPAL_ID_API `
    -AssigneePrincipalType "ServicePrincipal" `
    -RoleName "AcrPull" `
    -Scope $ACR_ID

Add-RoleAssignmentIfMissing `
    -AssigneeObjectId $PRINCIPAL_ID_CLIENT `
    -AssigneePrincipalType "ServicePrincipal" `
    -RoleName "AcrPull" `
    -Scope $ACR_ID

Start-Sleep -Seconds 30
# Tell App Service to use its managed identity for ACR.
# In PowerShell, do not add backslashes before the JSON quotes.

$ACR_MANAGED_IDENTITY_CONFIG = @{
    acrUseManagedIdentityCreds = $true
} | ConvertTo-Json -Compress

az webapp config set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME_API --generic-configurations '{\"acrUseManagedIdentityCreds\":true}' --output none --only-show-errors

if ($LASTEXITCODE -ne 0) {
    throw "Failed to enable managed-identity ACR authentication for the API Web App."
}

az webapp config set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME_CLIENT --generic-configurations '{\"acrUseManagedIdentityCreds\":true}' --output none --only-show-errors

if ($LASTEXITCODE -ne 0) {
    throw "Failed to enable managed-identity ACR authentication for the client Web App."
}

# ------------------------------------------------------------
# Update container image configuration
# Useful when rerunning the script with a new tag
# ------------------------------------------------------------

Write-Host "`nUpdating Web App container images..."

az webapp config container set `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_API `
    --container-image-name $API_IMAGE `
    --output none `
    --only-show-errors

az webapp config container set `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_CLIENT `
    --container-image-name $CLIENT_IMAGE `
    --output none `
    --only-show-errors

# ------------------------------------------------------------
# Configure container ports
# ------------------------------------------------------------

Write-Host "`nConfiguring container ports..."

az webapp config appsettings set `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_API `
    --settings "WEBSITES_PORT=$CONTAINER_PORT" `
    --output none `
    --only-show-errors

az webapp config appsettings set `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_CLIENT `
    --settings "WEBSITES_PORT=$CONTAINER_PORT" `
    --output none `
    --only-show-errors

# ------------------------------------------------------------
# Create Azure SQL logical server
# ------------------------------------------------------------

Write-Host "`nChecking Azure SQL Server..."

$SQL_SERVER_EXISTS = az sql server show `
    --resource-group $RESOURCE_GROUP `
    --name $SQL_SERVER `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($SQL_SERVER_EXISTS)) {
    Write-Host "Creating Azure SQL Server..."

    az sql server create `
        --resource-group $RESOURCE_GROUP `
        --name $SQL_SERVER `
        --location $LOCATION `
        --admin-user $SQL_ADMIN `
        --admin-password $SQL_PASSWORD `
        --output none `
        --only-show-errors
}
else {
    Write-Host "Azure SQL Server already exists."
}

# ------------------------------------------------------------
# Allow Azure-hosted resources to access Azure SQL
# ------------------------------------------------------------

Write-Host "`nConfiguring Azure SQL firewall rule..."

$FIREWALL_RULE_EXISTS = az sql server firewall-rule show `
    --resource-group $RESOURCE_GROUP `
    --server $SQL_SERVER `
    --name AllowAzureServices `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($FIREWALL_RULE_EXISTS)) {
    az sql server firewall-rule create `
        --resource-group $RESOURCE_GROUP `
        --server $SQL_SERVER `
        --name AllowAzureServices `
        --start-ip-address 0.0.0.0 `
        --end-ip-address 0.0.0.0 `
        --output none `
        --only-show-errors
}
else {
    Write-Host "Azure SQL firewall rule already exists."
}

# ------------------------------------------------------------
# Create Azure SQL Database
# ------------------------------------------------------------

Write-Host "`nChecking Azure SQL Database..."

$SQL_DATABASE_EXISTS = az sql db show `
    --resource-group $RESOURCE_GROUP `
    --server $SQL_SERVER `
    --name $SQL_DB `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($SQL_DATABASE_EXISTS)) {
    Write-Host "Creating Azure SQL Database..."

    az sql db create `
        --resource-group $RESOURCE_GROUP `
        --server $SQL_SERVER `
        --name $SQL_DB `
        --service-objective Basic `
        --output none `
        --only-show-errors
}
else {
    Write-Host "Azure SQL Database already exists."
}

# ------------------------------------------------------------
# Create Key Vault with Azure RBAC
# ------------------------------------------------------------

Write-Host "`nChecking Azure Key Vault..."

$KEYVAULT_EXISTS = az keyvault show `
    --resource-group $RESOURCE_GROUP `
    --name $KEYVAULT_NAME `
    --query name `
    --output tsv `
    --only-show-errors 2>$null

if ([string]::IsNullOrWhiteSpace($KEYVAULT_EXISTS)) {
    Write-Host "Creating Azure Key Vault..."

    az keyvault create `
        --resource-group $RESOURCE_GROUP `
        --name $KEYVAULT_NAME `
        --location $LOCATION `
        --enable-rbac-authorization true `
        --output none `
        --only-show-errors
}
else {
    Write-Host "Azure Key Vault already exists."

    # Ensure the existing vault uses Azure RBAC.
    az keyvault update `
        --resource-group $RESOURCE_GROUP `
        --name $KEYVAULT_NAME `
        --enable-rbac-authorization true `
        --output none `
        --only-show-errors
}

$KEYVAULT_ID = az keyvault show `
    --resource-group $RESOURCE_GROUP `
    --name $KEYVAULT_NAME `
    --query id `
    --output tsv `
    --only-show-errors

if ([string]::IsNullOrWhiteSpace($KEYVAULT_ID)) {
    throw "Failed to get the Key Vault resource ID."
}

# ------------------------------------------------------------
# Allow signed-in user to create Key Vault secrets
# ------------------------------------------------------------

Write-Host "`nGetting signed-in user information..."

$SIGNED_IN_USER_ID = az ad signed-in-user show `
    --query id `
    --output tsv `
    --only-show-errors

if ([string]::IsNullOrWhiteSpace($SIGNED_IN_USER_ID)) {
    throw "Failed to retrieve the signed-in user's object ID."
}

Add-RoleAssignmentIfMissing `
    -AssigneeObjectId $SIGNED_IN_USER_ID `
    -AssigneePrincipalType "User" `
    -RoleName "Key Vault Secrets Officer" `
    -Scope $KEYVAULT_ID

# ------------------------------------------------------------
# Build and store SQL connection string
# ------------------------------------------------------------

$DB_CONNECTION_STRING = "Server=tcp:$SQL_SERVER.database.windows.net,1433;Initial Catalog=$SQL_DB;Persist Security Info=False;User ID=$SQL_ADMIN;Password=$SQL_PASSWORD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "`nStoring SQL connection string in Key Vault..."

$SECRET_URI = Set-KeyVaultSecretWithRetry `
    -VaultName $KEYVAULT_NAME `
    -SecretName $SECRET_NAME `
    -SecretValue $DB_CONNECTION_STRING

if ([string]::IsNullOrWhiteSpace($SECRET_URI)) {
    throw "Key Vault returned an empty secret URI."
}

Write-Host "Secret created successfully."

# ------------------------------------------------------------
# Allow API managed identity to read Key Vault secrets
# ------------------------------------------------------------

Add-RoleAssignmentIfMissing `
    -AssigneeObjectId $PRINCIPAL_ID_API `
    -AssigneePrincipalType "ServicePrincipal" `
    -RoleName "Key Vault Secrets User" `
    -Scope $KEYVAULT_ID

# App Service resolves Key Vault references using its managed
# identity. The Secrets User role provides secret read access.
# ------------------------------------------------------------

$KEY_VAULT_REFERENCE = "@Microsoft.KeyVault(SecretUri=$SECRET_URI)"

Write-Host "`nConfiguring the API connection string..."

$AZ_PYTHON = "C:\Program Files\Microsoft SDKs\Azure\CLI2\python.exe"

if (-not (Test-Path $AZ_PYTHON)) {
    throw "Azure CLI Python executable was not found at: $AZ_PYTHON"
}

& $AZ_PYTHON -IBm azure.cli `
    webapp config connection-string set `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_API `
    --connection-string-type SQLAzure `
    --settings "DefaultConnection=$KEY_VAULT_REFERENCE" `
    --output none `
    --only-show-errors

if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure the API connection string."
}

Write-Host "API connection string configured successfully."

# ------------------------------------------------------------
# Configure client API URL
# ------------------------------------------------------------

$API_BASE_URL = "https://$WEB_APP_NAME_API.azurewebsites.net"

Write-Host "`nConfiguring client API base URL: $API_BASE_URL"

az webapp config appsettings set `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_CLIENT `
    --settings "ApiSettings__BaseUrl=$API_BASE_URL" `
    --output none `
    --only-show-errors

# ------------------------------------------------------------
# Restart Web Apps
# ------------------------------------------------------------

Write-Host "`nRestarting Web Apps..."

az webapp restart `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_API `
    --only-show-errors

az webapp restart `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME_CLIENT `
    --only-show-errors

# ------------------------------------------------------------
# Deployment summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host "Deployment completed"
Write-Host "============================================================"
Write-Host "API URL:       https://$WEB_APP_NAME_API.azurewebsites.net"
Write-Host "Client URL:    https://$WEB_APP_NAME_CLIENT.azurewebsites.net"
Write-Host "ACR:           $ACR_LOGIN_SERVER"
Write-Host "SQL Server:    $SQL_SERVER.database.windows.net"
Write-Host "SQL Database:  $SQL_DB"
Write-Host "Key Vault:     https://$KEYVAULT_NAME.vault.azure.net/"
Write-Host "Secret name:   $SECRET_NAME"
Write-Host "============================================================"