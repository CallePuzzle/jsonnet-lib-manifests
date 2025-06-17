local k = import 'k.libsonnet';
local deployment = k.apps.v1.deployment;

{
  values:: (import 'params.libsonnet'),

  local mainContainer = [
    ((import 'container.libsonnet') + { values+: $.values }).this,
  ],

  local containers = mainContainer,

  this: deployment.new(
    name=$.values.name,
    replicas=$.values.hpaMinReplicas,
    containers=containers,
  ),
}
