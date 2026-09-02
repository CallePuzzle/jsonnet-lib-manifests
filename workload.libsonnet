local k = import 'k.libsonnet';
local deployment = k.apps.v1.deployment;

local utils = import 'utils.libsonnet';

{
  values:: (import 'params.libsonnet'),

  local mainContainer = [
    ((import 'container.libsonnet') + { values+: $.values }).this,
  ],

  local containers = mainContainer,
  local replicas = if utils.hasHpa($.values.hpaMinReplicas, $.values.hpaMaxReplicas) then null else $.values.hpaMinReplicas,

  local _pullSecrets = if std.length($.values.pullSecret) > 0 then
    deployment.spec.template.spec.withImagePullSecrets($.values.pullSecret)
  else {},

  local _initContainers = if std.length($.values.containersInit) > 0 then
    deployment.spec.template.spec.withInitContainers($.values.containersInit)
  else {},

  local _podAnnotations = if std.length($.values.podAnnotations) > 0 then
    deployment.spec.template.metadata.withAnnotations($.values.podAnnotations)
  else {},

  local _securityContext = if $.values.userId != null then
    deployment.spec.template.spec.securityContext.withFsGroup($.values.userId)
    + deployment.spec.template.spec.securityContext.withRunAsUser($.values.userId)
  else {},

  this: deployment.new(
          name=$.values.name,
          replicas=replicas,
          containers=containers,
        )
        + deployment.metadata.withNamespace($.values.namespace)
        + deployment.metadata.withLabels({ app: $.values.name } + $.values.labels)
        + deployment.metadata.withAnnotations($.values.annotations)
        + deployment.spec.selector.withMatchLabels({ app: $.values.name })
        + deployment.spec.template.metadata.withLabels({ app: $.values.name } + $.values.labels)
        + _podAnnotations
        + _securityContext
        + _pullSecrets
        + _initContainers
        + $.values.deploymentMixin,
}
