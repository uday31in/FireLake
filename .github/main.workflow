workflow "Main-CI" {
  on = "push"
  resolves = ["Filters for GitHub Actions"]
}

action "auth" {
  uses = "Azure/github-actions/login@master"
  secrets = ["GITHUB_TOKEN", "AZURE_SERVICE_APP_ID", "AZURE_SERVICE_PASSWORD", "AZURE_SERVICE_TENANT"]
}

