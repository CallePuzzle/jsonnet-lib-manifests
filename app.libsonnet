local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local service = k.core.v1.service;

{
  values:: (import 'params.libsonnet'),

  local _service = if $.values.port != null then {
    service: k.util.serviceFor(self.workload)
             + service.metadata.withLabels({ app: $.values.name }),
  } else {},

  app: {
    workload: ((import 'workload.libsonnet') + { values+: $.values }).this,
    hpa: ((import 'workload-extra.libsonnet') + { values+: $.values }).hpa,
    ingress: ((import 'ingress.libsonnet') + { values+: $.values }).this,
  } + _service,
}
