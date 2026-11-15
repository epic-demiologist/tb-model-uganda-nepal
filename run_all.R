# Reproduce everything: data -> cascade -> calibration -> scenarios -> copy outputs to the app
for (f in c("R/01_prepare_data.R", "R/02_cascade_model.R", "R/03_calibrate.R", "R/04_scenarios.R")) {
  message("\n==== ", f); source(f, echo = FALSE)
}
file.copy(list.files("data/processed", pattern = "\\.rds$", full.names = TRUE), "app/data", overwrite = TRUE)
message("Done. Launch the dashboard with: shiny::runApp('app')")
