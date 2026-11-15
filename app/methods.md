### Purpose

A learning project to explore two questions from recent TB diagnostics and prevention research:

1. When can a less sensitive, but universally collectable, sample (tongue swab) find as many people with TB as sputum?
2. How much could better community case finding and short-course preventive therapy (3HP) change TB incidence in Uganda and Nepal by 2035?

The models are simplified and use published estimates. They are meant for discussion, not for policy decisions.

### Data

WHO Global TB Programme database (estimates, notifications, treatment outcomes, contact screening and TPT), downloaded 15 November 2026 from the WHO TB data portal. Incidence and mortality are WHO model estimates with 95% uncertainty intervals. Notifications are new and relapse cases (`c_newinc`), converted to rates with the WHO population estimate.

### 1. Diagnostic cascade model

A decision tree for 1,000 people with presumptive TB: sample obtained → test positive (true or false) → treatment started.

| Input | Sputum Xpert Ultra | Tongue swab, near-POC | Pooled sputum | Source |
|---|---|---|---|---|
| Sample obtained | 0.85 | 1.00 | 0.85 | Four-country diagnostic-yield study (Clin Infect Dis 2026): all participants gave a swab, 84.7% produced sputum |
| Sensitivity vs culture | 0.90 | 0.66 | 0.87 | Xpert Ultra (Cochrane); tongue swab 65.6% (Lancet Microbe 2026); pooling assumed slightly lower |
| Specificity | 0.98 | 0.985 | 0.98 | Lancet Microbe 2026 (swab 98.5%); Cochrane (Ultra) |
| Treatment started if positive | 0.85 | 0.95 | 0.88 | **Assumption**: same-day results reduce pre-treatment loss to follow-up |

Main output: people *with TB* started on treatment, and diagnostic yield (positives among everyone evaluated). The tornado plot varies each input ±15%.

### 2. TB transmission model

Deterministic compartmental model (R, `deSolve`) per 100,000 people: susceptible (S), recent latent (L fast), remote latent (L slow), protected after TPT (P), active TB (I), on treatment (T), recovered (R). Closed population; deaths are replaced by births.

| Parameter | Value (range sampled) | Source |
|---|---|---|
| Progression from recent infection | 0.0435/yr (0.03–0.06), ~8% lifetime | Ragonnet et al. 2017; Menzies et al. 2018 |
| Recent → remote latency | 0.5/yr (2 years) | Ragonnet et al. 2017 |
| Reactivation | 0.0006/yr (0.0003–0.001) | Ragonnet et al. 2017 |
| Protection against reinfection | 0.79 (0.6–0.9) | Andrews et al. 2012 |
| Self-cure, untreated | 0.15/yr (0.1–0.2) | Tiemersma et al. 2011 |
| TB mortality, untreated | 0.15/yr HIV-negative, 0.6/yr HIV-positive | Tiemersma et al. 2011; Dye et al. |
| Relapse after treatment | 0.008/yr (0.004–0.015) | Literature range |
| HIV: progression rate ratio | 15 (10–20); adult HIV prevalence 5% Uganda, 0.1% Nepal | WHO; UNAIDS |
| Treatment success | 92% | WHO outcomes data, 2023 cohort |
| 3HP efficacy among completers | 0.8 (0.7–0.9) | Sterling et al. 2011 |
| 3HP completion | 0.92 | 3HP Options trial, facilitated self-administered therapy |

**Calibration.** The transmission rate (beta) and the case detection rates in 2015 and 2024 (linear change in between) were fitted by weighted least squares on the log scale to WHO incidence (weight log-SD 0.20, because it is itself an estimate) and notification rates (log-SD 0.10), 2015–2024. Detection was constrained not to fall. Uncertainty: 60 Latin hypercube draws over the natural-history parameters, each re-calibrated; draws that fit about as well as the point estimate were kept.

**Scenarios (from 2027, 2-year scale-up).** Baseline: detection stays at the 2024 level. Community screening: 10% of people with undiagnosed TB reached per year, multiplied by the probability of starting treatment from the cascade model. 3HP: 30% of recent infections reached per year × completion × efficacy. Combined: swab screening + 3HP.

### Limitations

- In **Uganda**, WHO estimates incidence as roughly flat (≈200/100k) while notifications rose by about 60% between 2015 and 2024. A transmission model cannot reproduce both, because finding more cases reduces transmission. The fit is a compromise and projected declines should be read with this in mind. This is a useful question in itself: how much of the notification rise reflects better detection versus higher true incidence?
- No age structure, no drug resistance, no explicit HIV/ART dynamics, no subclinical TB compartment.
- Community screening is represented as an extra detection rate; it ignores the screening test before confirmatory testing (e.g. chest X-ray with CAD).
- Linkage to treatment for same-day testing is an assumption.
- TPT reach is expressed as a share of recent infections, not as numbers of contacts or people with HIV.

### Reproducibility

All code and data are in the GitHub repository. `run_all.R` reproduces every output; the dashboard is in `app/`.

### Key references

- Diagnostic yield of tongue swab vs sputum molecular testing in four high-burden countries. *Clin Infect Dis* 2026 (PMID 41804811).
- Multicountry tongue swab Xpert Ultra accuracy study. *Lancet Microbe* 2026 (PMID 42134368).
- Accuracy of TB screening tests in a prospective multinational cohort. *Clin Infect Dis* 2026 (PMID 39509711).
- 3HP Options trial (NIH R01HL144406); Sterling et al. *N Engl J Med* 2011 (3HP efficacy).
- Ragonnet R et al. *Epidemics* 2017; Andrews JR et al. *Clin Infect Dis* 2012; Tiemersma EW et al. *PLoS One* 2011; Menzies NA et al. *N Engl J Med* 2018.
- WHO. *Global Tuberculosis Report 2025*; WHO consolidated guidelines on TB (Modules 1–4).
