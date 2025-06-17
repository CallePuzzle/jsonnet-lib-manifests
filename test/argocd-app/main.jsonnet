local argocd_app = (import '../../argocd-app.libsonnet');

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
}
