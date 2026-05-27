// Pattern 1: Entra ID + Diagnostic Logs (no APIM)
// Subscription-scope entry. Creates the resource group and delegates resource
// authoring to resources.bicep.

targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment, used to derive resource group / resource names. Provided by azd.')
param environmentName string

@minLength(1)
@description('Azure region for all resources.')
param location string

@description('Object ID of the user (or service principal) that will be granted "Cognitive Services OpenAI User" on the AOAI account. Defaulted from azd as the deploying principal.')
param principalId string

@allowed([
  'User'
  'ServicePrincipal'
  'Group'
])
@description('Principal type for the role assignment. Use "User" for interactive azd deployments.')
param principalType string = 'User'

@description('Name of the gpt-4o-mini deployment created on the AOAI account.')
param chatDeploymentName string = 'gpt-4o-mini'

@description('TPM capacity (in thousands) for the gpt-4o-mini deployment.')
param chatDeploymentCapacity int = 10

var tags = {
  'azd-env-name': environmentName
  pattern: 'pattern-1-entra-direct'
}

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module resources './resources.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    abbrs: abbrs
    principalId: principalId
    principalType: principalType
    chatDeploymentName: chatDeploymentName
    chatDeploymentCapacity: chatDeploymentCapacity
  }
}

// Outputs consumed by the sample app via azd env get-values
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_OPENAI_ENDPOINT string = resources.outputs.openAiEndpoint
output AZURE_OPENAI_DEPLOYMENT string = chatDeploymentName
output AZURE_OPENAI_API_VERSION string = '2024-10-21'
output LOG_ANALYTICS_WORKSPACE_ID string = resources.outputs.logAnalyticsWorkspaceId
output LOG_ANALYTICS_WORKSPACE_NAME string = resources.outputs.logAnalyticsWorkspaceName
