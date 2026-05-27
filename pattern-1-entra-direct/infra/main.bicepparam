using './main.bicep'

// location は main.bicep 側で resourceGroup().location を使用するため、ここでは渡さない。
param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'aoai-track')
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
param principalType = readEnvironmentVariable('AZURE_PRINCIPAL_TYPE', 'User')
param chatDeploymentName = readEnvironmentVariable('AZURE_OPENAI_DEPLOYMENT', 'gpt-4o-mini')
param chatDeploymentCapacity = int(readEnvironmentVariable('AZURE_OPENAI_CAPACITY', '10'))
