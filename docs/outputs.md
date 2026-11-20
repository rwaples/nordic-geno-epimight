# Outputs, the folder to share, and findings

This page describes what a run writes to its output folder (`out/` below), what may leave
your server, and what to do when a run stops. Terms in bold are in the
[glossary](glossary.md).

## What each step writes

`pixi run study` (or `apptainer run IMAGE study`) runs the six steps in order. Each step
writes its own folder and a `DONE` file when it finishes. A step won't start until the step
before it is done, and rerunning a step deletes the output of every later step.

| Step | Folder | What to look at |
|---|---|---|
| `check` | `out/1_check/` | `findings.tsv`: every problem with your inputs (below). `pedigree_coverage.tsv`: pedigree people with no trait row, per birth decade (written only when the check passes). `pedsum/`: pedsum's logs. `run.yaml`: what the check read |
| `cohort` | `out/2_cohort/` | `cohort.tsv`: the **cohort table**, EPIMIGHT's input. `rules.tsv`: how many people each trait rule dropped or censored. `relatives_coverage.tsv`: per relationship and the relative's birth decade, the pairs whose relative has no trait row and so never counts |
| `epimight` | `out/3_epimight/` | `jobs.tsv`: each EPIMIGHT call's outcome, warnings and seconds |
| `tables` | `out/` | `h2.tsv`, `rg.tsv`, `cif.tsv`, `cohort_summary.tsv`, `run.yaml` (below); `4_tables/tables.rds` has the unrounded values |
| `report` | `out/report.html` | One page with every result and plot |
| `export` | `out/6_export/` | The only folder you send (below) |

Everything in `out/` except `6_export/` holds individual-level data or unsuppressed counts
and stays on your server.

## Result tables

Numbers are rounded to 6 significant digits.

| File | One row per | Contents |
|---|---|---|
| `h2.tsv` | analysis and **stratum**, plus a pooled row per analysis | h² with its sandwich SE and 95% interval, EPIMIGHT's own SE (`se_native`), the age the estimate is for, and a note |
| `rg.tsv` | the same | rg with the same columns, plus `rhh` and the two h² values it uses |
| `cif.tsv` | analysis, curve, stratum and age | The cumulative incidence (**CIF**) curves each analysis uses, with `cases`, the cumulative number of cases up to that age |
| `cohort_summary.tsv` | trait, relationship and stratum | Probands, cases, competing events, censored, probands with relatives and with affected relatives, relatives and affected relatives |
| `run.yaml` | | How the run was made (below) |

Reading the estimate tables:

- `level` is `stratum` for one stratum and `pooled` for the fixed-effect pool of the strata.
  `n_strata` counts the strata that entered; a note says when some did not.
- `age_min` and `age_max`: the ages a stratum's estimate reads. For h² there is one: the
  oldest age that the population and family-history CIF curves share at which EPIMIGHT
  gave an h² above 1e-10; a note says when an older shared age had none. Each CIF curve
  runs to the end of its follow-up. rg reads each input at its own age: the index trait's
  population and cross curves at the last age they share, the relatives trait's
  population curve at its last age, and each h² at its last row above 1e-10. `age_min`
  and `age_max` span those four ages. The pooled row gives the range over its strata.
- Report the sandwich interval (`l95_sandwich`, `u95_sandwich`). `se_native` treats every
  relative pair as independent and is there only for comparison.
- Intervals are not cut to [0, 1]: an h² interval can go below 0 or above 1 in a small
  stratum.
- When EPIMIGHT can't estimate a stratum or an analysis, the row stays, with NA values and
  a note giving the reason. In the oldest birth cohorts this is common: their parents
  often have no trait rows, so they have no affected parent to count.
- `rhh` is `rg × sqrt(h2_index_at_age × h2_relatives_at_age)`, each h² at the age rg read
  it.
- In `cif.tsv`, `cohort` is `population` (everyone with the trait's rows),
  `family_history` (probands with an affected relative of the relationship, for h²) or
  `cross` (probands whose relative has the other trait, for rg). Each curve starts with a
  row at age 0, where its CIF is 0, and ends at its probands' last follow-up age, as
  `cmprsk::cuminc` lays out a curve.

### run.yaml

`out/run.yaml` records the site, the plan's checksum (two sites ran the same plan when
these match), the kit's version and commit, the EPIMIGHT and pedigreegraph versions, a
checksum of every input file, the settings, the analyses, the study-population size,
warnings, EPIMIGHT call counts and run time (`epimight: wall_seconds`), and the row count
of each output.

A kit `version` ending in `-dirty` means the kit was built from changed files: in a
checkout, files under `kit/` had uncommitted changes when `pixi run setup` ran; in an
image, anything in the repository it was built from. A collaborator's run should not show
it. In a checkout, run `git status`, undo the change and rerun `pixi run setup`; for an
image, ask for a clean one.

## The folder to share

`out/6_export/` holds `h2.tsv`, `rg.tsv`, `cif.tsv`, `cohort_summary.tsv`, `run.yaml` and a
`report.html` built from them, with these changes:

- Every count from 1 to `export_min_count` (5 in the shared plan) is suppressed. In
  `cohort_summary.tsv` such cells are NA, and when one of cases, competing and censored is
  suppressed the other two are too, since they add up to the probands.
- CIF rows whose cumulative cases are 1 to `export_min_count` are left out.
- `run.yaml` names the input files without their paths and records what was suppressed.

These rules are preliminary. Nothing yet covers small differences between neighbouring
cells, such as one new case between two ages of a CIF curve. Before sending:

1. Open `6_export/report.html` and `6_export/cohort_summary.tsv` and look for anything
   your register's disclosure rules don't allow.
2. Follow your server's export review.
3. Zip the folder (`zip -r <site>-export.zip out/6_export`) and send it to
   **TODO: recipient and channel**.

## When a run stops

### The check step

The check step reads every input and lists each problem in `out/1_check/findings.tsv`
before stopping, so one run shows them all. Each row has:

| Column | Meaning |
|---|---|
| `code` | A fixed name for the problem, such as `date_after_study_end` |
| `severity` | `STOP` stops the run; `WARN` doesn't |
| `file` | The file it is in |
| `count` | How many rows or values are affected |
| `message` | What is wrong |
| `examples` | Up to ten examples, such as ids |

The check step stops on any input it can't use: unknown keys in the site file, unknown
columns in the plan's tables, missing files, bad dates or statuses, a code on someone who
isn't a case, duplicate ids, ids missing from the pedigree, trait files with different
people, a missing stratum value, anything pedsum finds in the pedigree, or installed
software that differs from the kit's pinned versions. The formats it checks are in
[step-0.md](step-0.md).

Two warnings don't stop the run:

- `few_cases`: a trait has fewer than 10 cases in some stratum. Its estimates there will be
  imprecise or missing.
- `trait2_unused`: a trait sets `trait2` but its `exclude_trait2` is `none`, so the
  second trait does nothing.

`run.yaml` counts the warnings, without examples.

### Later steps

- A step started before the step before it finished, or an input file or the kit changed
  since `check`. The message names the command to run.
- The cohort step stops (`trait_no_probands` in `2_cohort/findings.tsv`) when a trait's
  rules leave nobody.
- The tables step stops (`4_tables/findings.tsv`) when EPIMIGHT's outcome differs from
  what the kit predicted: an error the kit didn't predict, a call that ran when the kit
  expected EPIMIGHT to stop, or rg ages the kit can't rebuild. Please report these, with
  the findings file and `3_epimight/jobs.tsv`.
