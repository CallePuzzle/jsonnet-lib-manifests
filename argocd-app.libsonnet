{
  values:: {
    name: error 'name is required',
    namespace: 'argocd',
    projectName: error 'projectName is required',
    path: null,
    destinationNamespace: error 'destinationNamespace is required',
    repoURL: error 'repoURL is required',
    targetRevision: 'HEAD',
    chart: if self.path == null && self.plugin == null then error 'chart is required' else null,
    chartReleaseName: '',
    chartValues: null,
    plugin: null,
    autoSync: true,
    selfHeal: true,
    createNamespace: true,
  },

  local _validateSource =
    if $.values.path != null && $.values.chart != null then
      error 'argocd-app: path and chart are mutually exclusive'
    else if $.values.path != null && $.values.plugin != null then
      error 'argocd-app: path and plugin are mutually exclusive'
    else if $.values.plugin != null && $.values.chart != null then
      error 'argocd-app: plugin and chart are mutually exclusive'
    else {},

  local _source =
    {
      repoURL: $.values.repoURL,
      targetRevision: $.values.targetRevision,
    }
    + (if $.values.path != null then { path: $.values.path } else {})
    + (if $.values.chart != null then { chart: $.values.chart } else {})
    + (if $.values.plugin != null then { plugin: $.values.plugin } else {})
    + (if $.values.chartValues != null then {
         helm: {
           // Strip trailing spaces before line-breaks so tk diff stays clean.
           values: std.native('regexSubst')('(?m)[ ]+$', $.values.chartValues, ''),
         },
       } else {})
    + (if $.values.chartReleaseName != '' then { releaseName: $.values.chartReleaseName } else {}),

  local _autoSync = if $.values.autoSync then {
    syncPolicy: {
      automated: { prune: true, selfHeal: $.values.selfHeal },
    },
  } else {},

  local _createNamespace = if $.values.createNamespace then {
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
    source: _source,
  } + _autoSync + _createNamespace + _validateSource,
}
