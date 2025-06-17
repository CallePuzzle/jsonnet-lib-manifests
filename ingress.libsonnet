local k = import 'k.libsonnet';
local ingress = k.networking.v1.ingress;

{
  values:: (import 'params.libsonnet'),

  local name = $.values.name + '-' + $.values.serverAlias,

  local rules = [
    k.networking.v1.ingressRule.withHost($.values.serverAlias) +
    k.networking.v1.ingressRule.http.withPaths([
      k.networking.v1.httpIngressPath.withPath($.values.serverAliasPath) +
      k.networking.v1.httpIngressPath.withPathType($.values.serverAliasPathType) +
      k.networking.v1.httpIngressPath.backend.service.withName($.values.name) +
      k.networking.v1.httpIngressPath.backend.service.port.withName($.values.name + '-' + $.values.portName),
    ]),
  ],

  this: ingress.new(name=name)
        + ingress.metadata.withLabels($.values.labels)
        + ingress.spec.withRules(rules)
        + ingress.spec.withIngressClassName('nginx'),
}
