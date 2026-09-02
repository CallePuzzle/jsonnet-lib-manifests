local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local service = k.core.v1.service;

{
  values:: (import 'params.libsonnet'),

  local _service = if $.values.port != null then {
    service: k.util.serviceFor(self.workload)
             + service.metadata.withNamespace($.values.namespace)
             + service.metadata.withLabels({ app: $.values.name } + $.values.labels),
  } else {},

  local _ingress = if $.values.serverAlias != null && $.values.port != null then {
    ingress: ((import 'ingress.libsonnet') + { values+: $.values }).this,
  } else {},

  app: {
    workload: ((import 'workload.libsonnet') + { values+: $.values }).this,
    hpa: ((import 'workload-extra.libsonnet') + { values+: $.values }).hpa,
  } + _service + _ingress,
}
