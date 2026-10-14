#' make_epimight_tte
#'
#' Builds the time-to-event input for epimight for ONE trait and ONE kind of relative.
#' Call it once per kind of relative (siblings, parents, cousins, ...) and rbind the
#' results into one pool for epimight::Pipeline.
#'
#' How relatives are counted (same logic as epimight's own SQL):
#'   - Pairs in the genealogy are read in both directions by default (see relative_is).
#'   - A relative is only counted if they have a row for the trait in mainPhenotype.
#'   - Only Status 1 counts as an affected relative. Status 2 relatives count towards
#'     relatives_n but not towards relatives_n_trait.
#'   - Affection in relatives is counted at any age.
#'   - People with no relatives of this kind are KEPT with relatives_n = 0, because
#'     epimight's population CIF uses every row of the trait in the pool.
#'
#' -------------------------------------------------------------------------------
#' INPUT DATA
#' -------------------------------------------------------------------------------
#'
#' @param mainPhenotype
#'   Index phenotype data.frame, one row per person per phenotype, with:
#'   ID, Sex, BirthDate, Phenotype, Status, FailureTime
#'     Status:      0 = censored, 1 = affected, 2 = competing risk (e.g. death)
#'     FailureTime: years from birth to diagnosis, censoring or competing event
#'   Used for the probands AND for the status of every relative.
#'
#' @param secondaryPhenotype
#'   Second phenotype data.frame, only needed when exclude_trait2 is used, with:
#'   ID, Phenotype, Status, FailureTime
#'   Only Status 1 counts as having the second trait. Never counted as a relative outcome.
#'   If both traits are in one long file, pass that file here as well.
#'   Default: NULL
#'
#' @param genealogy
#'   Pairs of relatives, with:
#'   id1, id2, relationship_kind, kinship
#'   relationship_kind is the code in your file (e.g. "FS", "mHS", "pHS", "PO", "1C", "Av").
#'
#' -------------------------------------------------------------------------------
#' WHAT TO EXTRACT
#' -------------------------------------------------------------------------------
#'
#' @param trait
#'   Name of the index phenotype in mainPhenotype$Phenotype. Must match exactly.
#'   Example: "PTSD"
#'
#' @param relatives_kind
#'   One or more relationship_kind codes to use as relatives.
#'   Several codes are pooled under one label, so only pool kinds with the same relatedness.
#'   Example: "FS"   or   c("mHS", "pHS")
#'
#' @param relatives_label
#'   Text written in the output column relatives_kind. run_h2 selects relatives on this label,
#'   so it must describe the relationship (PO is never "full_siblings").
#'   Example: "parents"
#'   Default: the codes pasted together with "+"
#'
#' -------------------------------------------------------------------------------
#' WHICH RELATIVES TO COUNT
#' -------------------------------------------------------------------------------
#'
#' @param vertical
#'   Birth-order filter:
#'     "none"    keep all relatives        (siblings, cousins, avuncular)
#'     "older"   born before the proband   (parents, grandparents)
#'     "younger" born after the proband    (children)
#'   TRUE and FALSE also work and mean "older" and "none".
#'   Note: this is birth order, not generation. Use "none" for avuncular.
#'   Default: "none"
#'
#' @param relative_is
#'   Which genealogy column holds the relative:
#'     "either"  read every pair both ways (symmetric codes, or both directions stored)
#'     "id2"     id1 is the person, id2 is their relative
#'     "id1"     id2 is the person, id1 is their relative
#'   Default: "either"
#'
#' @param max_relatives
#'   Sanity check only, does not change the output. Warns and prints example IDs when a
#'   person has more relatives than this. Use 2 for parents.
#'   Default: NULL (no check)
#'
#' -------------------------------------------------------------------------------
#' FOLLOW-UP
#' -------------------------------------------------------------------------------
#'
#' @param min_followup
#'   Minimum POTENTIAL follow-up in years, based on birth date only.
#'   Probands born less than min_followup years before the end of data are removed,
#'   cases and non-cases alike. This is NOT a filter on FailureTime, so early cases are kept.
#'   Example: 10 with data ending 2021 removes probands born after 2011
#'   Default: NULL (no filter)
#'
#' @param max_followup
#'   Fixed observation window for the PROBANDS, in years from birth, so that every proband
#'   has the same observable time regardless of when they were born.
#'     - Probands born less than max_followup years before the end of data are removed
#'       (e.g. aged 15 at the end of data with 20).
#'     - Probands with FailureTime above max_followup are censored at the window:
#'       FailureTime = max_followup and Status = 0. This holds for a diagnosis (Status 1),
#'       a competing event such as death (Status 2) and a later censoring (Status 0).
#'     - Probands with FailureTime at or below max_followup are unchanged
#'       (diagnosis, death or emigration inside the window).
#'   Second-trait onsets after max_followup are ignored, because they fall outside the window.
#'   Example: 20
#'   Default: NULL (no window)
#'
#' @param max_followup_relatives
#'   Fixed observation window for the RELATIVES, in years from birth. Same three rules as
#'   max_followup, applied to people in their role as relatives:
#'     - Relatives born less than max_followup_relatives years before the end of data are
#'       not counted at all.
#'     - Relatives diagnosed after the window do not count as affected (they still count
#'       in relatives_n).
#'     - Relatives with an event inside the window are unchanged.
#'   Can differ from max_followup, e.g. probands observed for 20 years and parents for 50.
#'   With filter_relatives = TRUE the relatives are taken from the filtered probands, so the
#'   proband window has already been applied and the shorter of the two windows wins.
#'   Example: 50
#'   Default: the value of max_followup (same window for probands and relatives).
#'            Pass NULL to put no window on the relatives.
#'
#' @param study_end
#'   End of data as a date, only used with min_followup or max_followup.
#'   If NULL it is taken as the latest BirthDate + FailureTime among Status 0 people,
#'   and printed so you can check it. Set it per country if the printed date is wrong.
#'   Example: "2021-12-31"
#'   Default: NULL
#'
#' -------------------------------------------------------------------------------
#' EXCLUSION ON A SECOND TRAIT
#' -------------------------------------------------------------------------------
#'
#' @param trait2
#'   Name of the second phenotype in secondaryPhenotype$Phenotype.
#'   Required when exclude_trait2 is not "none".
#'   Example: "MDD"
#'
#' @param exclude_trait2
#'   When the second trait must occur, compared with the index FailureTime, to flag a proband:
#'     "none"    no exclusion
#'     "before"  second trait at or before the index FailureTime (same age counts as before)
#'     "after"   second trait after the index FailureTime
#'     "any"     either
#'   Applies to all probands, not only cases. For non-cases FailureTime is the censoring age.
#'   Default: "none"
#'
#' @param trait2_window
#'   Gap in years between the index FailureTime and the second trait onset.
#'   Default: NULL (any gap)
#'
#' @param trait2_window_type
#'   How the gap is used:
#'     "within"    flag when gap <= trait2_window   (diagnoses close together)
#'     "at_least"  flag when gap >= trait2_window   (diagnoses far apart)
#'   Examples, index PTSD at 30:
#'     "before", 2, "within"    flags MDD at 28 to 30
#'     "before", 2, "at_least"  flags MDD at 28 or earlier
#'     "after",  2, "within"    flags MDD at 30 to 32 (possible misdiagnosis)
#'     "after",  2, "at_least"  flags MDD at 32 or later
#'   Default: "within"
#'
#' @param trait2_action
#'   What happens to flagged probands:
#'     "exclude"    removed completely, including all their at-risk years
#'     "competing"  kept, but recoded to Status 2 at the age the second trait started
#'                  (only works with exclude_trait2 = "before")
#'   Default: "exclude"
#'
#' -------------------------------------------------------------------------------
#' RELATIVES AND OUTPUT
#' -------------------------------------------------------------------------------
#'
#' @param filter_relatives
#'   FALSE: relatives keep their original status, whatever the filters did to them as probands.
#'   TRUE:  people removed or recoded as probands are also removed or recoded as relatives.
#'   Note: TRUE also applies min_followup to relatives, so recently born relatives drop out.
#'   Default: FALSE
#'
#' @param keep_columns
#'   Extra columns kept in the output, for stratify_columns in epimight.
#'   Default: c("birth_year", "sex")
#'
#' @return
#'   data.table with one row per proband:
#'   person_id, trait, trait_status, trait_age, relatives_kind, relatives_n, relatives_n_trait,
#'   plus keep_columns.
#'     trait_age is floor(FailureTime), because epimight needs whole years.
#'   Attributes:
#'     attr(x, "kinship")      median kinship of the pairs used
#'     attr(x, "relatedness")  2 x kinship, the value to pass to run_h2
make_epimight_tte <- function(mainPhenotype,
                              secondaryPhenotype = NULL,
                              genealogy,
                              trait,
                              relatives_kind,
                              relatives_label    = NULL,
                              vertical           = "none",
                              relative_is        = c("either", "id2", "id1"),
                              max_relatives      = NULL,
                              min_followup       = NULL,
                              max_followup       = NULL,
                              max_followup_relatives = max_followup,
                              study_end         = NULL,
                              trait2             = NULL,
                              exclude_trait2     = c("none", "before", "after", "any"),
                              trait2_window      = NULL,
                              trait2_window_type = c("within", "at_least"),
                              trait2_action      = c("exclude", "competing"),
                              filter_relatives   = FALSE,
                              keep_columns       = c("birth_year", "sex")) {
  library(data.table)

  exclude_trait2 <- match.arg(exclude_trait2)
  relative_is    <- match.arg(relative_is)
  if (isTRUE(vertical))  vertical <- "older"
  if (isFALSE(vertical)) vertical <- "none"
  vertical <- match.arg(vertical, c("none", "older", "younger"))
  trait2_action  <- match.arg(trait2_action)
  trait2_window_type <- match.arg(trait2_window_type)
  if (!is.null(trait2_window) && (!is.numeric(trait2_window) || trait2_window < 0))
    stop("trait2_window must be a non-negative number of years")
  force(max_followup_relatives)  # default is max_followup; pass NULL for no window on relatives
  bad_window <- function(w) !is.null(w) && (!is.numeric(w) || length(w) != 1 || is.na(w) || w <= 0)
  if (bad_window(max_followup)) stop("max_followup must be one positive number of years")
  if (bad_window(max_followup_relatives)) stop("max_followup_relatives must be one positive number of years")
  if (is.null(relatives_label)) relatives_label <- paste(relatives_kind, collapse = "+")

  ph <- as.data.table(mainPhenotype)
  ge <- as.data.table(genealogy)

  # ---- input checks ---------------------------------------------------------
  need_ph <- c("ID", "Sex", "BirthDate", "Phenotype", "Status", "FailureTime")
  need_ge <- c("id1", "id2", "relationship_kind", "kinship")
  miss_ph <- setdiff(need_ph, names(ph))
  miss_ge <- setdiff(need_ge, names(ge))
  if (length(miss_ph)) stop("mainPhenotype is missing columns: ", paste(miss_ph, collapse = ", "))
  if (length(miss_ge)) stop("genealogy is missing columns: ", paste(miss_ge, collapse = ", "))

  ph <- ph[Phenotype == trait]
  if (nrow(ph) == 0) stop("No rows in mainPhenotype for trait '", trait, "'")

  # character IDs: epimight requires string person_id (large integers lose precision in joins)
  ph[, ID := as.character(ID)]
  ge[, `:=`(id1 = as.character(id1), id2 = as.character(id2))]

  if (anyDuplicated(ph$ID)) stop("Duplicate IDs for trait '", trait, "': expected one row per person per trait")
  if (!all(ph$Status %in% c(0L, 1L, 2L))) stop("Status must be 0 (censored), 1 (affected) or 2 (competing risk)")

  # invalid TTE: removed entirely (as probands AND as relatives)
  bad <- is.na(ph$FailureTime) | ph$FailureTime < 0
  cat(sum(bad), "Individual(s) removed due to negative TTE or NA", "\n")
  ph <- ph[!bad]

  ph[, BirthDate := as.IDate(BirthDate)]
  if (anyNA(ph$BirthDate)) stop("BirthDate could not be parsed as a date for some rows")

  # ---- end of data (needed by min_followup and the observation windows) ------
  if (!is.null(min_followup) || !is.null(max_followup) || !is.null(max_followup_relatives)) {
    if (is.null(study_end)) {
      cens <- ph[Status == 0L]
      if (nrow(cens) == 0) stop("No status 0 individuals to derive the end of follow-up; supply study_end")
      study_end <- max(cens$BirthDate + round(cens$FailureTime * 365.25))
      cat("End of follow-up derived from data:", format(study_end), "(check this is your administrative end date)", "\n")
    }
    study_end <- as.IDate(study_end)
  }

  # ---- fixed observation window ---------------------------------------------
  # Gives everybody the same observable time of `w` years from birth:
  # born too late to be observed for w years -> removed,
  # anything that happens after w -> censored at w (Status 0, FailureTime = w).
  # Used once for the probands (max_followup) and once for the relatives
  # (max_followup_relatives). Returns a new table, the input is not changed.
  apply_window <- function(d, w, who) {
    potential <- as.numeric(study_end - d$BirthDate) / 365.25
    drop      <- potential < w
    cat(sum(drop), "of", nrow(d), who, "removed because they could not be observed for", w,
        "years (born after", format(study_end - round(w * 365.25)), ")", "\n")
    d <- d[!drop]
    d[, `:=`(Status = as.integer(Status), FailureTime = as.numeric(FailureTime))]
    late <- d$FailureTime > w
    cat(sum(late), "of", nrow(d), who, "censored at", w, "years (",
        sum(late & d$Status == 1L), "diagnosed later,",
        sum(late & d$Status == 2L), "competing event later,",
        sum(late & d$Status == 0L), "censored later )", "\n")
    d[late, `:=`(Status = 0L, FailureTime = as.numeric(w))]
    d
  }

  pro <- copy(ph)
  if (!is.null(max_followup)) pro <- apply_window(pro, max_followup, "proband(s)")

  # ---- minimum potential follow-up filter (probands) ------------------------
  if (!is.null(min_followup)) {
    potential <- as.numeric(study_end - pro$BirthDate) / 365.25
    drop      <- potential < min_followup
    cat(sum(drop), "of", nrow(pro), "proband(s) removed with less than", min_followup,
        "years of potential follow-up (born after", format(study_end - round(min_followup * 365.25)), ")", "\n")
    pro <- pro[!drop]
  }

  # ---- secondaryPhenotype: exclusion or competing event -----------------------
  if (exclude_trait2 != "none") {
    if (is.null(trait2)) stop("trait2 is required when exclude_trait2 != 'none'")
    if (is.null(secondaryPhenotype)) stop("secondaryPhenotype is required when exclude_trait2 != 'none'")
    if (trait2_action == "competing" && exclude_trait2 != "before")
      stop("trait2_action = 'competing' only works with exclude_trait2 = 'before'")

    p2 <- as.data.table(secondaryPhenotype)
    miss_p2 <- setdiff(c("ID", "Phenotype", "Status", "FailureTime"), names(p2))
    if (length(miss_p2)) stop("secondaryPhenotype is missing columns: ", paste(miss_p2, collapse = ", "))

    p2 <- p2[Phenotype == trait2 & Status == 1L & !is.na(FailureTime),
             .(ID = as.character(ID), age2 = FailureTime)]
    if (nrow(p2) == 0) warning("No cases (Status == 1) of trait2 '", trait2, "' found")
    p2 <- p2[, .(age2 = min(age2)), by = ID]  # earliest onset if duplicated
    if (!is.null(max_followup)) p2 <- p2[age2 <= max_followup]  # onsets outside the window are ignored

    m      <- p2[pro[, .(ID, FailureTime)], on = "ID"]  # same row order as pro
    has2     <- !is.na(m$age2)
    d_before <- m$FailureTime - m$age2   # >= 0: trait2 at or before trait1 (ties count as before)
    d_after  <- m$age2 - m$FailureTime   # >  0: trait2 after trait1
    before   <- has2 & d_before >= 0
    after    <- has2 & d_after  >  0

    win_txt <- ""
    if (!is.null(trait2_window)) {
      in_window <- function(d) if (trait2_window_type == "within") d <= trait2_window else d >= trait2_window
      before  <- before & in_window(d_before)
      after   <- after  & in_window(d_after)
      win_txt <- paste0(" (", sub("_", " ", trait2_window_type), " ", trait2_window, " years)")
    }
    flag <- switch(exclude_trait2, before = before, after = after, any = before | after)

    cat(sum(flag), "of", nrow(pro), "proband(s) with", trait2, paste0(exclude_trait2, win_txt), trait,
        "(", sum(flag & pro$Status == 1L), trait, "cases,", sum(flag & pro$Status != 1L), "non-cases )", "\n")

    if (trait2_action == "exclude") {
      pro <- pro[!flag]
      cat("  -> excluded", "\n")
    } else {
      pro[flag, `:=`(Status = 2L, FailureTime = m$age2[flag])]
      cat("  -> recoded as competing event (Status 2) at", trait2, "onset", "\n")
    }
  }

  if (nrow(pro) == 0) stop("No probands left after filtering")

  # ---- relatives' status ----------------------------------------------------
  rel_src  <- if (isTRUE(filter_relatives)) pro else ph
  if (!is.null(max_followup_relatives)) rel_src <- apply_window(rel_src, max_followup_relatives, "relative(s)")
  rel_info <- rel_src[, .(relative_id = ID, rel_status = as.integer(Status), rel_birth = BirthDate)]

  # ---- relationship pairs, both directions, deduplicated --------------------
  ge_k <- ge[relationship_kind %in% relatives_kind]
  if (nrow(ge_k) == 0) stop("No pairs in genealogy with relationship_kind in: ", paste(relatives_kind, collapse = ", "))

  pairs <- switch(relative_is,
    either = rbind(ge_k[, .(person_id = id1, relative_id = id2)],
                   ge_k[, .(person_id = id2, relative_id = id1)]),
    id2    = ge_k[, .(person_id = id1, relative_id = id2)],
    id1    = ge_k[, .(person_id = id2, relative_id = id1)])
  pairs <- unique(pairs)
  pairs <- pairs[person_id != relative_id]

  # keep only relatives present in the phenotype data (inner join, as in epimight's SQL)
  pairs <- rel_info[pairs, on = "relative_id", nomatch = NULL]

  if (vertical != "none") {
    pairs <- pro[, .(person_id = ID, pro_birth = BirthDate)][pairs, on = "person_id", nomatch = NULL]
    pairs <- if (vertical == "older") pairs[rel_birth < pro_birth] else pairs[rel_birth > pro_birth]
  }

  counts <- pairs[, .(
    relatives_n       = .N,
    relatives_n_trait = sum(rel_status == 1L)
  ), by = person_id]

  cat("relatives_n distribution (", relatives_label, "):", "\n")
  print(table(counts$relatives_n, dnn = "relatives_n"))
  if (!is.null(max_relatives)) {
    over <- counts[relatives_n > max_relatives]
    if (nrow(over) > 0)
      warning(nrow(over), " person(s) have more than ", max_relatives, " '", relatives_label,
              "' relatives. Check relative_is / vertical / relationship_kind. Examples: ",
              paste(head(over$person_id, 5), collapse = ", "))
  }

  # ---- assemble output ------------------------------------------------------
  out <- pro[, .(
    person_id    = ID,
    trait        = trait,
    trait_status = as.integer(Status),
    # epimight's CIF validator requires whole years: use completed years of age
    trait_age    = as.integer(floor(FailureTime)),
    birth_year   = as.integer(year(BirthDate)),
    sex          = as.character(Sex)
  )]

  out <- counts[out, on = "person_id"]
  out[is.na(relatives_n),       relatives_n       := 0L]
  out[is.na(relatives_n_trait), relatives_n_trait := 0L]
  out[, `:=`(relatives_n       = as.integer(relatives_n),
             relatives_n_trait = as.integer(relatives_n_trait),
             relatives_kind    = relatives_label)]

  core <- c("person_id", "trait", "trait_status", "trait_age",
            "relatives_kind", "relatives_n", "relatives_n_trait")
  out  <- out[, c(core, intersect(keep_columns, names(out))), with = FALSE]
  setorder(out, person_id)

  # ---- relatedness for run_h2 / run_rg --------------------------------------
  k <- unique(ge_k$kinship)
  if (length(k) > 1) warning("Multiple kinship values for '", relatives_label, "': ",
                             paste(head(sort(k), 10), collapse = ", "), ". Using the median.")
  kin <- stats::median(ge_k$kinship, na.rm = TRUE)
  attr(out, "kinship")     <- kin
  attr(out, "relatedness") <- 2 * kin  # epimight's `relatedness` = coefficient of relationship (FS = 0.5)

  out[]
}

# ---- usage ------------------------------------------------------------------
# Basic:
# fs <- make_epimight_tte(mainPhenotype = main, genealogy = genealogy, trait = "MDD", relatives_kind = "FS",
#                         relatives_label = "full_siblings", min_followup = 10)
#
# Same 20 years of observable time for everybody (born too late removed, later events censored at 20):
# fs <- make_epimight_tte(mainPhenotype = main, genealogy = genealogy, trait = "MDD", relatives_kind = "FS",
#                         relatives_label = "full_siblings", max_followup = 20, study_end = "2021-12-31")
#
# Different windows: probands observed for 20 years, their parents for 50 years:
# par <- make_epimight_tte(mainPhenotype = main, genealogy = genealogy, trait = "MDD",
#                          relatives_kind = "PO", relatives_label = "parents", vertical = "older",
#                          max_followup = 20, max_followup_relatives = 50, study_end = "2021-12-31")
#
# Exclude probands who had BIP before (or at the same age as) MDD:
# fs <- make_epimight_tte(mainPhenotype = main, genealogy = genealogy, trait = "MDD", relatives_kind = "FS",
#                         relatives_label = "full_siblings", min_followup = 10,
#                         secondaryPhenotype = bip, trait2 = "BIP",
#                         exclude_trait2 = "before")
#
# Possible misdiagnosis: BIP cases re-diagnosed with MDD within 2 years after BIP:
# bip <- make_epimight_tte(mainPhenotype = main, genealogy = genealogy, trait = "BIP", relatives_kind = "FS",
#                          relatives_label = "full_siblings",
#                          secondaryPhenotype = dep, trait2 = "MDD",
#                          exclude_trait2 = "after", trait2_window = 2)
#
# Preferred alternative: keep them, BIP onset ends their MDD risk as a competing event:
# fs <- make_epimight_tte(mainPhenotype = main, genealogy = genealogy, trait = "MDD", relatives_kind = "FS",
#                         relatives_label = "full_siblings", min_followup = 10,
#                         secondaryPhenotype = bip, trait2 = "BIP",
#                         exclude_trait2 = "before", trait2_action = "competing")
#
# Parents from a directional genealogy where id2 is the parent of id1:
# par <- make_epimight_tte(mainPhenotype = main, genealogy = genealogy, trait = "BIP",
#                          relatives_kind = "PO", relatives_label = "parents",
#                          relative_is = "id2", vertical = "older", max_relatives = 2)
#
# pool <- rbind(fs, po)   # one row per person x trait x relatives_kind
# pipeline <- epimight::Pipeline$new(pool = pool)
# pipeline$run_h2(
#   cif_pop = list(index_trait = "MDD", stratify_columns = list("birth_year")),
#   cif_fh  = list(index_trait = "MDD", relatives_trait = "MDD",
#                  relatives_kind = "full_siblings", stratify_columns = list("birth_year")),
#   relatedness = attr(fs, "relatedness")
# )