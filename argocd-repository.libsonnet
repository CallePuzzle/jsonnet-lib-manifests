local k = import 'k.libsonnet';

local secret = k.core.v1.secret;

{
  values:: {
    name: error 'name is required',
    namespace: error 'namespace is required',
    projectName: error 'projectName is required',
    repositoryUrl: error 'repositoryUrl is required',
    password: null,
    username: null,
    sshPrivateKey: null,
  },
  local stringData = if $.values.password != null && $.values.username != null then
    {
      type: 'git',
      url: $.values.repositoryUrl,
      username: $.values.username,
      password: $.values.password,
      project: $.values.projectName,
    }
  else if $.values.sshPrivateKey != null then
    {
      type: 'git',
      url: $.values.repositoryUrl,
      sshPrivateKey: $.values.sshPrivateKey,
      project: $.values.projectName,
    }
  else
    {
      type: 'git',
      url: $.values.repositoryUrl,
      project: $.values.projectName,
    },
  repository: secret.new($.values.name + '-argocd-repository', {}) +
              secret.metadata.withNamespace($.values.namespace) +
              secret.metadata.withLabels({
                'argocd.argoproj.io/secret-type': 'repository',
              }) +
              secret.withStringData(stringData),
}
