# Code Review — jsonnet-lib-manifests

Fecha: 2026-08-12 · Commit: `44ac821` (main)
Actualización: 2026-08-13 — validación contra consumidores reales (ver sección al final).

Review completo de la librería Jsonnet (módulos top-level + tests). Verificado con `jb install` y `tk show` sobre los dos entornos de test.

## Resumen

La librería es coherente en su patrón (`values::` ocultos + overrides con `values+::`, builders encadenados, campos requeridos con `error`), pero tiene **un test roto en main**, **un bug real de namespaces** (la app se despliega repartida en dos namespaces) y varias inconsistencias de API y defaults. Los hallazgos están ordenados por severidad.

---

## Críticos

### 1. El entorno de test `test/argocd-app` no renderiza (CI rota)

`tk show test/argocd-app --dangerous-allow-redirect` falla:

```
RUNTIME ERROR: projectName is required
	argocd-repository.libsonnet:9:18-49
```

`test/argocd-app/main.jsonnet:15-24` instancia `argocd-repository` sin `projectName`, pero `argocd-repository.libsonnet:9` lo declara requerido. Regresión probable de `2da3fe2 fix argocd repository type and project`, que añadió `project` al secret sin actualizar el fixture. **El CI de PRs a main falla en este estado.**

Fix: añadir `projectName: 'project-name-example'` a los values del fixture.

### 2. Namespaces inconsistentes: la app se despliega en dos namespaces

Solo el `Deployment` lleva `values.namespace` (`workload.libsonnet:21`). El `Service` (`app.libsonnet:9`, via `k.util.serviceFor`), el `HPA` (`workload-extra.libsonnet:16`) y el `Ingress` (`ingress.libsonnet:19`) no llaman a `withNamespace`. Render real del test svelte-template:

- Deployment → `namespace: svelte-template` (de `values`)
- Service, HPA, Ingress → `namespace: default` (inyectado por Tanka desde `spec.json`)

El Ingress y el HPA del namespace `default` apuntan a recursos del namespace `svelte-template` — el HPA no encontrará el Deployment y el Ingress no resolverá el Service. Fix: añadir `metadata.withNamespace($.values.namespace)` en service, hpa e ingress.

### 3. `requestMemory: 128` en `params.libsonnet:18`

El default es un entero, que Kubernetes interpreta como **128 bytes** (no 128Mi). Además es inconsistente con `requestCpu: '100m'` (string). Fix: `requestMemory: '128Mi'`.

---

## Bugs / riesgos medios

### 4. Ingress emitido aunque no haya Service (`app.libsonnet:16`)

`_service` es condicional a `values.port != null`, pero `ingress` se emite siempre. Con `port: null` queda un Ingress apuntando a un Service inexistente. Además, la condición es **inalcanzable** por la vía normal: `params.libsonnet:15` define `port: error 'port not set'`, así que `port != null` nunca es false salvo override explícito a `null`. El diseño "Service opcional" está documentado en AGENTS.md pero no funciona como tal. Decidir: o `port` es requerido (y se elimina la condicional), o el default es `null` y el ingress también se condiciona.

### 5. Probes `null` en el manifiesto renderizado

`container.libsonnet:50-52` emite siempre `{ readinessProbe: $.values.readinessProbe }` etc. El render contiene `readinessProbe: null`, `livenessProbe: null`, `startupProbe: null`. Kubernetes lo tolera, pero ensucia el diff (`tk diff`) y algunos validadores estrictos lo rechazan. El patrón correcto ya existe en el mismo archivo (`args`, `command`, `_port`): condicional + merge.

### 6. HPA en `autoscaling/v1` (deprecada)

`workload-extra.libsonnet:2` usa `k.autoscaling.v1`. La API v1 de HPA está deprecada; `autoscaling/v2` es estable desde K8s 1.23 y la librería ya vendors k8s-libsonnet **1.32**. Además v1 solo permite CPU (`targetCPUUtilizationPercentage`). Migrar a v2 (con `metrics`) es recomendable.

### 7. `argocd-app.libsonnet` emite campos `null` y permite combinaciones inválidas

- `source` incluye siempre `path: null` / `plugin: null` / `chart: null` (líneas 44-49) cuando no aplican.
- `chart: if self.path == null then error 'chart is required'` (línea 10) fuerza `chart` solo cuando no hay `path`, pero **no impide definir ambos** — en Argo CD, `path` y `chart` son mutuamente excluyentes. Con `path` definido, `chart` evalúa a `null` y se emite.
- El comentario de la línea 51 tiene typo: "line-break's".

### 8. `argocd-repository.libsonnet`: fallback silencioso a repo sin autenticar

Si el consumidor define solo `username` (o solo `password`), la condición de línea 15 es false y el secret se genera **sin credenciales**, sin error. Mejor: error explícito si solo uno de los dos está presente.

### 9. Dependencias sin pinnar + lockfile ignorado

`jsonnetfile.json` usa `master`/`main` para las tres dependencias y `jsonnetfile.lock.json` está en `.gitignore`. Resultado: CI y consumidores no son reproducibles — un cambio upstream puede romper el build sin tocar este repo. Recomendación: commitear el lockfile y/o pinnar a tags/SHAs.

---

## Menores / mejoras

- **`container.libsonnet:24,32` — chequeo muerto**: `userId` es `error 'userId not set'` (requerido), pero el securityContext comprueba `if $.values.userId != null`. Solo puede ser null si el consumidor lo sobreescribe explícitamente; en `params.libsonnet` ni siquiera existe `userId`. Unificar criterio (requerido u opcional con default).
- **`workload.libsonnet:25` — labels no propagadas al pod template**: el Deployment lleva `{app} + values.labels` pero los pods solo `{app: name}`. Los pods no heredan `owner` ni labels custom, lo que dificulta seleccionarlos/auditarlos.
- **Ruido en el output**: `env: []`, `envFrom: []`, `imagePullSecrets: []`, `initContainers: []`, `annotations: {}` se emiten aunque estén vacíos.
- **Defaults personales en una librería publicada**: `owner: 'callepuzzle'` (`params.libsonnet:8`) y sync-waves hardcodeados (`params.libsonnet:11` → '50'; `secret-stringData.libsonnet:15` → '10', este último sin posibilidad de override). Considerar sacarlos de los defaults o hacerlos configurables.
- **`argocd-app.libsonnet:52` — dependencia de `std.native('regexSubst')`**: solo funciona con toolchains que registren esa native function (tk); falla con `jsonnet` puro. Limitación de portabilidad a documentar.
- **API de salida inconsistente entre módulos**: `this` (workload, ingress, container), `app` (app), `hpa` (workload-extra), `repository`/`secret`. Convendría un nombre uniforme.
- **`utils.hasHpa`**: `if <cond> then true else false` es redundante (devolver la condición); tampoco soporta `minReplicas: 0` (scale-to-zero, válido en HPA v2).
- **`workload.libsonnet:29`**: `withImagePullSecrets` espera objetos `{name: ...}` de K8s, no strings — no está documentado en el módulo.
- **`ingress.libsonnet`**: sin soporte de TLS, sin annotations configurables (p. ej. cert-manager, rate-limiting de nginx) y `ingressClassName: 'nginx'` hardcodeado.
- **`ingress.libsonnet:7`**: el nombre del Ingress incluye el host completo (`svelte-template-www.svelte-template.com`); válido como DNS-1123 subdomain, pero innecesariamente largo.
- **`argocd-app.libsonnet`**: `autoSync` activa `prune: true` pero no `selfHeal`; `targetRevision` por defecto `'master'`. Decisiones a documentar.
- **Fixture `test/argocd-app/main.jsonnet:10`**: `environment: 'test'` es un campo extra de `values` que ningún módulo consume (no rompe nada, pero confunde).
- **Cobertura de tests**: los tests solo verifican que `tk show` no falle; no hay aserciones sobre el contenido renderizado. Un test que hubiera comprobado namespaces habría pillado el hallazgo #2. No hay test para `secret-stringData.libsonnet` ni para el caso `port: null` / sin HPA.

---

## Lo que está bien

- Patrón `values::` + `values+::` consistente y bien explotado en los tests.
- Campos requeridos con `error '<name> not set'` — fallo temprano y claro.
- Extension points (`containerMixin`, `deploymentMixin`, `labels`, `annotations`) aplicados al final de la cadena, permitiendo al consumidor sobreescribir cualquier campo.
- Replicas omitidas correctamente cuando el HPA está activo (verificado: el Deployment renderizado no lleva `replicas`).
- Security contexts non-root en pod y contenedor por defecto.
- Uso correcto del idiom condicional (`if ... then {} else {}` + merge) en la mayoría de los módulos.

## Prioridad sugerida

1. Arreglar el fixture de `test/argocd-app` (#1) — CI rota.
2. Namespaces en service/hpa/ingress (#2) — despliegue funcionalmente roto.
3. `requestMemory: '128Mi'` (#3).
4. Decidir la semántica de `port` opcional y condicionar el ingress (#4).
5. Probes condicionales (#5) y migración a HPA v2 (#6).

---

## Actualización 2026-08-13 — Validación contra consumidores reales

El working tree (sin commit todavía) ya trae fixes para prácticamente todos los hallazgos de arriba: #1, #2, #3, #6, #7, #8, más varios de la sección "menores" (probes condicionales #5, `hasHpa` #utils, labels en pod template, `env`/`envFrom` vacíos, `syncWave` configurable, `selfHeal`/`targetRevision` en argocd-app, `AGENTS.md`/README nuevos, tests `svelte-minimal` y `secret-stringData` nuevos con `assert`). Los 4 entornos de test (`tk show`) pasan limpios.

Para confirmar que esos fixes no rompen nada fuera de este repo, se contrastaron contra los tres consumidores reales (repos hermanos, cuyos `lib/.../jsonnet-lib-manifests` son symlinks a este working tree, así que `tk show` ahí renderiza los cambios tal cual):

- `../Zytera/backend/deploy` (staging + pro)
- `../Zytera/web-app/deploy` (staging)
- `../Zytera/infra/app-of-apps` (staging + pro)

### Confirmado OK en real

- **#2 (namespaces)**: `web-app/staging` renderiza Deployment, Service e Ingress los tres en `medapsis-staging`. Consistente.
- **#7/#8 (argocd-app / argocd-repository)**: `app-of-apps` (`staging` y `pro`) renderiza las 3 Applications + 3 repository Secrets sin error, incluyendo el caso real con `sshPrivateKey` (sin `username`/`password`).

### 🔴 Nuevo crítico: el fix de `secret-stringData.libsonnet` rompe `backend` en real

`tk show` sobre `backend/deploy` (**staging y pro**) falla:

```
RUNTIME ERROR: Field does not exist: syncWave
	.../secret-stringData.libsonnet:16:45-62
```

Causa: el nuevo default `syncWave: '10'` (parte del fix del hallazgo menor "sync-wave hardcodeado sin override") solo funciona si el consumidor hace `values+:: {...}` (merge). `backend/deploy/lib/app.libsonnet` construye el secret con `values:: {...}` (**reemplazo completo**, no merge):

```jsonnet
secret: _secret {
  values:: {
    name: 'backend',
    namespace: tk.env.spec.namespace,
    stringData: { DATABASE_URL: secrets.DATABASE_URL },
  },
},
```

Al reemplazar entero el objeto de defaults se pierde `syncWave`, y como el módulo lo referencia sin condicional (`$.values.syncWave`), revienta. Es el único punto de los tres consumidores que usa `::` en vez de `+::` contra esta librería — `web-app` y `app-of-apps` sí siguen la convención documentada en `AGENTS.md`/README ("Consumers override parameters with `values+::`") y no se ven afectados.

Ningún test de este repo detecta esta regresión porque ningún fixture reproduce el patrón "reemplazo completo" (`values::`) que usa `backend` — los 4 `tk show` de `test/` pasan limpios pese a la rotura real.

**Opciones de fix:**
1. Corregir `backend/deploy/lib/app.libsonnet` (`values::` → `values+::` en el bloque `secret`) — es el fix correcto según la convención de la librería, pero vive en otro repo.
2. Documentar explícitamente en el commit/PR de este cambio que es un *breaking change* para cualquier consumidor que use `secret-stringData.libsonnet` con reemplazo completo de `values`, antes de mergear a `main`.

No excluyentes — probablemente conviene hacer ambas.

### Hallazgo menor residual: `argocd-app` con `plugin` sin `path` sigue roto

El fix de exclusión mutua (`_validateSource`) cubre `path`+`chart` y `path`+`plugin`, pero no el caso "solo `plugin`, sin `path` ni `chart`": el default de `chart` (`if self.path == null then error 'chart is required'`) sigue forzando error en ese caso, porque `_source` evalúa `$.values.chart != null` sin condicionar a que `plugin` esté seteado. Bug preexistente (ya estaba en `44ac821`), no introducido por el fix actual. **Ningún consumidor real usa `plugin` hoy** (el CMP `tanka-sops` que aparece en `infra/` es un plugin de Argo CD a nivel repo-server, no el campo `spec.source.plugin` de esta librería), así que no rompe nada en producción — pero si algún día se usa, hay que acordarse de setear `chart: null` explícitamente o arreglar el default.

### Nota aparte (no es un hallazgo de la librería)

Al renderizar `app-of-apps` con `tk show`, las claves SSH de los repos salen desencriptadas en el output (comportamiento normal de sops/tanka-sops, no algo introducido por estos cambios). No se han vuelto a imprimir ni persistido en ningún artefacto — mencionado solo como precaución operativa al ejecutar `tk show --dangerous-allow-redirect` sobre estos entornos.

### Prioridad actualizada

1. **Resolver la rotura de `secret-stringData` en `backend`** (fix en `backend/deploy/lib/app.libsonnet` y/o nota de breaking change) — bloqueante antes de mergear estos cambios a `main`, ya rompe `staging` y `pro` reales.
2. Mergear el resto de fixes ya aplicados en el working tree (#1, #2, #3, #6, #7, #8, menores) — validados en real salvo el punto anterior.
3. Arreglar el caso `plugin`-only de `argocd-app.libsonnet` (`chart: null` cuando `path == null && plugin != null`) — baja prioridad, sin consumidores afectados hoy.

---

## Actualización 2026-09-02 — Revisión de staged, fix de `auth` y fixes residuales

Re-revisión del diff staged (ramas `dev`) contra los tres consumidores activos: `backend/deploy`, `web-app/deploy` y `auth` (este último no había entrado en la validación del 2026-08-13). Todos los `tk show` de la librería y el render de `web-app/staging` pasan limpios.

### Corrección sobre el estado de los consumidores (importante)

Los tres consumidores renderizan **este working tree en caliente**: cada uno tiene `lib/github.com/CallePuzzle/jsonnet-lib-manifests` como symlink a este repo, que es la ruta por la que tk resuelve los imports `github.com/CallePuzzle/jsonnet-lib-manifests/...`. Los directorios `vendor/` de backend y web-app son copias antiguas residuales (pinnadas a SHAs viejos: `e2e0510` en backend/auth, `cfab8b9` en web-app) que tk no usa mientras exista el symlink — solo importan para CI o clones sin symlink. Verificado empíricamente: el render de `web-app/staging` muestra los rasgos exclusivos de la versión staged (labels del owner en el pod template, `env`/`envFrom` vacíos omitidos, Ingress/Service/Deployment en `medapsis-staging`).

Consecuencia práctica: **cualquier rotura en este working tree se activa en staging/pro al momento**, no al re-pinear. Los pins de `jsonnetfile.lock.json` de los consumidores habrá que subirlos al mergear, pero no protegen nada hoy.

### 🔴→✅ Crítico resuelto: `auth` tenía el mismo patrón roto que `backend`

`auth/deploy/lib/app.libsonnet` construía el `secret` con `values::` (reemplazo completo), el mismo patrón que rompía `backend` — `auth` simplemente no había entrado en la validación anterior. **Fix aplicado**: `values::` → `values+::` en el bloque `secret` (idéntico al fix ya commiteado en `backend`). Tras el fix, `web-app` sigue siendo el único consumidor que no usa `secret-stringData`.

Estado de los tres consumidores frente a la librería staged: `backend` ✅ (fix commiteado), `auth` ✅ (fix aplicado, pendiente de commit en su repo), `web-app` ✅ (no usa el módulo afectado). Los tres siguen la convención `values+::` en todos sus puntos de extensión.

### ✅ Fixes residuales aplicados en la librería (working tree, sin commit)

1. **Ingress condicionado también a `port`** (`app.libsonnet`): antes se emitía con solo `serverAlias`, dejando un Ingress apuntando a un Service inexistente cuando `port: null`. Ahora la condición es `serverAlias != null && port != null` — el Ingress siempre tiene el Service al que apunta. Cubierto con un segundo caso en `test/svelte-minimal` (`serverAlias` sin `port`).
2. **Security context del pod condicional a `userId`** (`workload.libsonnet`): antes `withFsGroup/withRunAsUser(null)` producía `securityContext: {fsGroup: null, runAsUser: null}` (ruido que renderiza como `{}`). Ahora, igual que en `container.libsonnet`, no se emite nada cuando `userId` es `null`. Verificado: con `userId: null` el pod spec no lleva `securityContext`.
3. **Caso `plugin`-only de `argocd-app` arreglado** (prioridad 3 de la lista anterior): el default de `chart` ahora solo exige `chart` cuando no hay `path` **ni** `plugin`; verificado que un Application con solo `plugin` renderiza `source` limpio (`plugin`/`repoURL`/`targetRevision`).
4. **Exclusión mutua `plugin`+`chart`** añadida a `_validateSource` (en Argo CD también son excluyentes): ahora hay error explícito en las tres combinaciones (`path`+`chart`, `path`+`plugin`, `plugin`+`chart`).
5. **Cobertura de tests ampliada** (`test/argocd-app`): se añaden un Application por `chart` (con `chartValues` + `chartReleaseName`) y uno `plugin`-only, con asserts sobre las claves exactas de `spec.source` en los tres casos. Antes solo se ejercitaba `path`.

### Documentación actualizada (AGENTS.md y README.md)

- Semántica del Ingress: se emite solo con `port` **y** `serverAlias`.
- `userId`: no-root es opt-in; los security contexts (pod y contenedor) solo se emiten si `userId` está seteado — sustituye la frase "workloads default to running as a non-root user", que ya no describía el comportamiento real.
- `app.hpa` es `null` (no `{}`) cuando no hay HPA, por eso tk lo descarta.
- `argocd-app`: `path`/`chart`/`plugin` son pairwise excluyentes; `plugin` solo es válido.
- `argocd-repository`: si se setean `sshPrivateKey` y `username`/`password` a la vez, gana la clave SSH (precedencia documentada, comportamiento sin cambio).
- `pullSecret` espera objetos Kubernetes (`[{ name: '...' }]`), no strings.

### Validación ejecutada hoy

- `tk fmt --test .`, `tk lint .` y los 4 `tk show` (`argocd-app`, `svelte-template`, `secret-stringData`, `svelte-minimal`): **limpios**.
- `web-app/staging` contra el working tree: Deployment/Service/Ingress en `medapsis-staging`, security context correcto, Ingress presente — sin regresiones.
- `backend`/`auth` no renderizan en esta máquina por falta de `secrets.json` (gitignored, generado localmente); el fix de `auth` es estructuralmente idéntico al de `backend`, que sí se validó en su día.
- Edge cases verificados con `jsonnet`: `userId: null` sin security context, `serverAlias` sin `port` sin Service/Ingress, `plugin`-only OK, `plugin`+`chart` error explícito.

### Estado de la lista de prioridades anterior

1. ~~Rotura de `secret-stringData`~~ → resuelto en ambos repos afectados (`backend` y `auth`).
2. Merge del resto de fixes → siguen pendientes de commit/PR (este mismo diff staged, más los de hoy).
3. ~~`plugin`-only~~ → resuelto, con exclusión `plugin`+`chart` y cobertura de test incluidas.

Pendiente antes de mergear a `main`: bump del pin de `jsonnetfile.lock.json` en `backend/deploy`, `web-app/deploy` y `auth/deploy` una vez esta rama esté en `main` (los symlinks harán el trabajo en local, pero los clones/CI de los consumidores necesitan el pin nuevo).
