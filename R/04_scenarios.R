# =============================================================================
# 04_scenarios.R
# Project 2025-2035 under five scenarios (interventions start 2027, 2-year scale-up)
# for every retained calibration draw; summarise median and 95% interval.
# =============================================================================
suppressPackageStartupMessages({ library(dplyr); library(parallel) })
source("app/model_functions.R")

calib <- readRDS("data/processed/calibration.rds")
burden <- readRDS("data/processed/who_burden_uga_npl.rds")
pop24 <- burden |> filter(year == 2024) |> select(iso3, pop)
scens <- scenario_list()

run_draws <- function(iso) {
  draws <- c(list(calib[[iso]]$point), calib[[iso]]$draws)
  res <- mclapply(seq_along(draws), function(i) {
    do.call(rbind, lapply(names(scens), function(s) {
      r <- run_tb(draws[[i]], to = 2035, scen = scens[[s]])
      data.frame(iso3 = iso, draw = i - 1, scenario = s, year = r$time,
                 incidence = r$incidence, notifications = r$notifications, deaths = r$deaths)
    }))
  }, mc.cores = max(1, detectCores() - 1))
  do.call(rbind, res)
}

traj <- bind_rows(lapply(c("UGA", "NPL"), run_draws))

summ <- traj |> filter(draw > 0) |>
  group_by(iso3, scenario, year) |>
  summarise(across(c(incidence, notifications, deaths), list(med = median, lo = ~quantile(.x, 0.025), hi = ~quantile(.x, 0.975))),
            .groups = "drop")

# cumulative cases and deaths averted 2027-2035 vs baseline, scaled to 2024 population
base <- traj |> filter(scenario == "Baseline (current trends)") |>
  select(iso3, draw, year, inc0 = incidence, dth0 = deaths)
averted <- traj |> filter(year >= 2027, year <= 2035, draw > 0) |>
  left_join(base, by = c("iso3", "draw", "year")) |>
  left_join(pop24, by = "iso3") |>
  group_by(iso3, scenario, draw) |>
  summarise(cases_averted = sum((inc0 - incidence) * pop / 1e5),
            deaths_averted = sum((dth0 - deaths) * pop / 1e5), .groups = "drop") |>
  group_by(iso3, scenario) |>
  summarise(across(c(cases_averted, deaths_averted), list(med = median, lo = ~quantile(.x, 0.025), hi = ~quantile(.x, 0.975))),
            .groups = "drop")

# End TB Strategy check: reduction in 2030 and 2035 vs 2015 (model, median draw)
endtb <- traj |> filter(draw > 0, year %in% c(2015, 2030, 2035)) |>
  group_by(iso3, scenario, draw) |>
  summarise(inc_red_2030 = 1 - incidence[year == 2030] / incidence[year == 2015],
            dth_red_2030 = 1 - deaths[year == 2030] / deaths[year == 2015],
            inc_red_2035 = 1 - incidence[year == 2035] / incidence[year == 2015],
            dth_red_2035 = 1 - deaths[year == 2035] / deaths[year == 2015], .groups = "drop") |>
  group_by(iso3, scenario) |> summarise(across(starts_with(c("inc", "dth")), median), .groups = "drop")

saveRDS(list(summary = summ, averted = averted, endtb = endtb), "data/processed/scenario_results.rds")
write.csv(averted, "data/processed/cases_deaths_averted.csv", row.names = FALSE)
print(averted, width = 200)
print(endtb, width = 200)
