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

  this: deployment.new(
          name=$.values.name,
          replicas=replicas,
          containers=containers,
        )
        + deployment.metadata.withNamespace($.values.namespace)
        + deployment.metadata.withLabels({ app: $.values.name } + $.values.labels)
        + deployment.metadata.withAnnotations($.values.annotations)
        + deployment.spec.selector.withMatchLabels({ app: $.values.name })
        + deployment.spec.template.metadata.withLabels({ app: $.values.name })
        + deployment.spec.template.metadata.withAnnotations($.values.podAnnotations)
        + deployment.spec.template.spec.securityContext.withFsGroup($.values.userId)
        + deployment.spec.template.spec.securityContext.withRunAsUser($.values.userId)
        + deployment.spec.template.spec.withImagePullSecrets($.values.pullSecret)
        + deployment.spec.template.spec.withInitContainers($.values.containersInit)
        + $.values.deploymentMixin,
}
