{
  values:: {
    name: error 'name is required',
    namespace: 'argocd',
    projectName: error 'projectName is required',
    path: null,
    destinationNamespace: error 'destinationNamespace is required',
    repoURL: error 'repoURL is required',
    targetRevision: 'master',
    chart: if self.path == null then error 'chart is required',
    chartReleaseName: '',
    chartValues: null,
    plugin: null,
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
      plugin: $.values.plugin,
      repoURL: $.values.repoURL,
      targetRevision: $.values.targetRevision,
      chart: $.values.chart,
    } + if $.values.chartValues != null then { helm: {
      //This regex filter spaces before line-break's, so tkdiff shows a correct diff
      values: std.native('regexSubst')('(?m)[ ]+$', $.values.chartValues, ''),
    } } else {} + if $.values.chartReleaseName != '' then { releaseName: $.values.chartReleaseName } else {},
  } + autoSync + createNamespace,
}
