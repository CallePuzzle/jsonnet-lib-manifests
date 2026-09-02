local argocd_app = (import '../../argocd-app.libsonnet');
local argocd_repository = (import '../../argocd-repository.libsonnet');

local path_app = argocd_app {
  values+:: {
    name: 'svelte-template',
    projectName: 'project-name-example',
    destinationNamespace: self.projectName,
    path: '.',
    repoURL: 'https://github.com/CallePuzzle/svelte-template',
    targetRevision: 'HEAD',
  },
};

local chart_app = argocd_app {
  values+:: {
    name: 'ingress-nginx',
    projectName: 'project-name-example',
    destinationNamespace: self.projectName,
    repoURL: 'https://kubernetes.github.io/ingress-nginx',
    chart: 'ingress-nginx',
    chartReleaseName: 'ingress-nginx',
    chartValues: |||
      controller:
        replicaCount: 2
    |||,
  },
};

local plugin_app = argocd_app {
  values+:: {
    name: 'cmp-app',
    projectName: 'project-name-example',
    destinationNamespace: self.projectName,
    repoURL: 'https://github.com/CallePuzzle/svelte-template',
    plugin: { name: 'tanka-sops' },
  },
};

assert path_app.spec.source.path == '.' : 'path app should carry path';
assert !std.objectHas(path_app.spec.source, 'plugin') : 'path app must not emit plugin';
assert chart_app.spec.source.chart == 'ingress-nginx' : 'chart app should carry chart';
assert !std.objectHas(chart_app.spec.source, 'path') : 'chart app must not emit path';
assert std.objectHas(chart_app.spec.source.helm, 'values') : 'chart app should carry helm values';
assert plugin_app.spec.source.plugin.name == 'tanka-sops' : 'plugin app should carry plugin';
assert !std.objectHas(plugin_app.spec.source, 'chart') : 'plugin app must not emit chart';
assert !std.objectHas(plugin_app.spec.source, 'path') : 'plugin app must not emit path';

{
  path_app: path_app,
  chart_app: chart_app,
  plugin_app: plugin_app,
  argocd_repository: argocd_repository {
    values+:: {
      name: 'svelte-template',
      namespace: 'default',
      projectName: 'project-name-example',
      repositoryUrl: 'https://github.com/CallePuzzle/svelte-template',
      // password: 'password',
      // username: 'username',
      sshPrivateKey: 'ssh-private-key',
    },
  },
}
