// Pattern 1: Resource-group-scoped resources
// - Azure OpenAI (kind=OpenAI) with gpt-4o-mini deployment
// - Log Analytics workspace
// - Diagnostic Settings on AOAI -> Log Analytics (Audit + RequestResponse + AllMetrics)
// - Role assignment: principalId gets "Cognitive Services OpenAI User" on AOAI

@description('Azure region for all resources.')
param location string

@description('Tags applied to all resources.')
param tags object

@description('Short token used to make resource names unique within a region/subscription.')
param resourceToken string

@description('Resource name abbreviations loaded from abbreviations.json.')
param abbrs object

@description('Principal that receives the Cognitive Services OpenAI User role on the AOAI account.')
param principalId string

@allowed([
  'User'
  'ServicePrincipal'
  'Group'
])
param principalType string

param chatDeploymentName string
param chatDeploymentCapacity int

// "Cognitive Services OpenAI User" role definition GUID
// https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/ai-machine-learning#cognitive-services-openai-user
var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.15.1' = {
  params: {
    name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
    skuName: 'PerGB2018'
  }
}

module openAi 'br/public:avm/res/cognitive-services/account:0.14.2' = {
  params: {
    name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    kind: 'OpenAI'
    sku: 'S0'
    // customSubDomainName is required for Entra ID token-based auth
    customSubDomainName: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    // Force Entra-only auth so that per-user attribution is reliable.
    // (disableLocalAuth=true is also the AVM default.)
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    deployments: [
      {
        name: chatDeploymentName
        model: {
          format: 'OpenAI'
          name: 'gpt-4o-mini'
          version: '2024-07-18'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: chatDeploymentCapacity
        }
      }
    ]
    diagnosticSettings: [
      {
        name: 'to-log-analytics'
        workspaceResourceId: logAnalytics.outputs.resourceId
        logCategoriesAndGroups: [
          {
            category: 'Audit'
          }
          {
            category: 'RequestResponse'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]
    roleAssignments: [
      {
        principalId: principalId
        principalType: principalType
        roleDefinitionIdOrName: openAiUserRoleId
      }
    ]
  }
}

output openAiEndpoint string = openAi.outputs.endpoint
output openAiResourceId string = openAi.outputs.resourceId
output logAnalyticsWorkspaceId string = logAnalytics.outputs.resourceId
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
