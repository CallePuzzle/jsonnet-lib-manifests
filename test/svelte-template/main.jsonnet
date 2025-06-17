local app = (import '../../app.libsonnet');

{
  svelte_template: app {
    values+:: {
      name: 'svelte-template',
      image: 'svelte-template',
      namespace: 'svelte-template',
      userId: 10000,
      port: 3000,
      requestCpu: '10m',
      requestMemory: '50Mi',
      serverAlias: 'www.svelte-template.com',
      hpaMaxReplicas: 2,
    },
  },
}
