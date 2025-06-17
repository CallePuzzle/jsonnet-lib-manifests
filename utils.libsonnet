{
  hasHpa: function(hpaMinReplicas, hpaMaxReplicas) if hpaMinReplicas >= 1 && hpaMaxReplicas > 1 && hpaMinReplicas != hpaMaxReplicas then true else false,
}
