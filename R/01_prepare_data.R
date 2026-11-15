# =============================================================================
# 01_prepare_data.R
# Read WHO Global TB Programme data (downloaded 15 Nov 2026) and build tidy
# country-year tables for Uganda (UGA) and Nepal (NPL).
# Source: https://www.who.int/teams/global-programme-on-tuberculosis-and-lung-health/data
# =============================================================================
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })

countries <- c("UGA", "NPL")
raw <- "data/raw"

est <- read_csv(file.path(raw, "who_estimates.csv"), show_col_types = FALSE) |>
  filter(iso3 %in% countries) |>
  select(iso3, country, year, pop = e_pop_num,
         inc_100k = e_inc_100k, inc_lo = e_inc_100k_lo, inc_hi = e_inc_100k_hi,
         mort_100k = e_mort_100k, mort_lo = e_mort_100k_lo, mort_hi = e_mort_100k_hi,
         tbhiv_pct = e_tbhiv_prct, cdr = c_cdr)

notif <- read_csv(file.path(raw, "who_notifications.csv"), show_col_types = FALSE) |>
  filter(iso3 %in% countries) |>
  select(iso3, year, c_newinc)

outc <- read_csv(file.path(raw, "who_outcomes.csv"), show_col_types = FALSE) |>
  filter(iso3 %in% countries) |>
  select(iso3, year, tsr_new = c_new_tsr)

tpt <- read_csv(file.path(raw, "who_contact_tpt.csv"), show_col_types = FALSE) |>
  filter(iso3 %in% countries) |>
  select(iso3, year, any_of(c("newinc_con", "newinc_con_screen", "newinc_con_prevtx", "newinc_con04_prevtx")))

burden <- est |>
  left_join(notif, by = c("iso3", "year")) |>
  left_join(outc, by = c("iso3", "year")) |>
  left_join(tpt, by = c("iso3", "year")) |>
  mutate(notif_100k = 1e5 * c_newinc / pop) |>
  arrange(iso3, year)

dir.create("data/processed", showWarnings = FALSE)
write_csv(burden, "data/processed/who_burden_uga_npl.csv")
saveRDS(burden, "data/processed/who_burden_uga_npl.rds")

targets <- burden |> filter(year >= 2015, year <= 2024) |>
  select(iso3, year, inc_100k, notif_100k, cdr)
saveRDS(targets, "data/processed/calibration_targets.rds")

message("Saved ", nrow(burden), " country-years to data/processed/")
print(targets |> group_by(iso3) |> summarise(across(c(inc_100k, notif_100k), list(first = first, last = last))))
