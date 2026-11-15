# Deploy the dashboard to shinyapps.io
# 1) Once: rsconnect::setAccountInfo(name = "<account>", token = "<token>", secret = "<secret>")
#    (copy this command from shinyapps.io -> Account -> Tokens -> Show)
# 2) Then: source("deploy.R")
rsconnect::deployApp(appDir = "app", appName = "tb-models", forceUpdate = TRUE)
