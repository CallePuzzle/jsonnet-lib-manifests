local k = import 'k.libsonnet';

local secret = k.core.v1.secret;

{
  values:: {
    name: error 'name is required',
    namespace: error 'namespace is required',
    repositoryUrl: error 'repositoryUrl is required',
    password: null,
    username: null,
    sshPrivateKey: null,
  },
  local stringData = if $.values.password != null && $.values.username != null then
    {
      url: $.values.repositoryUrl,
      username: $.values.username,
      password: $.values.password,
    }
  else if $.values.sshPrivateKey != null then
    {
      url: $.values.repositoryUrl,
      sshPrivateKey: $.values.sshPrivateKey,
    }
  else
    {
      url: $.values.repositoryUrl,
    },
  repository: secret.new('argocd-repository', {}) +
              secret.metadata.withNamespace($.values.namespace) +
              secret.metadata.withLabels({
                'argocd.argoproj.io/secret-type': 'repository',
              }) +
              secret.withStringData(stringData),
}
