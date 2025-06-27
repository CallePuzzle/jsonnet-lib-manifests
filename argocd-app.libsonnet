{
  values:: {
    name: error 'name is required',
    namespace: 'argocd',
    projectName: error 'projectName is required',
    path: 'manifests',
    destinationNamespace: error 'destinationNamespace is required',
    environment: error 'environment is required',
    repoURL: error 'repoURL is required',
    targetRevision: 'master',
    autoSync: true,
    createNamespace: true,
  },

  local autoSync = if $.values.autoSync then {
    syncPolicy: {
      automated: { prune: true },
    },
  } else {},

  local createNamespace = if $.values.createNamespace then {
    syncPolicy+: {
      syncOptions+: [
        'CreateNamespace=true',
      ],
    },
  } else {},

  apiVersion: 'argoproj.io/v1alpha1',
  kind: 'Application',
  metadata: {
    name: $.values.name + '-' + $.values.projectName,
    namespace: $.values.namespace,
  },
  spec: {
    destination: {
      namespace: $.values.destinationNamespace,
      server: 'https://kubernetes.default.svc',
    },
    project: $.values.projectName,
    source: {
      path: $.values.path,
      plugin: {
        env: [
          {
            name: 'ENVIRONMENT',
            value: $.values.environment,
          },
        ],
        name: 'tanka-sops',
      },
      repoURL: $.values.repoURL,
      targetRevision: $.values.targetRevision,
    },
  } + autoSync + createNamespace,
}
