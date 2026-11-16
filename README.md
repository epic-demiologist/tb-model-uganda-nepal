# TB diagnosis & prevention models — Uganda and Nepal

An R project and Shiny dashboard exploring how **tongue-swab testing**, **community screening** and **short-course TB preventive therapy (3HP)** could change tuberculosis outcomes in Uganda and Nepal.

> Learning project by **Bikram Kumar Singh** (MSc Epidemiology, Advanced Biostatistics, LMU Munich). Simplified models built from open WHO data and published estimates, intended for discussion and not for policy decisions.

**Live dashboard:** `   **Live dashboard:** https://bikramsingh.shinyapps.io/tb-models/` 

## What is inside

| Component | Question | Method |
|---|---|---|
| 1. TB burden | How have incidence, notifications, mortality and TPT changed in Uganda and Nepal? | WHO Global TB Programme data, 2000–2024 |
| 2. Diagnostic cascade | Per 1,000 people with presumptive TB, how many with TB start treatment with sputum Xpert Ultra, tongue swab near-POC testing or pooled sputum? | Decision tree + one-way sensitivity analysis (tornado) |
| 3. Transmission model | How much could community screening (sputum vs swab) and 3HP scale-up reduce incidence and deaths by 2035? | Compartmental ODE model (`deSolve`), calibrated to WHO incidence and notifications 2015–2024, Latin hypercube uncertainty |
| 4. Dashboard | Interactive exploration, including a live model run | Shiny + bslib + plotly |

## Repository structure

```
tb-model-uganda-nepal/
├── run_all.R                 # reproduces everything (≈20–30 min)
├── R/
│   ├── 01_prepare_data.R     # WHO data → tidy tables, calibration targets
│   ├── 02_cascade_model.R    # diagnostic cascade + tornado
│   ├── 03_calibrate.R        # model calibration with parameter uncertainty
│   └── 04_scenarios.R        # projections 2027–2035, cases/deaths averted
├── app/
│   ├── app.R                 # Shiny dashboard
│   ├── model_functions.R     # cascade + transmission model (shared)
│   ├── methods.md            # methods, parameters, limitations, references
│   └── data/                 # processed results used by the app
├── data/
│   ├── raw/                  # WHO CSV files (downloaded 15 Nov 2026)
│   └── processed/            # outputs of R/ scripts
└── deploy.R                  # deploy to shinyapps.io
```

## Run it

```r
# R >= 4.2
install.packages(c("deSolve", "dplyr", "tidyr", "readr", "lhs", "ggplot2",
                   "plotly", "DT", "shiny", "bslib", "markdown", "scales", "rsconnect"))
source("run_all.R")          # optional: re-runs data prep, calibration and scenarios
shiny::runApp("app")         # launch the dashboard (uses precomputed results in app/data)
```

## Deploy to shinyapps.io

1. Create a free account at <https://www.shinyapps.io>, then go to **Account → Tokens → Show** and copy the `rsconnect::setAccountInfo(...)` command.
2. Run that command once in R.
3. Run `source("deploy.R")`. The app is published as `tb-models`.

## Key findings (point estimates; see the dashboard for uncertainty)

- **Diagnostic cascade:** with published inputs, tongue swab testing starts almost as many people with TB on treatment as sputum Xpert Ultra (about 63 vs 65 per 1,000 evaluated at 10% prevalence). Lower sensitivity is largely offset by universal sample collection and same-day results. The balance depends most on sputum availability, swab sensitivity and linkage to care.
- **Transmission model:** see the *Transmission model* tab for cases and deaths averted 2027–2035 under each scenario.
- **A calibration puzzle (Uganda):** WHO's incidence estimate is nearly flat, while notifications rose by about 60% in 2015–2024. A transmission model cannot reproduce both, because finding more cases reduces transmission. This raises a question worth discussing: how much of the rise reflects better detection rather than higher true incidence?

## Data sources and references

- WHO Global Tuberculosis Programme, TB data: <https://www.who.int/teams/global-programme-on-tuberculosis-and-lung-health/data>
- Tongue swab vs sputum diagnostic yield, *Clin Infect Dis* 2026 (PMID 41804811); multicountry tongue swab Xpert Ultra study, *Lancet Microbe* 2026 (PMID 42134368); TB screening test accuracy, *Clin Infect Dis* 2026 (PMID 39509711).
- 3HP Options trial (NIH R01HL144406); Sterling TR et al., *N Engl J Med* 2011.
- Ragonnet R et al., *Epidemics* 2017; Andrews JR et al., *Clin Infect Dis* 2012; Tiemersma EW et al., *PLoS One* 2011; Menzies NA et al., *N Engl J Med* 2018.

Full parameter table and limitations: [`app/methods.md`](app/methods.md).

## License

Code: MIT. WHO data are subject to WHO's terms of use.
