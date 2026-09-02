local app = (import '../../app.libsonnet');

local rendered = app {
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
};

// Sanity assertions: every resource lives in the configured namespace.
local ns = rendered.app.workload.metadata.namespace;
assert ns == 'svelte-template' : 'workload namespace mismatch: ' + ns;
assert rendered.app.service.metadata.namespace == 'svelte-template' : 'service namespace mismatch';
assert rendered.app.hpa.metadata.namespace == 'svelte-template' : 'hpa namespace mismatch';
assert rendered.app.ingress.metadata.namespace == 'svelte-template' : 'ingress namespace mismatch';
assert rendered.app.hpa.spec.maxReplicas == 2 : 'hpa maxReplicas mismatch';

// No null probes, no empty arrays on the container.
local c = rendered.app.workload.spec.template.spec.containers[0];
assert !std.objectHas(c, 'readinessProbe') : 'readinessProbe should be omitted when null';
assert !std.objectHas(c, 'livenessProbe') : 'livenessProbe should be omitted when null';
assert !std.objectHas(c, 'startupProbe') : 'startupProbe should be omitted when null';
assert !std.objectHas(c, 'env') : 'env should be omitted when empty';
assert !std.objectHas(c, 'envFrom') : 'envFrom should be omitted when empty';

{
  svelte_template: rendered,
}
