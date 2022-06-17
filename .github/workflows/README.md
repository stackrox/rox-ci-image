Development (local iteration)
-----------------------------

> :warning: toggle debug logging for workflow steps by updating the
> `ACTIONS_RUNNER_DEBUG` secret.

```bash
make lint-shell
make github-workflow-syntax-check
```


Github Actions CLI Examples
---------------------------

```bash
brew upgrade gh

gh run view      # interactive
gh run download  # interactive
gh run rerun     # interactive
gh workflow view # interactive

gh run watch
gh run list --limit 3 --json name,status,headBranch,createdAt,url,event,conclusion
gh run view --log --job=7044383751
gh run download -n artifact-foo
gh workflow view 'Hello World' --ref shane/rs-525-ci-migration --yaml
gh workflow disable 'Hello World'
gh workflow enable 'Hello World'
gh workflow run 'Hello World' --ref shane/rs-525-ci-migration
```


References
----------

* https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions
* https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
* https://docs.github.com/en/actions/examples
* https://github.com/actions/starter-workflows/blob/main/ci/docker-image.yml
* https://github.com/actions/starter-workflows/blob/main/ci/docker-publish.yml
* https://github.blog/2021-04-15-work-with-github-actions-in-your-terminal-with-github-cli/
* https://stackoverflow.com/questions/62142092/is-it-okay-to-use-github-secrets-with-a-public-repo
* https://docs.github.com/en/rest/actions/secrets
* https://securitylab.github.com/research/github-actions-preventing-pwn-requests/
* https://docs.github.com/en/actions/using-jobs/defining-outputs-for-jobs
* https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions
* https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts
* https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions
* https://docs.github.com/en/actions/using-workflows/reusing-workflows
* https://docs.github.com/en/actions/using-workflows/about-workflows
* https://github.com/actions
* https://github.com/actions/starter-workflows/blob/main/ci/docker-image.yml
* https://github.com/actions/starter-workflows/blob/main/ci/docker-publish.yml
* https://github.com/actions/upload-artifact
* https://github.com/actions/download-artifact
* https://github.com/docker/login-action
