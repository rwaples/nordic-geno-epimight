# A trait's follow-up and second-trait rules (D10, D11), with make_epimight_tte's
# semantics (R/make_epimight_tte.R). All windows are years from birth; "potential"
# follow-up is study_end minus birth_date in years.

# Gives everyone in `d` (id, status, age, birth_date) the same observable time of `w`
# years: people born too late to be observed for w years are removed, and anything after
# w becomes censoring at w. Returns the changed copy and how many it removed and censored.
apply_window <- function(d, w, study_end) {
  potential <- as.numeric(study_end - d$birth_date) / 365.25
  d <- d[potential >= w]
  late <- d$age > w
  out <- copy(d)[late, `:=`(status = 0L, age = as.numeric(w))]
  list(data = out, removed = sum(potential < w), censored = sum(late))
}

# The trait's probands: its file's rows (id, status, age, birth_date) after max_followup,
# min_followup and the trait2 rule. `onsets` are trait2's status-1 rows (id, age).
# Returns list(probands, log), log being one row per rule with how many people it changed.
apply_rules <- function(rows, rule, onsets, study_end) {
  log <- list(data.table(rule = character(), people = integer()))
  note <- function(step, n) data.table(rule = step, people = n)
  probands <- copy(rows)
  if (!is.na(rule$max_followup)) {
    window <- apply_window(probands, rule$max_followup, study_end)
    probands <- window$data
    log <- c(log, list(note("max_followup: born too late, removed", window$removed),
                       note("max_followup: censored at the window", window$censored)))
  }
  if (!is.na(rule$min_followup)) {
    potential <- as.numeric(study_end - probands$birth_date) / 365.25
    log <- c(log, list(note("min_followup: born too late, removed",
                            sum(potential < rule$min_followup))))
    probands <- probands[potential >= rule$min_followup]
  }
  if (rule$exclude_trait2 != "none") {
    flagged <- trait2_flags(probands, rule, onsets)
    action <- if (rule$trait2_action == "exclude") "excluded" else "recoded as competing"
    log <- c(log, list(note(sprintf("trait2 %s %s: %s", rule$trait2, rule$exclude_trait2, action),
                            sum(flagged$flag))))
    if (rule$trait2_action == "exclude") {
      probands <- probands[!flagged$flag]
    } else {
      probands[flagged$flag, `:=`(status = 2L, age = flagged$age2[flagged$flag])]
    }
  }
  list(probands = probands, log = rbindlist(log))
}

# Which probands have trait2 at the time the rule names; ties count as before.
trait2_flags <- function(probands, rule, onsets) {
  onsets <- onsets[, .(age2 = min(age)), by = id]
  if (!is.na(rule$max_followup)) onsets <- onsets[age2 <= rule$max_followup]
  age2 <- onsets$age2[match(probands$id, onsets$id)]
  has2 <- !is.na(age2)
  gap_before <- probands$age - age2
  gap_after <- age2 - probands$age
  before <- has2 & gap_before >= 0
  after <- has2 & gap_after > 0
  if (!is.na(rule$trait2_window)) {
    in_window <- function(gap) {
      w <- rule$trait2_window
      if (rule$trait2_window_type == "within") gap <= w else gap >= w
    }
    before <- before & in_window(gap_before)
    after <- after & in_window(gap_after)
  }
  flag <- switch(rule$exclude_trait2, before = before, after = after, any = before | after)
  list(flag = flag, age2 = age2)
}

# The people counted as relatives for one trait and relationship: the trait file's rows,
# or its probands with filter_relatives, inside the relatives' window `w` (NA: none).
relatives_status <- function(rows, probands, rule, w, study_end) {
  source <- if (rule$filter_relatives) probands else rows
  if (!is.na(w)) source <- apply_window(source, w, study_end)$data
  source[, .(relative_id = id, relative_status = status)]
}
