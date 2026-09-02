{
  hasHpa(hpaMinReplicas, hpaMaxReplicas)::
    hpaMinReplicas >= 0 && hpaMaxReplicas > 0 && hpaMinReplicas != hpaMaxReplicas,
}
