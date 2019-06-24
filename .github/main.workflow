workflow "Main-CI" {
  on = "push"
  resolves = ["Filters for GitHub Actions"]
}

action "auth" {
  uses = "Azure/github-actions/login@master"
  secrets = ["GITHUB_TOKEN", "AZURE_SERVICE_APP_ID", "AZURE_SERVICE_PASSWORD", "AZURE_SERVICE_TENANT"]
}

action "Filters for GitHub Actions" {
  uses = "docker://alpine/git:latest"
  needs = ["auth"]
  secrets = ["GITHUB_TOKEN"]
  args = "diff --name-only --diff-filter=AM"
}
