local argocd_app = (import '../../argocd-app.libsonnet');
local argocd_repository = (import '../../argocd-repository.libsonnet');

{
  svelte_template: argocd_app {
    values+:: {
      name: 'svelte-template',
      projectName: 'project-name-example',
      destinationNamespace: self.projectName,
      environment: 'test',
      repoURL: 'https://github.com/CallePuzzle/svelte-template',
      targetRevision: 'master',
    },
  },
  argocd_repository: argocd_repository {
    values+:: {
      name: 'svelte-template',
      namespace: 'default',
      repositoryUrl: 'https://github.com/CallePuzzle/svelte-template',
      // password: 'password',
      // username: 'username',
      sshPrivateKey: 'ssh-private-key',
    },
  },
}
