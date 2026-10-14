# nordic-geno-epimight

A kit for estimating heritability (h²) and genetic correlation (rg) from register data
with [EPIMIGHT](https://github.com/BioPsyk/epimight), with pedigree-pair sandwich standard
errors. You give it a pedigree, one file per trait, and two lists: the traits and the
analyses. It checks the inputs, builds EPIMIGHT's cohort table, runs EPIMIGHT, and writes
tables and an HTML report. Everything except the pedigree check runs in R; the pedigree is
checked by [pedsum](https://github.com/rwaples/pedsum).

## Install

Install [pixi](https://pixi.sh) (0.76), then from this folder:

```sh
pixi install --locked   # R 4.5, Rust, Python and their packages, from conda-forge
pixi run setup          # builds epimight and pedigreegraph from their pinned commits
pixi run selftest selftest-out/
```

`pixi run setup` needs internet access and compiles Rust (about 3 minutes the first time;
seconds after that). It installs epimight from BioPsyk/epimight's `sandwich` branch at
`55803e1` and pedigreegraph v0.12.2; the pins are in `nordicepimight/inst/pins.yaml`.
Every run checks that what is installed matches them.

`pixi run selftest` runs the kit on a simulated toy study (`selftest/`) and compares the
results with values the kit did not compute. It takes about 2 minutes, prints one
`PASS`, `FAIL` or `SKIP` line per item, and exits 1 if anything fails. Run it before your
own data. `selftest/README.md` says what each item checks.

## Running a study

```sh
pixi run study selftest/toy/study.yaml out/
```

runs five steps in order. Each can also be run alone, as `pixi run <step> study.yaml out/`:

| Step | Writes | What it does |
|---|---|---|
| `check` | `out/1_check/` | Reads every input and lists every problem in `findings.tsv`. Stops before anything runs if there is a STOP. |
| `cohort` | `out/2_cohort/` | Applies each trait's rules and counts every proband's relatives: `cohort.tsv` (EPIMIGHT's input), `cohort_summary.tsv`, `rules.tsv`. |
| `epimight` | `out/3_epimight/` | Runs EPIMIGHT once per estimate the analyses need. |
| `tables` | `out/*.tsv`, `out/run.yaml` | Writes `h2.tsv`, `rg.tsv`, `cif.tsv`, `cohort_summary.tsv` and `run.yaml`. |
| `report` | `out/report.html` | One self-contained page of results and plots. |

A step starts only after the one before it has finished, and rerunning a step deletes
the output of every later step, so `out/` never mixes runs.

## Inputs

Paths in `study.yaml` are relative to `study.yaml`; trait files in `traits.tsv` are
relative to `traits.tsv`. All tables are tab-separated with a header row. `NA` or an empty
cell is missing. Ids are text: `001`, `1` and `1.0` are three people.

### study.yaml

```yaml
pedigree: pedigree.tsv
traits: traits.tsv
analyses: analyses.tsv
relative_windows: relative_windows.tsv   # optional
study_end: 2023-12-31                    # the end of register follow-up
stratify: [birth_year]                   # pedigree columns, or birth_year
birth_year_bin: 5                        # optional, default 1
threads: 4                               # optional, default 1
max_degree: 3                            # optional, 1-5, default 3
external_parent_cap: 30                  # optional, default 30
```

- `stratify` names one or more pedigree columns. `birth_year` is the year of
  `birth_date`, grouped into bins of `birth_year_bin` years and labelled by each bin's
  first year (1960, 1965, ...). EPIMIGHT estimates per stratum and pools across strata.
- `max_degree` is the furthest kinship degree whose pairs enter the sandwich SE. It must
  reach every relationship analysed (PO and FS 1; HS, mHS, pHS, Av and 1G 2; 1C 3).
- `external_parent_cap`: a parent id with no row of its own is added as a founder, unless
  it has more children than this; then it is probably a code for an unknown parent, and
  the run stops.

### Pedigree file

One row per person: `id, mother, father, sex, birth_date`, plus any columns you stratify
on. An unknown parent is `NA`, empty or `-1`, never `0` (unless 0 is someone's id). Sex is
1 male, 2 female, 0 unknown. `birth_date` is `YYYY-MM-DD`.

### Trait files

One file per trait, one row per person in the study population: `id, trait, status,
age, date`.

- `status`: 1 the trait, 2 a competing event (death, for example), 0 censored.
- `age`: years from birth to that status: onset for 1, the competing event for 2, end of
  follow-up for 0. Fractions are fine; EPIMIGHT uses whole years (floored).
- `date`: the date of that status, `YYYY-MM-DD`. It must agree with `age` to within a
  day: `age = (date - birth_date) / 365.25`.
- `trait`: one value for the whole file, recorded but not used.

Every trait file must hold exactly the same people (the study population). Someone you
exclude from one trait keeps a row there, censored (status 0) at the age they leave
follow-up.

### traits.tsv: the trait list

One row per trait. A trait is a name, a file and rules; several traits may share a file.

| Column | Required | Meaning |
|---|---|---|
| `trait` | yes | The name analyses use: letters, digits, `_`, `.`, `-`. |
| `type` | yes | `tte` (time to event; the only type so far). |
| `file` | yes | The trait file. |
| `min_followup` | | Remove probands born less than this many years before `study_end`. |
| `max_followup` | | Follow every proband for this many years from birth: remove those born too late to be followed that long, and censor anything later at this age. |
| `max_followup_relatives` | | The same window for people counted as relatives. Empty: the same as `max_followup`. `none`: no window. |
| `trait2` | | Another trait in this list, used only by the next four columns (its status-1 onsets). |
| `exclude_trait2` | | `none` (default), `before`, `after` or `any`: when `trait2`'s onset flags a proband, compared with this trait's age. The same age counts as before. |
| `trait2_window` | | Years between the two onsets; empty for any gap. |
| `trait2_window_type` | | `within` (default; gap at most the window) or `at_least` (gap at least the window). |
| `trait2_action` | | `exclude` (default; remove flagged probands) or `competing` (keep them, as a competing event at `trait2`'s onset; needs `before`). |
| `filter_relatives` | | `TRUE`: people a rule removed or recoded as probands are removed or recoded as relatives too. Default `FALSE`. |

These rules are those of `R/make_epimight_tte.R` (its guide is in `docs/`), and the
self-test checks that the kit's cohort table matches that script's for every rule.
Examples (tab-separated in the file; columns left out are empty):

```
trait      type  file      max_followup  trait2  exclude_trait2  trait2_action
adhd_fu20  tte   adhd.tsv  20
adhd_fu30  tte   adhd.tsv  30
mdd        tte   mdd.tsv                 bip     before          competing
bip        tte   bip.tsv
```

`adhd_fu20` and `adhd_fu30` are the same file followed for 20 and 30 years. `mdd` ends a
person's MDD follow-up at their BIP onset when BIP came first.

### relative_windows.tsv (optional)

Overrides `max_followup_relatives` for one trait and relationship:

```
trait      relationship  max_followup_relatives
adhd_fu20  PO            50
```

follows parents for 50 years while probands get 20.

### analyses.tsv: the analysis list

One row per estimate: `analysis_id, analysis, trait, relatives_trait, relationship`.

- `analysis_id`: your name for it, carried by every output row.
- `analysis`: `h2` (`relatives_trait` equals `trait`) or `rg`: the `trait` outcome of
  probands whose relatives have `relatives_trait`. rg is one direction; list both if
  you want both.
- `relationship`:

| Code | Relatives | Relatedness |
|---|---|---|
| `PO` | parents | 0.5 |
| `FS` | full siblings (MZ twins included) | 0.5 |
| `HS` | half siblings | 0.25 |
| `mHS`, `pHS` | maternal, paternal half siblings | 0.25 |
| `Av` | aunts and uncles | 0.25 |
| `1G` | grandparents | 0.25 |
| `1C` | first cousins | 0.125 |

A relative counts only if they have a row in the trait file (after any relatives'
window). PO, Av and 1G count a person's elders by their place in the pedigree, not by
birth order.

## Outputs

All tables are tab-separated, `NA` for missing, numbers rounded to 6 significant digits
(`out/4_tables/tables.rds` keeps them unrounded).

- `h2.tsv`: per analysis, one row per stratum and a pooled row (`level`), with the age
  used (`age_min`, `age_max`), `n_strata`, `h2`, the sandwich SE and 95% interval
  (`se_sandwich`, `l95_sandwich`, `u95_sandwich`), EPIMIGHT's own SE (`se_native`) and a
  `note`.
- `rg.tsv`: the same for rg, plus `rhh` and both h² at the rg age, which explain why rg
  need not match the h² rows.
- `cif.tsv`: the cumulative incidence curves each analysis uses (`cohort`: population,
  family_history or cross), per stratum and age.
- `cohort_summary.tsv`: per trait, relationship and stratum, the probands, their
  outcomes, and how many have relatives and affected relatives.
- `run.yaml`: versions, input checksums, settings, warnings and how EPIMIGHT's calls went.

A stratum or analysis EPIMIGHT cannot estimate keeps its row, with NA and a `note` saying
why (for example `no proband in this stratum with a PO relative affected by adhd`). Use the
sandwich interval; `se_native` treats relatives as independent.

## What stops a run

`out/1_check/findings.tsv` lists every problem with a code, the file, a count and up to
ten examples. Any STOP ends the run after the check step.

- study.yaml: `study_unreadable`, `study_unknown_key`, `study_missing_key`,
  `study_value_invalid`, `file_missing`, `study_end_invalid`, `stratify_invalid`.
- traits.tsv: `traits_unreadable`, `traits_missing_column`, `traits_unknown_column`, `trait_name_invalid`,
  `trait_duplicate`, `trait_type_unknown`, `trait_file_missing`, `trait_rule_invalid`,
  `trait2_missing`, `trait2_unknown`, `trait2_self`, `trait2_competing_needs_before`.
- analyses.tsv: `analyses_unreadable`, `analyses_missing_column`, `analyses_unknown_column`,
  `analysis_id_invalid`, `analysis_id_duplicate`, `analysis_unknown`,
  `relationship_unknown`, `h2_relatives_trait_differs`, `rg_same_trait`,
  `analysis_duplicate`, `analysis_trait_unknown`, `max_degree_below_relationship`.
- relative_windows.tsv: `relative_windows_unreadable`, `relative_windows_missing_column`,
  `relative_windows_unknown_column`, `relative_windows_trait_unknown`,
  `relative_windows_duplicate`, `relationship_unknown`, `trait_rule_invalid`.
- Pedigree: `pedigree_unreadable`, `pedigree_missing_column`, `parent_zero`,
  `birth_date_missing`, `birth_date_invalid`, `stratify_not_in_pedigree`, `stratum_na`,
  `pedigree_invalid` (pedsum's checks; details in `1_check/pedsum/validate.log`),
  `external_parent_over_cap`.
- Trait files: `trait_file_unreadable`, `trait_file_missing_column`, `trait_id_missing`,
  `trait_duplicate_id`, `trait_file_trait_values`, `status_invalid`, `age_invalid`,
  `date_invalid`, `trait_id_not_in_pedigree`, `date_before_birth`,
  `date_after_study_end`, `age_date_mismatch`, `trait_population_differs`.
- Installation: `pins_mismatch` (run `pixi run setup`).

Warnings are recorded and the run goes on: `external_parents`, `pedigree_autofixed`,
`few_cases` (fewer than 10 cases in a stratum), `trait2_unused`,
`pedigree_birth_year_replaced`.

Later steps stop on `trait_no_probands` (a trait's rules left nobody) and, in the tables
step, on any EPIMIGHT error the kit did not predict (`epimight_error_unpredicted`,
`epimight_prediction_unmet`, `rg_age_rebuild_mismatch`); please report those.

## Open questions for collaborators

1. Relatives count only if they have a row in the trait file, and a relatives' window
   applies only when set. Is that what `make_epimight_tte` intends?
2. PO, Av and 1G count a person's elders by pedigree role. EPIMIGHT's registry SQL and
   `make_epimight_tte`'s `vertical = "older"` use birth order instead. Which do you want?
3. Every trait file must hold the same people. Do your registers need trait files with
   different people?

## Also in this repository

- `R/make_epimight_tte.R`, its guide in `docs/`, and `R/Summarise_incidence.R`: the
  collaborators' scripts. `Definitions/Phenotype_list.tsv`: the phenotype definitions.
- `nordicepimight/`: the kit's R package (`pixi run test` runs its tests, `pixi run lint`
  its linter); `steps/`: one script per step.
- `GLOSSARY.md` and `docs/adr/`: the kit's terms and design decisions.
