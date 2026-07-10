# Configuration generation
{
  name = "statistikles",
  replicas =
    let env = "dev" in
    if env == "prod" then 5
    else if env == "staging" then 3
    else 1,
  port = 8080,
  env = "dev",
}
