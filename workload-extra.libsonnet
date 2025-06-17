local k = import 'k.libsonnet';
local hpa = k.autoscaling.v1.horizontalPodAutoscaler;
local utils = import 'utils.libsonnet';

{
  values:: (import 'params.libsonnet'),

  local hpaSpec = hpa.metadata.withLabels({ app: $.values.name } + $.values.labels)
                  + hpa.spec.scaleTargetRef.withApiVersion('apps/v1')
                  + hpa.spec.scaleTargetRef.withKind('Deployment')
                  + hpa.spec.scaleTargetRef.withName($.values.name)
                  + hpa.spec.withTargetCPUUtilizationPercentage($.values.hpaCpuPercent)
                  + hpa.spec.withMinReplicas($.values.hpaMinReplicas)
                  + hpa.spec.withMaxReplicas($.values.hpaMaxReplicas),

  hpa: if utils.hasHpa($.values.hpaMinReplicas, $.values.hpaMaxReplicas) then hpa.new($.values.name) + hpaSpec else {},
}
