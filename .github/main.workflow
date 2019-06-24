workflow "Main-CI" {
  on = "push"
  resolves = ["Filters for GitHub Actions"]
}

action "auth" {
  uses = "Azure/github-actions/login@master"
  secrets = ["GITHUB_TOKEN", "AZURE_SERVICE_APP_ID", "AZURE_SERVICE_PASSWORD", "AZURE_SERVICE_TENANT"]
}

action "Filters for GitHub Actions" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  needs = ["auth"]
  secrets = ["GITHUB_TOKEN"]
  runs = "git diff --name-only --diff-filter=AM"
}
