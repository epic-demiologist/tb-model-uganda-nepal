# =============================================================================
# 03_calibrate.R
# Calibrate the TB transmission model to WHO incidence and notification rates
# (2015-2024) for Uganda and Nepal, with parameter uncertainty:
#   * Latin hypercube sample (n = 60 per country) over uncertain natural-history
#     parameters; for each draw, beta and the case detection rates are re-fitted.
#   * The best-fitting point (median parameter values) is saved for the dashboard.
# Run time: ~10-20 minutes on 4 cores.
# =============================================================================
suppressPackageStartupMessages({ library(lhs); library(parallel) })
source("app/model_functions.R")
set.seed(2027)

targets <- readRDS("data/processed/calibration_targets.rds")
n_draws <- 60
ranges <- list(                       # plausible ranges from the literature (app/methods.md)
  eps  = c(0.030, 0.060),             # fast progression
  nu   = c(0.0003, 0.0010),           # slow reactivation
  x    = c(0.60, 0.90),               # protection against reinfection
  cure = c(0.10, 0.20),               # self-cure
  rho  = c(0.004, 0.015),             # relapse
  tpt_eff = c(0.70, 0.90),            # 3HP efficacy among completers
  irr  = c(10, 20)                    # TB incidence rate ratio with HIV
)

calib_country <- function(iso) {
  tg <- subset(targets, iso3 == iso)
  base <- calibrate(tb_fixed(iso), tg)
  message(iso, ": point estimate fitted (SSE ", round(base$sse, 2), ")")
  u <- randomLHS(n_draws, length(ranges)); colnames(u) <- names(ranges)
  draws <- mclapply(seq_len(n_draws), function(i) {
    p <- tb_fixed(iso)
    for (k in names(ranges)) p[[k]] <- ranges[[k]][1] + u[i, k] * diff(ranges[[k]])
    st <- c(log(base$beta), log(base$d15), log(base$d24 / base$d15) + 0.001)
    tryCatch(calibrate(p, tg, start = st), error = function(e) NULL)
  }, mc.cores = max(1, detectCores() - 1))
  draws <- Filter(Negate(is.null), draws)
  sse <- sapply(draws, `[[`, "sse")
  keep <- draws[sse <= 2 * base$sse]          # retain draws that fit about as well as the point estimate
  message(iso, ": kept ", length(keep), " of ", length(draws), " draws")
  list(point = base, draws = keep)
}

calib <- setNames(lapply(c("UGA", "NPL"), calib_country), c("UGA", "NPL"))
saveRDS(calib, "data/processed/calibration.rds")
