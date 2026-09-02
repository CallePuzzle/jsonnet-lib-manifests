local k = import 'k.libsonnet';

local secret = k.core.v1.secret;

{
  values:: {
    name: error 'name is required',
    namespace: error 'namespace is required',
    stringData: error 'stringData is required',
    syncWave: '10',
  },
  secret: secret.new($.values.name, {}) +
          secret.withStringData($.values.stringData) +
          secret.metadata.withNamespace($.values.namespace) +
          secret.metadata.withAnnotations({
            'argocd.argoproj.io/sync-wave': $.values.syncWave,
          }),
}
