// Pattern 1: Entra ID + Diagnostic Logs (APIM なし)
//
// Resource-group スコープのテンプレート。
// リソースグループとリージョンは `azd up` 実行時に対話的に選択 (or 既存利用) され、
// azd が `AZURE_RESOURCE_GROUP` / `AZURE_LOCATION` を環境変数として管理する。

@minLength(1)
@maxLength(64)
@description('azd 環境名。タグおよび一意名のソルトに利用する。')
param environmentName string

@description('"Cognitive Services OpenAI User" を付与するプリンシパルの Object ID。azd が実行ユーザーで設定する。')
param principalId string

@allowed([
  'User'
  'ServicePrincipal'
  'Group'
])
@description('ロール割り当てのプリンシパル種別。対話的な azd 実行では "User"。')
param principalType string = 'User'

@description('AOAI アカウントに作成する gpt-4o-mini デプロイの名前。')
param chatDeploymentName string = 'gpt-4o-mini'

@description('gpt-4o-mini デプロイの TPM 容量 (千単位)。')
param chatDeploymentCapacity int = 10

var tags = {
  'azd-env-name': environmentName
  pattern: 'pattern-1-entra-direct'
}

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName))

// リージョンは RG のものを使用 (azd が AZURE_LOCATION で RG 作成時に決定)。
var location = resourceGroup().location

// "Cognitive Services OpenAI User"
var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.15.1' = {
  name: 'logAnalytics-deploy'
  params: {
    name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
    skuName: 'PerGB2018'
  }
}

module openAi 'br/public:avm/res/cognitive-services/account:0.14.2' = {
  name: 'openAi-deploy'
  params: {
    name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    kind: 'OpenAI'
    sku: 'S0'
    customSubDomainName: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
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
    // NOTE: 診断設定は別リソースとして下に定義する。
    // AVM avm/res/cognitive-services/account v0.14.2 の `diagnosticSettings` パラメータは
    // `logAnalyticsDestinationType` フィールドを受け付けない（モジュール側未対応）。
    // 学習用の明示性のためにネイティブ `Microsoft.Insights/diagnosticSettings` を openAi に
    // 拡張リソースとして付ける（カテゴリを 1 件ずつ明示列挙したいため）。
    roleAssignments: [
      {
        principalId: principalId
        principalType: principalType
        roleDefinitionIdOrName: openAiUserRoleId
      }
    ]
  }
}

// AOAI の診断ログ / メトリクスを Log Analytics に送る。
//
// 実測ベースの注意点（README §5 / §6 参照）:
//   - AOAI には Cognitive Services 専用の resource-specific テーブル（AOAIRequestUsage 等）
//     は実在しない。`logAnalyticsDestinationType: 'Dedicated'` を指定しても、レコードは
//     すべて `AzureDiagnostics` テーブルに着地する。GET 時に当該フィールドが null で返って
//     くるのが正常で、AOAI に対しては事実上 **no-op** であるが、将来仕様変更に備え、また
//     他リソースとのテンプレ統一のため明示的に 'Dedicated' を残している。
//   - `RequestResponse` には callerObjectId は出るが prompt/completion トークン数は出ない
//     （`requestLength` / `responseLength` は bytes）。
//   - `AzureOpenAIRequestUsage` が両方を持つ唯一のカテゴリだが、本検証では明示 enable しても
//     emit されなかった。テナント / リージョン / 時期で挙動が安定しないため、本パターンは
//     「学習用」「per-user × per-token は構造的に不可」と README §6 で明記している。
//   - `AzureMetrics`（AllMetrics）はトークン数を持つが caller ディメンションが無い。
resource aoaiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
}

resource aoaiDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aoaiAccount
  name: 'to-log-analytics'
  properties: {
    workspaceId: logAnalytics.outputs.resourceId
    // AOAI に対しては事実上 no-op（上記コメント参照）。テンプレ統一目的で明示。
    logAnalyticsDestinationType: 'Dedicated'
    // 学習目的でカテゴリを 1 件ずつ明示列挙する（`allLogs` カテゴリグループでも結果は同等だが、
    // どのカテゴリを有効化したいか／していないかを Bicep 上で一目で見えるようにしておく）。
    // 注: `AzureOpenAIRequestUsage` は明示 enable しても本検証では emit されなかった。
    //     READMEで「期待した形では取れない」ことを伝えるためにも、設定上は有効にしておく。
    logs: [
      {
        category: 'Audit'
        enabled: true
      }
      {
        category: 'RequestResponse'
        enabled: true
      }
      {
        category: 'AzureOpenAIRequestUsage'
        enabled: true
      }
      {
        category: 'Trace'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: [
    openAi
  ]
}

// azd env get-values 経由でサンプルアプリから参照される出力
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_OPENAI_ENDPOINT string = openAi.outputs.endpoint
output AZURE_OPENAI_DEPLOYMENT string = chatDeploymentName
output LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.resourceId
output LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.outputs.name
