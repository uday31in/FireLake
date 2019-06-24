workflow "Main-CI" {
  on = "push"
  resolves = ["docker://alpine/git:latest"]
}

action "docker://alpine/git:latest" {
  uses = "docker://alpine/git:latest"
  secrets = ["GITHUB_TOKEN"]
  runs = "git"
  args = "diff --name-only --diff-filter=AM origin/master"
}
