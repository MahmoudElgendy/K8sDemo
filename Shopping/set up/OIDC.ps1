az login

# create a application registry and a service principal for the GitHub Actions workflow to use
$RESOURCE_GROUP = "geeks-rg"
$ACR_NAME = "geekscr"
$API_WEB_APP_NAME = "geeks-shopping-api"

$GITHUB_ORG = "MahmoudElgendy"
$GITHUB_REPO = "K8sDemo"

$APP_NAME = "github-k8sdemo-deployment"

$TENANT_ID = az account show --query tenantId --output tsv                         # 1
$SUBSCRIPTION_ID = az account show --query id --output tsv                         # 2
$APP_ID = az ad app create --display-name $APP_NAME --query appId --output tsv     # 3

az ad sp create --id $APP_ID

$SERVICE_PRINCIPAL_OBJECT_ID = az ad sp show --id $APP_ID --query id --output tsv


# Create federated credential for the service principal
# don't foreget to create the json file

az ad app federated-credential create --id $APP_ID --parameters federated-credential.json

$RESOURCE_GROUP_ID = az group show --name $RESOURCE_GROUP --query id --output tsv

$ACR_ID = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query id --output tsv

az role assignment create --assignee-object-id $SERVICE_PRINCIPAL_OBJECT_ID --assignee-principal-type ServicePrincipal --role "AcrPush" --scope $ACR_ID

az role assignment create --assignee-object-id $SERVICE_PRINCIPAL_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Contributor" --scope $RESOURCE_GROUP_ID

$WEB_APP_PRINCIPAL_ID = az webapp identity assign --name $API_WEB_APP_NAME --resource-group $RESOURCE_GROUP --query principalId --output tsv