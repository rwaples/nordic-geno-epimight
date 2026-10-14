# Step 5, report: one self-contained HTML page from the step-4 tables (D17, D18). Each
# analysis gets its estimates, a forest plot, its CIF curves and its cohort counts; then
# the h2 forests per trait, the rg heatmaps per relationship and a summary table.

# Each row's stratify values joined by " / "; "pooled" for a pooled row.
stratum_label <- function(d, stratify) {
  label <- do.call(paste, c(lapply(stratify, function(s) as.character(d[[s]])), sep = " / "))
  if (is.null(d$level)) label else ifelse(d$level == "pooled", "pooled", label)
}

# Point and sandwich 95% interval per stratum and pooled, for the rows of one or more
# analyses; `colour` names the column that separates them (one line each).
plot_forest <- function(d, estimate, stratify, colour = NULL, title = NULL) {
  d <- copy(d)
  labels <- stratum_label(d, stratify)
  d[, stratum := factor(labels, levels = rev(c(sort(setdiff(unique(labels), "pooled")),
                                               "pooled")))]
  d <- d[, est := get(estimate)]
  aesthetics <- ggplot2::aes(x = est, y = stratum, xmin = l95_sandwich, xmax = u95_sandwich)
  if (!is.null(colour)) aesthetics$colour <- as.name(colour)
  dodge <- ggplot2::position_dodge(width = 0.5)
  ggplot2::ggplot(d[is.finite(est)], aesthetics) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey70") +
    ggplot2::geom_pointrange(position = dodge, size = 0.3) +
    ggplot2::labs(x = sprintf("%s (sandwich 95%% CI)", estimate), y = NULL, title = title) +
    ggplot2::theme_minimal(base_size = 11)
}

# Pooled rg per index trait (rows) and relatives' trait (columns) for one relationship.
plot_rg_heatmap <- function(rg, rel) {
  d <- rg[level == "pooled" & relationship == rel]
  d[, label := ifelse(is.finite(rg), sprintf("%.2f\n(%.2f, %.2f)", rg, l95_sandwich, u95_sandwich),
                      "NA")]
  ggplot2::ggplot(d, ggplot2::aes(x = relatives_trait, y = index_trait, fill = rg)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = label), size = 3) +
    ggplot2::scale_fill_gradient2(limits = c(-1, 1), oob = scales::squish, na.value = "grey90") +
    ggplot2::labs(x = "relatives' trait", y = "index trait",
                  title = sprintf("Pooled rg, %s", rel)) +
    ggplot2::theme_minimal(base_size = 11)
}

# CIF curves of one analysis, one panel per cohort, one line per stratum.
plot_cif <- function(cif, stratify) {
  d <- copy(cif)
  d[, stratum := stratum_label(d, stratify)]
  d[, panel := ifelse(cohort == "population", sprintf("population: %s", index_trait),
                      sprintf("%s: %s, %s relatives with %s", sub("_", " ", cohort), index_trait,
                              relationship, relatives_trait))]
  order <- unique(d[order(match(cohort, c("population", "family_history", "cross")), index_trait),
                    panel])
  d[, panel := factor(panel, levels = order)]
  ggplot2::ggplot(d, ggplot2::aes(x = age, y = cif, colour = stratum)) +
    ggplot2::geom_step() +
    ggplot2::facet_wrap(~panel, ncol = 3) +
    ggplot2::labs(x = "age", y = "cumulative incidence",
                  colour = paste(stratify, collapse = " / ")) +
    ggplot2::theme_minimal(base_size = 10)
}

# Estimate (sandwich 95% CI) as text; NA when there is none.
format_estimate <- function(est, lo, hi) {
  ifelse(is.finite(est), sprintf("%.3f (%.3f, %.3f)", est, lo, hi), "NA")
}

render_report <- function(out, dir) {
  # knitr changes into `dir`, so relative paths would no longer resolve.
  out <- normalizePath(out, mustWork = TRUE)
  dir <- normalizePath(dir, mustWork = TRUE)
  rmarkdown::render(
    system.file("report.Rmd", package = "nordicepimight", mustWork = TRUE),
    params = list(out = out), output_file = "report.html",
    output_dir = out, intermediates_dir = dir, knit_root_dir = dir,
    envir = new.env(), quiet = TRUE
  )
}

run_report <- function(study_path, out, dir) {
  path <- render_report(out, dir)
  cat(sprintf("report: %s\n", path))
  TRUE
}
