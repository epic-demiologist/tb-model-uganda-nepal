# =============================================================================
# TB diagnosis & prevention modelling dashboard — Uganda and Nepal
# Author: Bikram Kumar Singh  |  Data: WHO Global TB Programme (2025 release)
# Run locally: shiny::runApp("app")   Deploy: rsconnect::deployApp("app")
# =============================================================================
suppressPackageStartupMessages({
  library(shiny); library(bslib); library(ggplot2); library(dplyr); library(tidyr); library(plotly); library(DT)
})
source("model_functions.R")

burden <- readRDS("data/who_burden_uga_npl.rds")
calib  <- readRDS("data/calibration.rds")
scen   <- readRDS("data/scenario_results.rds")
cnames <- c(UGA = "Uganda", NPL = "Nepal")
pal <- c("Baseline (current trends)" = "#6B7280", "Community screening, sputum Xpert" = "#2E86AB",
         "Community screening, tongue swab" = "#E07A1F", "3HP preventive therapy scale-up" = "#3C9D5D",
         "Tongue swab screening + 3HP" = "#8E44AD")
theme_set(theme_minimal(base_size = 13) + theme(legend.position = "bottom", panel.grid.minor = element_blank()))
fmt <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = ",")

# ---------------------------------------------------------------- UI
card_note <- function(...) tags$p(class = "text-muted small mb-0", ...)

ui <- page_navbar(
  fillable = FALSE,
  title = "TB diagnosis & prevention models · Uganda and Nepal",
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#1F3864"),
  sidebar = sidebar(width = 260,
    selectInput("iso", "Country", choices = c(Uganda = "UGA", Nepal = "NPL")),
    card_note("Data: WHO Global TB Programme database, downloaded 15 Nov 2026. Model inputs from published studies; see Methods."),
    hr(),
    card_note("Built by Bikram Kumar Singh (MSc Epidemiology, LMU Munich) as a learning project. Simplified models for discussion, not policy advice.")
  ),

  nav_panel("Overview",
    layout_columns(col_widths = c(3, 3, 3, 3), fill = FALSE,
      value_box("Estimated incidence 2024", textOutput("vb_inc"), p(textOutput("vb_inc_ci", inline = TRUE)), theme = "primary"),
      value_box("Notified cases 2024", textOutput("vb_not"), p(textOutput("vb_cdr", inline = TRUE)), theme = "secondary"),
      value_box("Estimated TB deaths 2024", textOutput("vb_mort"), p("per 100,000 (WHO)"), theme = "danger"),
      value_box("Cases averted 2027–35", textOutput("vb_avert"), p(textOutput("vb_avert_ci", inline = TRUE)), theme = "success")
    ),
    layout_columns(col_widths = c(7, 5),
      card(card_header("What this dashboard does"),
        tags$ol(
          tags$li(tags$b("TB burden: "), "WHO estimates and notifications for Uganda and Nepal, 2000–2024."),
          tags$li(tags$b("Diagnostic cascade: "), "how many people with TB start treatment per 1,000 evaluated when testing sputum with Xpert Ultra, tongue swabs with a near-point-of-care test, or pooled sputum. Defaults come from recent multicountry tongue-swab studies (Clin Infect Dis 2026; Lancet Microbe 2026)."),
          tags$li(tags$b("Transmission model: "), "a compartmental TB model calibrated to WHO incidence and notification rates (2015–2024), projecting 2027–2035 with community screening, 3HP preventive therapy (completion from the 3HP Options trial), or both."),
          tags$li(tags$b("Calibration & methods: "), "model fit, assumptions, parameters, limitations and sources.")
        ),
        card_note("Questions I wanted to explore: when does a less sensitive but universally collectable sample find as many people with TB as sputum? How much could better case finding and short-course preventive therapy change incidence by 2035?")
      ),
      card(card_header("Model structure"), uiOutput("diagram"))
    )
  ),

  nav_panel("TB burden",
    layout_columns(col_widths = c(6, 6),
      card(card_header("Incidence (WHO estimate, 95% UI) and notifications per 100,000"), plotlyOutput("p_inc", height = 340)),
      card(card_header("TB mortality per 100,000 (WHO estimate, 95% UI)"), plotlyOutput("p_mort", height = 340)),
      card(card_header("Case detection ratio and treatment success (%)"), plotlyOutput("p_cdr", height = 300)),
      card(card_header("Household contacts given TB preventive treatment"), plotlyOutput("p_tpt", height = 300),
           card_note("WHO field newinc_con_prevtx (all ages) where reported; otherwise children under 5 (newinc_con04_prevtx)."))
    )
  ),

  nav_panel("Diagnostic cascade",
    layout_sidebar(
      sidebar = sidebar(width = 300, position = "right", title = "Inputs",
        sliderInput("prev", "TB prevalence among people evaluated", 0.01, 0.30, 0.10, 0.01),
        tags$b("Sputum, Xpert Ultra (lab)"),
        sliderInput("A_sample", "Can produce sputum", 0.5, 1, 0.85, 0.01),
        sliderInput("A_sens", "Sensitivity", 0.5, 1, 0.90, 0.01),
        sliderInput("A_link", "Started on treatment if positive", 0.5, 1, 0.85, 0.01),
        tags$b("Tongue swab, near-POC test"),
        sliderInput("B_sample", "Can give a swab", 0.5, 1, 1.00, 0.01),
        sliderInput("B_sens", "Sensitivity", 0.3, 1, 0.66, 0.01),
        sliderInput("B_link", "Started on treatment if positive (same day)", 0.5, 1, 0.95, 0.01),
        tags$b("Pooled sputum (lab)"),
        sliderInput("C_sens", "Sensitivity", 0.5, 1, 0.87, 0.01),
        actionButton("reset", "Reset to published defaults", class = "btn-sm btn-outline-primary")
      ),
      layout_columns(col_widths = c(12, 7, 5),
        card(card_header("Per 1,000 people with presumptive TB"), uiOutput("casc_text"), plotlyOutput("p_casc", height = 330)),
        card(card_header("Results table"), DTOutput("t_casc")),
        card(card_header("What drives the swab vs sputum difference? (±15% one-way)"), plotOutput("p_torn", height = 300),
             card_note("Bars show the change in (swab − sputum) people with TB started on treatment per 1,000."))
      )
    )
  ),

  nav_panel("Transmission model",
    layout_columns(col_widths = c(8, 4),
      card(card_header("TB incidence per 100,000 under five scenarios (median and 95% interval across calibrated parameter sets)"),
           plotlyOutput("p_scen", height = 470),
           card_note("Interventions start in 2027 and scale up over two years. Dashed lines: End TB Strategy milestones (incidence −50% by 2025, −80% by 2030 vs 2015).")),
      card(card_header("Scenario assumptions"),
        tags$ul(
          tags$li(tags$b("Community screening: "), "10% of people with undiagnosed TB reached per year by active case finding; probability of starting treatment from the diagnostic cascade (sputum vs tongue swab)."),
          tags$li(tags$b("3HP scale-up: "), "30% of recent infections (household contacts, people with HIV) reached per year; 92% completion (facilitated self-administered therapy, 3HP Options trial); 70–90% efficacy."),
          tags$li(tags$b("Baseline: "), "case detection stays at the calibrated 2024 level.")
        ))
    ),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Cases and deaths averted, 2027–2035 (national, vs baseline)"), DTOutput("t_avert")),
      card(card_header("TB deaths per 100,000"), plotlyOutput("p_deaths", height = 300))
    ),
    card(card_header("Explore: run the model live (point estimate)"),
      layout_columns(col_widths = c(3, 9),
        div(
          sliderInput("acf", "Undiagnosed TB reached by screening per year", 0, 0.5, 0.10, 0.01),
          radioButtons("acf_test", "Screening test", c("Tongue swab (near-POC)" = "swab", "Sputum Xpert" = "sputum"), inline = FALSE),
          sliderInput("tptc", "Recent infections reached by TPT per year", 0, 0.8, 0.30, 0.05),
          sliderInput("tptcomp", "3HP completion", 0.4, 1, 0.92, 0.01)
        ),
        div(plotlyOutput("p_live", height = 320), uiOutput("live_text"))
      )
    )
  ),

  nav_panel("Calibration",
    layout_columns(col_widths = c(6, 6),
      card(card_header("Model fit: incidence per 100,000"), plotlyOutput("p_fit_inc", height = 330)),
      card(card_header("Model fit: notifications per 100,000"), plotlyOutput("p_fit_not", height = 330))
    ),
    card(card_header("Calibrated parameters (point estimate)"),
         card_note("beta: effective contacts per infectious person per year; d2015/d2024: case detection rates per year. Uncertain natural-history parameters were sampled by Latin hypercube; draws fitting about as well as the point estimate were retained."), DTOutput("t_par"))
  ),

  nav_panel("Methods & sources", card(card_body(includeMarkdown("methods.md"))))
)

# ---------------------------------------------------------------- server
server <- function(input, output, session) {
  b  <- reactive(burden |> filter(iso3 == input$iso))
  b24 <- reactive(b() |> filter(year == 2024))

  output$vb_inc <- renderText(paste0(b24()$inc_100k, " /100k"))
  output$vb_inc_ci <- renderText(paste0("95% UI ", b24()$inc_lo, " to ", b24()$inc_hi, " (WHO)"))
  output$vb_not <- renderText(fmt(b24()$c_newinc))
  output$vb_cdr <- renderText(paste0("case detection ratio ", b24()$cdr, "%"))
  output$vb_mort <- renderText(paste0(b24()$mort_100k))
  output$vb_avert <- renderText({
    a <- scen$averted |> filter(iso3 == input$iso, scenario == "Tongue swab screening + 3HP")
    fmt(a$cases_averted_med)
  })
  output$vb_avert_ci <- renderText({
    a <- scen$averted |> filter(iso3 == input$iso, scenario == "Tongue swab screening + 3HP")
    paste0("95% interval ", fmt(a$cases_averted_lo), " to ", fmt(a$cases_averted_hi), "; swab screening + 3HP (model)")
  })

  output$diagram <- renderUI(HTML(paste0(
    '<svg viewBox="0 0 520 300" width="100%" role="img" aria-label="TB model compartments">',
    '<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0 0L10 5L0 10z" fill="#555"/></marker></defs>',
    '<style>.b{fill:#EAF1FB;stroke:#1F3864;stroke-width:1.2}.t{font:13px sans-serif;text-anchor:middle;fill:#111}.s{font:10.5px sans-serif;fill:#555;text-anchor:middle}.l{stroke:#555;stroke-width:1.2;fill:none;marker-end:url(#a)}</style>',
    '<rect class="b" x="10" y="120" width="70" height="40" rx="6"/><text class="t" x="45" y="145">S</text>',
    '<rect class="b" x="120" y="60" width="80" height="40" rx="6"/><text class="t" x="160" y="85">L fast</text>',
    '<rect class="b" x="120" y="180" width="80" height="40" rx="6"/><text class="t" x="160" y="205">L slow</text>',
    '<rect class="b" x="240" y="120" width="80" height="40" rx="6" style="fill:#FDEBD0;stroke:#C0392B"/><text class="t" x="280" y="145">I (active)</text>',
    '<rect class="b" x="360" y="120" width="70" height="40" rx="6"/><text class="t" x="395" y="145">T (treated)</text>',
    '<rect class="b" x="450" y="120" width="60" height="40" rx="6"/><text class="t" x="480" y="145">R</text>',
    '<rect class="b" x="240" y="20" width="80" height="34" rx="6" style="fill:#E8F6EC;stroke:#3C9D5D"/><text class="t" x="280" y="42">P (3HP)</text>',
    '<path class="l" d="M80 135 L120 85"/><text class="s" x="88" y="100">infection</text>',
    '<path class="l" d="M160 100 L160 180"/><text class="s" x="140" y="145">2 yrs</text>',
    '<path class="l" d="M200 80 L240 130"/><text class="s" x="232" y="100">fast</text>',
    '<path class="l" d="M200 200 L240 152"/><text class="s" x="232" y="190">reactivation</text>',
    '<path class="l" d="M200 70 L240 42"/><text class="s" x="212" y="48">TPT</text>',
    '<path class="l" d="M320 140 L360 140"/><text class="s" x="340" y="132">detection</text><text class="s" x="340" y="174">+ screening</text>',
    '<path class="l" d="M430 140 L450 140"/>',
    '<path class="l" d="M480 160 Q400 260 285 162"/><text class="s" x="400" y="248">relapse</text>',
    '<path class="l" d="M480 120 Q400 20 205 62"/><text class="s" x="400" y="28">reinfection (partial protection)</text>',
    '</svg><p class="text-muted small">Closed population per 100,000; deaths replaced by births into S. HIV raises progression (Uganda). Notifications = detected active TB.</p>')))

  # ---- burden
  output$p_inc <- renderPlotly({
    d <- b() |> filter(year >= 2000)
    g <- ggplot(d, aes(year)) + geom_ribbon(aes(ymin = inc_lo, ymax = inc_hi), fill = "#1F3864", alpha = .15) +
      geom_line(aes(y = inc_100k, colour = "Incidence (WHO estimate)"), linewidth = 1) +
      geom_line(aes(y = notif_100k, colour = "Notifications (reported)"), linewidth = 1) +
      geom_point(aes(y = notif_100k, colour = "Notifications (reported)"), size = 1.2) +
      scale_colour_manual(values = c("#1F3864", "#E07A1F"), name = NULL) + labs(x = NULL, y = "per 100,000")
    ggplotly(g) |> layout(legend = list(orientation = "h", y = -0.15))
  })
  output$p_mort <- renderPlotly({
    d <- b() |> filter(year >= 2000)
    ggplotly(ggplot(d, aes(year, mort_100k)) + geom_ribbon(aes(ymin = mort_lo, ymax = mort_hi), fill = "#C0392B", alpha = .15) +
      geom_line(colour = "#C0392B", linewidth = 1) + labs(x = NULL, y = "per 100,000"))
  })
  output$p_cdr <- renderPlotly({
    d <- b() |> filter(year >= 2010) |> select(year, `Case detection ratio` = cdr, `Treatment success (new)` = tsr_new) |>
      pivot_longer(-year) |> filter(!is.na(value))
    ggplotly(ggplot(d, aes(year, value, colour = name)) + geom_line(linewidth = 1) + geom_point(size = 1.2) +
      scale_colour_manual(values = c("#2E86AB", "#3C9D5D"), name = NULL) + labs(x = NULL, y = "%") + ylim(0, 100)) |>
      layout(legend = list(orientation = "h", y = -0.2))
  })
  output$p_tpt <- renderPlotly({
    d <- b() |> filter(year >= 2015) |>
      mutate(tpt = coalesce(newinc_con_prevtx, newinc_con04_prevtx),
             what = ifelse(is.na(newinc_con_prevtx), "children <5 only", "all ages")) |> filter(!is.na(tpt))
    ggplotly(ggplot(d, aes(year, tpt, fill = what)) + geom_col() + scale_fill_manual(values = c("all ages" = "#3C9D5D", "children <5 only" = "#A9D8B8"), name = NULL) +
      scale_y_continuous(labels = scales::comma) + scale_x_continuous(breaks = 2015:2024) + labs(x = NULL, y = "contacts")) |> layout(legend = list(orientation = "h", y = -0.2))
  })

  # ---- cascade
  observeEvent(input$reset, {
    d <- cascade_defaults
    for (k in c("prev", "A_sample", "A_sens", "A_link", "B_sample", "B_sens", "B_link", "C_sens")) updateSliderInput(session, k, value = d[[k]])
  })
  cpar <- reactive({
    p <- cascade_defaults
    for (k in c("prev", "A_sample", "A_sens", "A_link", "B_sample", "B_sens", "B_link", "C_sens")) p[[k]] <- input[[k]]
    p$C_sample <- input$A_sample
    p
  })
  casc <- reactive(cascade_model(cpar()))
  output$casc_text <- renderUI({
    r <- casc(); dlt <- r$tb_started[2] - r$tb_started[1]
    tags$p(HTML(sprintf("Of <b>%s</b> people with TB, sputum testing starts <b>%s</b> on treatment and tongue swab testing <b>%s</b> (difference <b>%+.1f</b>). Diagnostic yield: sputum %.1f%%, swab %.1f%%, pooled %.1f%%.",
      fmt(r$with_tb[1]), fmt(r$tb_started[1], 1), fmt(r$tb_started[2], 1), dlt, r$yield_pct[1], r$yield_pct[2], r$yield_pct[3])))
  })
  output$p_casc <- renderPlotly({
    r <- casc() |> transmute(strategy, `Sample obtained (all)` = sample_obtained, `True positives` = true_pos,
                             `People with TB started on treatment` = tb_started, `People with TB missed` = tb_missed) |>
      pivot_longer(-strategy) |>
      mutate(name = factor(name, levels = c("Sample obtained (all)", "True positives", "People with TB started on treatment", "People with TB missed")))
    g <- ggplot(r, aes(name, value, fill = strategy)) + geom_col(position = position_dodge(.8), width = .75) +
      scale_fill_manual(values = c("Sputum Xpert Ultra (lab)" = "#2E86AB", "Pooled sputum (lab)" = "#9B59B6", "Tongue swab, near-POC test" = "#E07A1F"), name = NULL) + labs(x = NULL, y = "people") +
      facet_wrap(~ name, scales = "free", nrow = 1, labeller = label_wrap_gen(18)) + theme(axis.text.x = element_blank())
    ggplotly(g) |> layout(legend = list(orientation = "h", y = -0.1))
  })
  output$t_casc <- renderDT({
    r <- casc() |> transmute(Strategy = strategy, `Sample obtained` = round(sample_obtained), `True positive` = round(true_pos, 1),
                             `False positive` = round(false_pos, 1), `TB started on Tx` = round(tb_started, 1),
                             `TB missed` = round(tb_missed, 1), `Yield %` = round(yield_pct, 1),
                             `P(TB to Tx)` = round(prob_tb_treated, 3))
    datatable(r, rownames = FALSE, options = list(dom = "t", scrollX = TRUE))
  })
  output$p_torn <- renderPlot({
    t <- cascade_tornado(cpar()); t$parameter <- factor(t$parameter, levels = t$parameter)
    ggplot(t) + geom_segment(aes(x = low, xend = high, y = parameter, yend = parameter), linewidth = 7, colour = "#E07A1F", alpha = .7) +
      geom_vline(xintercept = t$base[1], linetype = 2) + labs(x = "Swab minus sputum (per 1,000)", y = NULL)
  })

  # ---- scenarios (precomputed)
  ss <- reactive(scen$summary |> filter(iso3 == input$iso, year >= 2015))
  output$p_scen <- renderPlotly({
    d <- ss(); i15 <- d$incidence_med[d$year == 2015 & d$scenario == names(pal)[1]]
    w <- b() |> filter(year >= 2015)
    pl <- plot_ly()
    for (sc in names(pal)) {
      x <- d |> filter(scenario == sc)
      pl <- pl |>
        add_ribbons(data = x, x = ~year, ymin = ~incidence_lo, ymax = ~incidence_hi, fillcolor = pal[[sc]],
                    opacity = 0.12, line = list(width = 0), showlegend = FALSE, hoverinfo = "skip", name = sc) |>
        add_lines(data = x, x = ~year, y = ~incidence_med, name = sc, line = list(color = pal[[sc]], width = 2.5))
    }
    pl |>
      add_markers(data = w, x = ~year, y = ~inc_100k, name = "WHO estimate", marker = list(color = "black", size = 6)) |>
      add_lines(x = c(2015, 2035), y = rep(i15 * 0.5, 2), name = "End TB 2025 milestone (−50%)", line = list(color = "grey", dash = "dot")) |>
      add_lines(x = c(2015, 2035), y = rep(i15 * 0.2, 2), name = "End TB 2030 milestone (−80%)", line = list(color = "grey", dash = "dash")) |>
      layout(yaxis = list(title = "incidence per 100,000", rangemode = "tozero"), xaxis = list(title = ""),
             legend = list(orientation = "v", x = 1.02, y = 1, font = list(size = 11)), margin = list(r = 10))
  })
  output$p_deaths <- renderPlotly({
    d <- ss()
    ggplotly(ggplot(d, aes(year, deaths_med, colour = scenario)) + geom_line(linewidth = 1) +
      scale_colour_manual(values = pal, name = NULL) + labs(x = NULL, y = "per 100,000") + theme(legend.position = "none"))
  })
  output$t_avert <- renderDT({
    a <- scen$averted |> filter(iso3 == input$iso, scenario != names(pal)[1]) |>
      left_join(scen$endtb |> filter(iso3 == input$iso), by = c("iso3", "scenario")) |>
      transmute(Scenario = scenario,
                `Cases averted (95% interval)` = paste0(fmt(cases_averted_med), " (", fmt(cases_averted_lo), "–", fmt(cases_averted_hi), ")"),
                `Deaths averted (95% interval)` = paste0(fmt(deaths_averted_med), " (", fmt(deaths_averted_lo), "–", fmt(deaths_averted_hi), ")"),
                `Incidence 2035 vs 2015` = paste0("−", round(100 * inc_red_2035), "%"))
    datatable(a, rownames = FALSE, options = list(dom = "t", scrollX = TRUE))
  })

  # ---- live model
  live <- reactive({
    p <- calib[[input$iso]]$point
    cm <- cascade_model(cpar())
    prob <- if (input$acf_test == "swab") cm$prob_tb_treated[2] else cm$prob_tb_treated[1]
    base <- run_tb(p, 2035, scenario_list()[[1]])
    int  <- run_tb(p, 2035, list(acf_cov = input$acf, acf_prob = prob, tpt_cov = input$tptc, tpt_comp = input$tptcomp))
    bind_rows(cbind(base[, c("time", "incidence", "deaths")], run = "Baseline"),
              cbind(int[, c("time", "incidence", "deaths")], run = "Your scenario"))
  })
  output$p_live <- renderPlotly({
    d <- live() |> filter(time >= 2015)
    ggplotly(ggplot(d, aes(time, incidence, colour = run)) + geom_line(linewidth = 1.1) +
      scale_colour_manual(values = c("#6B7280", "#E07A1F"), name = NULL) + labs(x = NULL, y = "incidence per 100,000")) |>
      layout(legend = list(orientation = "h", y = -0.15))
  })
  output$live_text <- renderUI({
    d <- live(); pop <- b24()$pop
    b0 <- d |> filter(run == "Baseline", time >= 2027); b1 <- d |> filter(run == "Your scenario", time >= 2027)
    ca <- sum(b0$incidence - b1$incidence) * pop / 1e5; da <- sum(b0$deaths - b1$deaths) * pop / 1e5
    i35 <- b1$incidence[b1$time == 2035]; i15 <- d$incidence[d$run == "Baseline" & d$time == 2015]
    tags$p(HTML(sprintf("2027–2035: about <b>%s</b> cases and <b>%s</b> deaths averted nationally; incidence in 2035 is <b>%.0f%%</b> below 2015 (End TB 2035 target: −90%%).",
      fmt(ca), fmt(da), 100 * (1 - i35 / i15))))
  })

  # ---- calibration
  fitdat <- reactive(scen$summary |> filter(iso3 == input$iso, scenario == names(pal)[1], year >= 2015, year <= 2024))
  output$p_fit_inc <- renderPlotly({
    d <- fitdat(); w <- b() |> filter(year >= 2015)
    ggplotly(ggplot(d, aes(year)) + geom_ribbon(aes(ymin = incidence_lo, ymax = incidence_hi), fill = "#1F3864", alpha = .15) +
      geom_line(aes(y = incidence_med), colour = "#1F3864", linewidth = 1) +
      geom_pointrange(data = w, aes(y = inc_100k, ymin = inc_lo, ymax = inc_hi), colour = "#C0392B", size = .3) +
      labs(x = NULL, y = "per 100,000 (red: WHO estimate)"))
  })
  output$p_fit_not <- renderPlotly({
    d <- fitdat(); w <- b() |> filter(year >= 2015)
    ggplotly(ggplot(d, aes(year)) + geom_ribbon(aes(ymin = notifications_lo, ymax = notifications_hi), fill = "#E07A1F", alpha = .15) +
      geom_line(aes(y = notifications_med), colour = "#E07A1F", linewidth = 1) +
      geom_point(data = w, aes(y = notif_100k), colour = "black", size = 1.5) + labs(x = NULL, y = "per 100,000 (black: reported)"))
  })
  output$t_par <- renderDT({
    p <- calib[[input$iso]]$point
    d <- data.frame(Parameter = c("beta (transmission)", "Case detection rate 2015", "Case detection rate 2024", "Fast progression", "Reactivation", "Reinfection protection", "Self-cure", "Relapse", "HIV prevalence (adults)", "Share of TB with HIV", "Retained uncertainty draws"),
                    Value = c(round(p$beta, 2), round(p$d15, 2), round(p$d24, 2), p$eps, p$nu, p$x, p$cure, p$rho, p$hiv_prev, p$h_tb, length(calib[[input$iso]]$draws)))
    datatable(d, rownames = FALSE, options = list(dom = "t"))
  })
}

shinyApp(ui, server)
