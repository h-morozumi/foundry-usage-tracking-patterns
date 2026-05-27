using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'aoai-track')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
param principalType = readEnvironmentVariable('AZURE_PRINCIPAL_TYPE', 'User')
param chatDeploymentName = readEnvironmentVariable('AZURE_OPENAI_DEPLOYMENT', 'gpt-4o-mini')
param chatDeploymentCapacity = int(readEnvironmentVariable('AZURE_OPENAI_CAPACITY', '10'))
