# jsonnet-manifests-for-node-container

A Jsonnet library that generates Kubernetes manifests for node/container workloads,
plus a few Argo CD helper resources. Published and consumed as a
[jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler) package;
the top-level `.libsonnet` files are reusable building blocks that downstream
projects import and parameterize.

- Language: Jsonnet
- Tooling: `jsonnet-bundler` (`jb`), [Grafana Tanka](https://tanka.dev/) (`tk`), `jsonnet`
- License: Apache-2.0 (see `LICENSE`)

## Dependencies

Dependencies are declared in `jsonnetfile.json` and vendored into `vendor/`
(gitignored). `jsonnetfile.lock.json` is committed and pins each dependency to a
specific git SHA, so CI and consumers are reproducible. The same SHAs are also
written in `jsonnetfile.json` as a fallback for tools that do not read the
lockfile:

- `github.com/grafana/jsonnet-libs/ksonnet-util` — kausal utilities
  (e.g. `k.util.serviceFor`)
- `github.com/jsonnet-libs/docsonnet/doc-util` — documentation helpers
- `github.com/jsonnet-libs/k8s-libsonnet/1.32` — typed Kubernetes API builders

## Repository layout

Each top-level file is an independent, composable module. The recurring pattern
is an object with a hidden `values::` field of parameters, and one or more
visible output fields built from those values. Consumers override parameters
with `values+::` (see the tests for examples).

| File | Purpose |
| --- | --- |
| `app.libsonnet` | Top-level composition: builds a full app (workload + HPA + optional Service + optional Ingress) from shared params. Service is emitted only when `values.port != null`; Ingress only when `values.port != null` and `values.serverAlias != null` (the Ingress targets the generated Service); HPA only when `utils.hasHpa(...)` is true. |
| `workload.libsonnet` | The Kubernetes `Deployment` (namespace, labels, annotations, security context, image pull secrets, init containers, `deploymentMixin`). Replicas are set to `null` when an HPA is active. Empty `pullSecret` / `containersInit` / `podAnnotations` are omitted from the rendered output. Pod security context only when `userId` is set; `pullSecret` takes Kubernetes objects (`[{ name: '...' }]`), not strings. |
| `workload-extra.libsonnet` | `HorizontalPodAutoscaler` (autoscaling/v2, CPU utilization), emitted only when `utils.hasHpa(...)` is true. `selfHeal` is configurable. `minReplicas: 0` is allowed (scale-to-zero, requires HPAScaleToZero). The `hpa` output is `null` (not an empty object) when inactive, so Tanka drops it. |
| `container.libsonnet` | The main container spec (ports, resources, probes, env, security context, `containerMixin`). Has its own local `values::` defaults. `readinessProbe` / `livenessProbe` / `startupProbe` / `env` / `envFrom` are only emitted when non-null/non-empty. |
| `params.libsonnet` | Shared default parameters imported by `app`, `workload`, `workload-extra`, and `ingress`. Required values use `error '... not set'` (e.g. `name`, `image`, `namespace`). Optional resources are `null` by default: `port`, `serverAlias`. `userId` is consumed by `workload`/`container` but defaults to `null` — consumers must set it to enable the non-root security contexts. |
| `ingress.libsonnet` | nginx Ingress with a single host rule from `serverAlias` / `serverAliasPath`. Hardcodes `ingressClassName: 'nginx'` and embeds the host in the resource name (`<name>-<serverAlias>`). |
| `argocd-app.libsonnet` | Raw (untyped, plain-object) Argo CD `Application` resource. `source` only includes the fields the consumer actually configured (no null `path` / `chart` / `plugin`). `path`, `chart` and `plugin` are pairwise mutually exclusive and produce a runtime error if combined; `plugin` alone is valid. `autoSync` adds `prune` and `selfHeal`; `targetRevision` defaults to `'HEAD'`. Helm `chartValues` go through `std.native('regexSubst')` (Tanka-only) to keep `tk diff` clean. |
| `argocd-repository.libsonnet` | Argo CD repository `Secret` (supports basic auth, SSH key, or unauthenticated git). Setting only one of `username` / `password` is a runtime error. If `sshPrivateKey` is set together with `username` / `password`, the SSH key takes precedence. |
| `secret-stringData.libsonnet` | Generic Kubernetes `Secret` with `stringData` and an Argo CD sync-wave annotation. `syncWave` is configurable (default `'10'`). |
| `utils.libsonnet` | Small helpers (currently just `hasHpa`). |
| `lib/k.libsonnet` | Local alias that re-exports the k8s-libsonnet 1.32 entrypoint, so modules can `import 'k.libsonnet'`. |

Import style varies: modules import `k.libsonnet` via the `lib/` path
(resolved through the vendor / `jb` path), while `app.libsonnet` imports
`kausal.libsonnet` by its full legacy github path (`legacyImports: true` in
`jsonnetfile.json`).

## Quick start

Install dependencies and render one of the test environments:

```sh
jb install -q
tk show test/argocd-app --dangerous-allow-redirect
```

## Build and test commands

There is no build step — Jsonnet is interpreted.

```sh
jb install -q                                          # install / vendor dependencies
tk fmt .                                               # format (CI runs this)
tk lint .                                              # lint (CI runs this)
tk show test/argocd-app --dangerous-allow-redirect      # render test manifests
tk show test/svelte-template --dangerous-allow-redirect
tk show test/secret-stringData --dangerous-allow-redirect
tk show test/svelte-minimal --dangerous-allow-redirect
```

## Testing strategy

Tests are Tanka environments under `test/`, each with a `spec.json` (Tanka
environment config) and a `main.jsonnet` that imports the library modules and
overrides `values+::` with concrete parameters. Several tests include `assert`
statements that validate the rendered output (namespaces, omitted fields,
configurable sync-waves, etc.) — `tk show` fails at evaluation time if the
assertions do not hold.

- `test/argocd-app/` — exercises `argocd-app.libsonnet` with all three source
  kinds (`path`, `chart` with helm values, `plugin`-only) and
  `argocd-repository.libsonnet` (with `sshPrivateKey`).
- `test/svelte-template/` — exercises the full `app.libsonnet` composition
  (deployment, HPA, ingress, service) and asserts all four resources share
  `values.namespace`.
- `test/secret-stringData/` — exercises `secret-stringData.libsonnet` with the
  default and a custom `syncWave`, asserting both values land in the
  annotation.
- `test/svelte-minimal/` — exercises the `app.libsonnet` composition with
  `port: null` and no `serverAlias` / HPA, asserting that Service, Ingress and
  HPA are not emitted, plus a second app with `serverAlias` but no `port`
  asserting that no Ingress is emitted without a Service.

"Passing" means `tk show` renders without errors (including assertion failures).
CI (`.github/workflows/test.yaml`, runs on PRs to `main`) installs Tanka 0.26.0
and Jsonnet, then runs `jb install`, `tk fmt`, `tk lint`, and `tk show` on all
four test environments. When modifying a module, extend or run the
corresponding test environment to verify rendering.

## Code style conventions

- Follow the existing Jsonnet idiom: 2-space indent, `local` bindings at the
  top of the file/object, builder-style chaining with `+`
  (e.g. `deployment.metadata.withLabels(...)`).
- Parameter objects are hidden fields (`values::`); required parameters are
  expressed as `error '<name> not set'` (or `'... is required'` in the argocd
  modules — match the module you are editing).
- Conditional fields use `if ... then {...} else {}` merged with `+` (see
  `_service` in `app.libsonnet`, `args` / `command` / `_port` in
  `container.libsonnet`).
- Extension points for consumers: `containerMixin`, `deploymentMixin`,
  `labels`, `annotations` — preserve these when editing.
- Run `tk fmt .` before committing; CI enforces formatting and linting.

## Security considerations

- Modules that produce Secrets (`argocd-repository.libsonnet`,
  `secret-stringData.libsonnet`) take credentials as Jsonnet values — never
  commit real credentials into `test/` fixtures or parameter defaults
  (existing tests use placeholder strings like `'ssh-private-key'`).
- Non-root execution is opt-in: set `userId` and both pod and container
  security contexts are emitted (`runAsUser` / `fsGroup`); when `userId` is
  `null` the security contexts are omitted. Do not reintroduce unconditional
  security contexts or hidden non-root defaults.
