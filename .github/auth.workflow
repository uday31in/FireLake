
workflow "Az Login" {
  on = "push"
  resolves = ["GitHub Action for Azure"]
}

action "GitHub Action for Azure" {
  uses = "Azure/github-actions/cli@1364758fbd1891d018072a354a57f9651bacb5b2"
  secrets = ["AZURE_SERVICE_APP_ID", "GITHUB_TOKEN", "AZURE_SERVICE_TENANT", "AZURE_SERVICE_PASSWORD"]
  env = {
    AZURE_SUBSCRIPTION = "4b7561c1-24a7-468f-8b80-bf79cc29d48b"
  }
}
