action "Setup Ruby for use with actions" {
  uses = "actions/setup-ruby@50f3cc9f0b0ab0fc1ed658c07aee4b1d61970143"
  runs = "./script/build"
}

workflow "Rspec" {
  on = "check_run"
  resolves = ["Setup Ruby for use with actions-1"]
}

action "Setup Ruby for use with actions-1" {
  uses = "actions/setup-ruby@50f3cc9f0b0ab0fc1ed658c07aee4b1d61970143"
  runs = "./script/cibuild"
}
