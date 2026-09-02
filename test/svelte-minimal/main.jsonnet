local app = (import '../../app.libsonnet');

local rendered = app {
  values+:: {
    name: 'svelte-minimal',
    image: 'svelte-minimal',
    namespace: 'svelte-minimal',
    userId: 10000,
  },
};

// No port, no serverAlias, no HPA: Service, Ingress and HPA must NOT be emitted.
assert !std.objectHasAll(rendered.app, 'service') : 'service should not be emitted when port is null';
assert !std.objectHasAll(rendered.app, 'ingress') : 'ingress should not be emitted when serverAlias is null';
assert rendered.app.hpa == null : 'hpa should not be emitted when hpaMaxReplicas == hpaMinReplicas';

// serverAlias without port: the Ingress targets the generated Service, so with
// no Service there must be no Ingress either.
local no_port = app {
  values+:: {
    name: 'svelte-minimal-no-port',
    image: 'svelte-minimal',
    namespace: 'svelte-minimal',
    userId: 10000,
    serverAlias: 'www.svelte-minimal.com',
  },
};
assert !std.objectHasAll(no_port.app, 'service') : 'service should not be emitted when port is null';
assert !std.objectHasAll(no_port.app, 'ingress') : 'ingress should not be emitted when port is null even with serverAlias';

{
  svelte_minimal: rendered,
}
