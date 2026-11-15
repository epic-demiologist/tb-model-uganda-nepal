# =============================================================================
# model_functions.R
# Shared functions: (1) diagnostic cascade model, (2) TB transmission model.
# Sourced by the analysis scripts in R/ and by the Shiny app.
# Author: Bikram Kumar Singh
# =============================================================================

suppressPackageStartupMessages(library(deSolve))

# -----------------------------------------------------------------------------
# 1. DIAGNOSTIC CASCADE MODEL (static, decision-tree style)
# -----------------------------------------------------------------------------
# Follows a cohort of people with presumptive TB through:
#   sample obtained -> test positive (true or false) -> treatment started
# Default inputs come from published studies (see app/methods.md):
#   * Sputum production ~85% vs tongue swab 100% (four-country yield study, CID 2026)
#   * Tongue swab sensitivity ~66% vs culture (eight-country study, Lancet Microbe 2026)
#   * Xpert Ultra on sputum sensitivity ~90%, specificity ~96-98% (Cochrane reviews)
#   * Linkage to treatment is higher with same-day results (assumption, varied in SA)

cascade_defaults <- list(
  n = 1000,            # people with presumptive TB evaluated
  prev = 0.10,         # TB prevalence among them
  # strategy A: sputum, Xpert Ultra (laboratory)
  A_sample = 0.85, A_sens = 0.90, A_spec = 0.98, A_link = 0.85,
  # strategy B: tongue swab, near-point-of-care NAAT (same day)
  B_sample = 1.00, B_sens = 0.66, B_spec = 0.985, B_link = 0.95,
  # strategy C: pooled sputum testing (laboratory, faster turnaround)
  C_sample = 0.85, C_sens = 0.87, C_spec = 0.98, C_link = 0.88
)

cascade_one <- function(n, prev, sample, sens, spec, link) {
  tb <- n * prev; notb <- n - tb
  tested_tb <- tb * sample; tested_notb <- notb * sample
  tp <- tested_tb * sens; fp <- tested_notb * (1 - spec)
  data.frame(
    with_tb = tb, sample_obtained = n * sample, true_pos = tp, false_pos = fp,
    tb_started = tp * link, false_started = fp * link,
    tb_missed = tb - tp * link,
    yield_pct = 100 * (tp + fp) / n,                    # positives among ALL evaluated
    prob_tb_treated = tp * link / tb                    # P(person with TB starts treatment)
  )
}

cascade_model <- function(p = cascade_defaults) {
  out <- rbind(
    cbind(strategy = "Sputum Xpert Ultra (lab)", cascade_one(p$n, p$prev, p$A_sample, p$A_sens, p$A_spec, p$A_link)),
    cbind(strategy = "Tongue swab, near-POC test", cascade_one(p$n, p$prev, p$B_sample, p$B_sens, p$B_spec, p$B_link)),
    cbind(strategy = "Pooled sputum (lab)", cascade_one(p$n, p$prev, p$C_sample, p$C_sens, p$C_spec, p$C_link))
  )
  out
}

# One-way sensitivity analysis: difference (swab - sputum) in people with TB started on treatment
cascade_tornado <- function(p = cascade_defaults, rel = 0.15) {
  base <- function(pp) { r <- cascade_model(pp); r$tb_started[2] - r$tb_started[1] }
  b0 <- base(p)
  vars <- c(prev = "TB prevalence", A_sample = "Sputum: sample obtained", A_sens = "Sputum: sensitivity",
            A_link = "Sputum: linkage to treatment", B_sample = "Swab: sample obtained",
            B_sens = "Swab: sensitivity", B_link = "Swab: linkage to treatment")
  res <- lapply(names(vars), function(v) {
    lo <- p; hi <- p
    lo[[v]] <- max(0, p[[v]] * (1 - rel)); hi[[v]] <- min(1, p[[v]] * (1 + rel))
    data.frame(parameter = vars[[v]], low = base(lo), high = base(hi))
  })
  res <- do.call(rbind, res)
  res$range <- abs(res$high - res$low)
  res$base <- b0
  res[order(res$range), ]
}

# -----------------------------------------------------------------------------
# 2. TB TRANSMISSION MODEL (deterministic compartmental ODE, per 100,000 people)
# -----------------------------------------------------------------------------
# Compartments
#   S   susceptible (never infected)
#   Lf  recent ("fast") latent infection      -> high progression risk for ~2 years
#   Ls  remote ("slow") latent infection      -> low reactivation risk
#   P   protected after TB preventive therapy  (like Ls, but no reactivation)
#   I   active TB, not yet diagnosed (infectious)
#   T   on treatment (assumed non-infectious)
#   R   recovered / treated (can relapse or be reinfected)
# Population is closed and constant: deaths (background + TB) are replaced by births into S.
#
# Time-varying case detection rate delta(t): constant before 2015, linear change
# 2015 -> 2024, constant afterwards (baseline). Interventions start in 2027.

tb_fixed <- function(country = c("UGA", "NPL")) {
  country <- match.arg(country)
  base <- list(
    eps   = 0.0435,  # Lf -> I  (gives ~8% lifetime progression from recent infection)
    kappa = 0.50,    # Lf -> Ls (average 2 years in recent latent state)
    nu    = 0.0006,  # Ls -> I  reactivation rate per year (Ragonnet et al. 2017)
    x     = 0.79,    # protection against reinfection for Ls, P, R (Andrews et al. 2012)
    cure  = 0.15,    # self-cure rate of untreated TB per year (Tiemersma et al. 2011)
    rho   = 0.008,   # relapse rate from R per year
    tx    = 2.0,     # treatment exit rate per year (6-month regimen)
    tpt_eff = 0.80   # efficacy of completed 3HP against progression
  )
  if (country == "UGA") {
    c(base, list(country = "Uganda", mu = 1 / 63, hiv_prev = 0.05, h_tb = 0.33, irr = 15, tsr = 0.92))
  } else {
    c(base, list(country = "Nepal", mu = 1 / 71, hiv_prev = 0.001, h_tb = 0.006, irr = 15, tsr = 0.92))
  }
}

delta_t <- function(t, p) {
  if (t < 2015) return(p$d15)
  if (t <= 2024) return(p$d15 + (p$d24 - p$d15) * (t - 2015) / 9)
  p$d24
}

ramp <- function(t, start = 2027, years = 2) pmin(1, pmax(0, (t - start) / years))

tb_ode <- function(t, y, p) {
  with(as.list(c(y, p)), {
    N <- S + Lf + Ls + P + I + T + R
    prog <- 1 + hiv_prev * (irr - 1)                # HIV raises progression/reactivation
    muI  <- (1 - h_tb) * 0.15 + h_tb * 0.60         # untreated TB mortality (HIV-/HIV+)
    muT  <- (1 - tsr) * tx * 0.4                    # deaths during treatment
    failT <- (1 - tsr) * tx * 0.6                   # failure / loss to follow-up -> back to I
    lam  <- beta * I / N                            # force of infection
    d    <- delta_t(t, p)
    # interventions (from 2027, 2-year scale-up)
    acf  <- acf_cov * acf_prob * ramp(t)            # extra detection from community case finding
    tpt  <- tpt_cov * tpt_comp * tpt_eff * ramp(t)  # recent infections protected by TPT per year
    tbdeaths <- muI * I + muT * T
    births <- mu * N + tbdeaths
    dS  <- births - lam * S - mu * S
    dLf <- lam * (S + (1 - x) * (Ls + P + R)) - (eps * prog + kappa + tpt + mu) * Lf
    dLs <- kappa * Lf - (nu * prog + lam * (1 - x) + mu) * Ls
    dP  <- tpt * Lf - (lam * (1 - x) + mu) * P
    dI  <- eps * prog * Lf + nu * prog * Ls + rho * R + failT * T - (d + acf + cure + muI + mu) * I
    dT  <- (d + acf) * I - (tx * tsr + muT + failT + mu) * T
    dR  <- tx * tsr * T + cure * I - (rho + lam * (1 - x) + mu) * R
    inc  <- eps * prog * Lf + nu * prog * Ls + rho * R   # incident TB (new + relapse)
    list(c(dS, dLf, dLs, dP, dI, dT, dR),
         incidence = inc, notifications = (d + acf) * I, deaths = tbdeaths)
  })
}

tb_init <- function() c(S = 60000, Lf = 1000, Ls = 38000, P = 0, I = 300, T = 100, R = 600)

# Run the model from 1900 (burn-in at constant delta) to `to`
run_tb <- function(p, to = 2035, scen = list(acf_cov = 0, acf_prob = 0, tpt_cov = 0, tpt_comp = 0)) {
  pp <- c(p, scen)
  times <- seq(1900, to, by = 1)
  out <- ode(y = tb_init(), times = times, func = tb_ode, parms = pp, method = "lsoda")
  out <- as.data.frame(out)
  out[out$time >= 2010, ]
}

# Weighted least-squares objective on log scale: WHO incidence and notification rates 2015-2024
calib_obj <- function(par, pars, target) {
  p <- pars
  p$beta <- exp(par[1]); p$d15 <- exp(par[2]); p$d24 <- exp(par[2] + par[3])
  r <- tryCatch(suppressWarnings(run_tb(p, to = 2024)), error = function(e) NULL)
  if (is.null(r) || any(!is.finite(r$incidence))) return(1e6)
  m <- merge(r, target, by.x = "time", by.y = "year")
  if (any(m$incidence <= 0) || any(m$notifications <= 0)) return(1e6)
  # Weighted on the log scale: notifications are observed counts (log-SD 0.10),
  # WHO incidence is itself a modelled estimate with wide uncertainty (log-SD 0.20).
  # In Uganda, WHO's flat incidence and the steep rise in notifications cannot both be
  # matched by a transmission model (more detection -> less transmission); see README.
  v <- sum(((log(m$incidence) - log(m$inc_100k)) / 0.20)^2) +
       sum(((log(m$notifications) - log(m$notif_100k)) / 0.10)^2)
  if (!is.finite(v)) 1e6 else v
}

# Starting values: detection rates implied by WHO case detection ratios,
# CDR = d / (d + cure + muI + mu)  =>  d = CDR * (cure + muI + mu) / (1 - CDR)
start_values <- function(p, target) {
  muI <- (1 - p$h_tb) * 0.15 + p$h_tb * 0.60
  exit <- p$cure + muI + p$mu
  cdr <- pmin(target$cdr / 100, 0.95)
  d <- cdr * exit / (1 - cdr)
  d15 <- d[target$year == 2015]; d24 <- d[target$year == 2024]
  c(log(10), log(d15), max(0.01, log(d24 / d15)))
}

calibrate <- function(p, target, start = start_values(p, target)) {
  # parameters: log(beta), log(d2015), log(d2024/d2015) >= 0 (detection does not fall)
  f <- optim(start, calib_obj, pars = p, target = target, method = "L-BFGS-B",
             lower = c(log(2), log(0.05), 0), upper = c(log(60), log(5), 3))
  p$beta <- exp(f$par[1]); p$d15 <- exp(f$par[2]); p$d24 <- exp(f$par[2] + f$par[3])
  p$sse <- f$value
  p
}

scenario_list <- function(acf_cov = 0.10, tpt_cov = 0.30, tpt_comp = 0.92,
                          prob_swab = NULL, prob_sputum = NULL) {
  cm <- cascade_model()
  if (is.null(prob_sputum)) prob_sputum <- cm$prob_tb_treated[1]
  if (is.null(prob_swab))   prob_swab   <- cm$prob_tb_treated[2]
  list(
    "Baseline (current trends)"          = list(acf_cov = 0, acf_prob = 0, tpt_cov = 0, tpt_comp = 0),
    "Community screening, sputum Xpert"  = list(acf_cov = acf_cov, acf_prob = prob_sputum, tpt_cov = 0, tpt_comp = 0),
    "Community screening, tongue swab"   = list(acf_cov = acf_cov, acf_prob = prob_swab, tpt_cov = 0, tpt_comp = 0),
    "3HP preventive therapy scale-up"    = list(acf_cov = 0, acf_prob = 0, tpt_cov = tpt_cov, tpt_comp = tpt_comp),
    "Tongue swab screening + 3HP"        = list(acf_cov = acf_cov, acf_prob = prob_swab, tpt_cov = tpt_cov, tpt_comp = tpt_comp)
  )
}
