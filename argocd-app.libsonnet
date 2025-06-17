{
  values:: {
    name: error 'name is required',
    projectName: error 'projectName is required',
    destinationNamespace: error 'destinationNamespace is required',
    environment: error 'environment is required',
    repoURL: error 'repoURL is required',
    targetRevision: 'master',
    autoSync: true,
    ignoreReplicas: true,
  },

  local autoSync = if $.values.autoSync then {
    syncPolicy: {
      automated: { prune: true },
    },
  } else {},

  local ignoreReplicas = if $.values.ignoreReplicas then {
    ignoreDifferences: [
      {
        group: 'apps',
        kind: 'Deployment',
        jsonPointers: [
          '/spec/replicas',
        ],
      },
    ],
    syncPolicy+: {
      syncOptions+: [
        'RespectIgnoreDifferences=true',
      ],
    },
  } else {},

  apiVersion: 'argoproj.io/v1alpha1',
  kind: 'Application',
  metadata: {
    name: $.values.name + '-' + $.values.projectName,
    namespace: 'argocd',
  },
  spec: {
    destination: {
      namespace: $.values.destinationNamespace,
      server: 'https://kubernetes.default.svc',
    },
    project: $.values.projectName,
    source: {
      path: '.',
      plugin: {
        env: [
          {
            name: 'ENVIRONMENT',
            value: $.values.environment + '/' + $.values.name,
          },
        ],
        name: 'tanka',
      },
      repoURL: $.values.repoURL,
      targetRevision: $.values.targetRevision,
    },
  } + autoSync + ignoreReplicas,
}
