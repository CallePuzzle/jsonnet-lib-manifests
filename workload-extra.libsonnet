local k = import 'k.libsonnet';
local hpa = k.autoscaling.v2.horizontalPodAutoscaler;
local metricSpec = k.autoscaling.v2.metricSpec;
local utils = import 'utils.libsonnet';

{
  values:: (import 'params.libsonnet'),

  local cpuMetric =
    metricSpec.withType('Resource') +
    metricSpec.resource.withName('cpu') +
    metricSpec.resource.target.withType('Utilization') +
    metricSpec.resource.target.withAverageUtilization($.values.hpaCpuPercent),

  local hpaSpec = hpa.metadata.withNamespace($.values.namespace)
                  + hpa.metadata.withLabels({ app: $.values.name } + $.values.labels)
                  + hpa.spec.scaleTargetRef.withApiVersion('apps/v1')
                  + hpa.spec.scaleTargetRef.withKind('Deployment')
                  + hpa.spec.scaleTargetRef.withName($.values.name)
                  + hpa.spec.withMinReplicas($.values.hpaMinReplicas)
                  + hpa.spec.withMaxReplicas($.values.hpaMaxReplicas)
                  + hpa.spec.withMetrics([cpuMetric]),

  hpa:
    if utils.hasHpa($.values.hpaMinReplicas, $.values.hpaMaxReplicas) then
      hpa.new($.values.name) + hpaSpec
    else
      null,
}
