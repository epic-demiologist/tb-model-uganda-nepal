# =============================================================================
# 02_cascade_model.R
# Diagnostic cascade: sputum Xpert Ultra vs tongue swab near-point-of-care test
# vs pooled sputum, per 1,000 people with presumptive TB. Model functions are in
# app/model_functions.R (shared with the dashboard).
# =============================================================================
source("app/model_functions.R")

casc <- cascade_model(cascade_defaults)
torn <- cascade_tornado(cascade_defaults, rel = 0.15)

print(casc[, c("strategy", "sample_obtained", "true_pos", "tb_started", "tb_missed", "yield_pct", "prob_tb_treated")])
cat("\nTongue swab minus sputum, people with TB started on treatment per 1,000:",
    round(casc$tb_started[2] - casc$tb_started[1], 1), "\n")

saveRDS(list(cascade = casc, tornado = torn, defaults = cascade_defaults), "data/processed/cascade_results.rds")
write.csv(casc, "data/processed/cascade_results.csv", row.names = FALSE)
