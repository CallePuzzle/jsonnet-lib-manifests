local k = import 'k.libsonnet';
local hpa = k.autoscaling.v1.horizontalPodAutoscaler;


{
  values:: (import 'params.libsonnet'),


  local hpaSpec = hpa.metadata.withLabels({ app: $.values.name, product: 'nx' })
                  + hpa.spec.scaleTargetRef.withApiVersion('apps/v1')
                  + hpa.spec.scaleTargetRef.withKind('Deployment')
                  + hpa.spec.scaleTargetRef.withName($.values.name)
                  + hpa.spec.withTargetCPUUtilizationPercentage($.values.hpaCpuPercent)
                  + hpa.spec.withMinReplicas($.values.hpaMinReplicas)
                  + hpa.spec.withMaxReplicas($.values.hpaMaxReplicas),

  hpa: if $.values.hpaMinReplicas >= 1 && $.values.hpaMaxReplicas > 1 && $.values.hpaMinReplicas != $.values.hpaMaxReplicas then hpa.new($.values.name) + hpaSpec else {},

}
