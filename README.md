# nordic-geno-epimight

Estimates heritability (h²) and genetic correlation (rg) from register data with
[EPIMIGHT](https://github.com/BioPsyk/epimight), using pedigree-pair sandwich standard
errors. You provide a pedigree, one file per trait, a trait list and an analysis list.
The kit checks them, builds EPIMIGHT's input, runs EPIMIGHT, and writes tables and an
HTML report. It runs in R, except the pedigree check, which uses
[pedsum](https://github.com/rwaples/pedsum).

## Install

Install [pixi](https://pixi.sh) 0.76, then run from this folder:

```sh
pixi install --locked
pixi run setup
pixi run selftest selftest-out/
```

`setup` downloads and compiles EPIMIGHT and pedigreegraph at the commits pinned in
`nordicepimight/inst/pins.yaml`. It needs internet access and takes about 3 minutes the
first time. Every run checks that the installed versions match the pins.

`selftest` runs the kit on a simulated toy study and compares its results with values
computed independently. It takes about 2 minutes, prints one PASS, FAIL or SKIP line per
check, and exits 1 if any check fails. Run it before using your own data.
`selftest/README.md` describes each check.

## Run a study

```sh
pixi run study selftest/toy/study.yaml out/
```

This runs five steps in order. You can also run one at a time with
`pixi run <step> study.yaml out/`.

| Step | Output | Does |
|---|---|---|
| `check` | `out/1_check/` | Checks every input and lists each problem in `findings.tsv` |
| `cohort` | `out/2_cohort/` | Applies the trait rules and counts each person's relatives, writing `cohort.tsv` |
| `epimight` | `out/3_epimight/` | Runs EPIMIGHT once for each estimate the analyses need |
| `tables` | `out/*.tsv`, `out/run.yaml` | Writes the result tables |
| `report` | `out/report.html` | Writes one page with every result and plot |

Each step needs the previous one to have finished. Rerunning a step deletes the output of
the steps after it. If an input file changes after `check`, the later steps stop until you
rerun `check`.

## Inputs

All tables are tab-separated with a header row. A missing value is `NA` or an empty cell.
Ids are text, so `001`, `1` and `1.0` are three different people. Relative paths are
resolved from the folder of the file that names them.

### study.yaml

```yaml
pedigree: pedigree.tsv
traits: traits.tsv
analyses: analyses.tsv
relative_windows: relative_windows.tsv   # optional
study_end: 2023-12-31                    # end of register follow-up
stratify: [birth_year]                   # pedigree columns, or birth_year
birth_year_bin: 5                        # optional, default 1
threads: 4                               # optional, default 1
max_degree: 3                            # optional, 1 to 5, default 3
external_parent_cap: 30                  # optional, default 30
```

EPIMIGHT estimates each stratum separately and then pools them. `birth_year` is the year
of `birth_date`, grouped into `birth_year_bin`-year bins named by their first year.

`max_degree` sets which relative pairs enter the sandwich SE. It must reach the furthest
relationship you analyse: 1 for PO and FS, 2 for HS, mHS, pHS, Av and 1G, 3 for 1C.

A parent id without its own row is added as a founder. If it has more children than
`external_parent_cap`, the run stops, because it is probably a code for an unknown parent.

### Pedigree

One row per person with `id, mother, father, sex, birth_date`, plus any column you
stratify on. Write an unknown parent as `NA`, empty or `-1`. Use `0` only if 0 is a real
id. Sex is 1 for male, 2 for female and 0 for unknown. Dates are `YYYY-MM-DD`.

### Trait files

One file per trait with `id, trait, status, age, date`, and one row for each person in the
study population.

| Column | Meaning |
|---|---|
| `status` | 1 has the trait, 2 had a competing event such as death, 0 censored |
| `age` | Years from birth to the status: onset, competing event or end of follow-up |
| `date` | Date of the status. It must match `age` to within a day |
| `trait` | One value for the whole file. The kit records it but doesn't use it |

Ages may have fractions. EPIMIGHT uses whole years.

All trait files must list the same people. If you exclude someone from a trait, keep their
row and censor it (status 0) at the age they leave follow-up.

### traits.tsv

One row per trait. A trait is a name, a file and optional rules. Several traits can share
a file.

| Column | Meaning |
|---|---|
| `trait` | Name used in the analyses: letters, digits, `_`, `.` or `-` |
| `type` | `tte` (time to event), the only type so far |
| `file` | The trait file |
| `min_followup` | Drop probands born fewer than this many years before `study_end` |
| `max_followup` | Follow every proband for this many years. Drop those born too late, and censor later events at this age |
| `max_followup_relatives` | The same window for relatives. Empty means the same as `max_followup`; `none` means no window |
| `trait2` | Another trait whose onsets the next four columns use |
| `exclude_trait2` | When a `trait2` onset flags a proband: `none` (default), `before`, `after` or `any`. The same age counts as before |
| `trait2_window` | Years between the two onsets. Empty means any gap |
| `trait2_window_type` | `within` (default): gap at most the window. `at_least`: gap at least the window |
| `trait2_action` | `exclude` (default) drops flagged probands. `competing` keeps them, with a competing event at the `trait2` onset; it needs `before` |
| `filter_relatives` | `TRUE` also applies the proband rules to relatives. Default `FALSE` |

The rules follow `R/make_epimight_tte.R`, and the self-test checks that the kit builds the
same table as that script for every rule. An example, with empty columns left out:

```
trait      type  file      max_followup  trait2  exclude_trait2  trait2_action
adhd_fu20  tte   adhd.tsv  20
adhd_fu30  tte   adhd.tsv  30
mdd        tte   mdd.tsv                 bip     before          competing
bip        tte   bip.tsv
```

`adhd_fu20` and `adhd_fu30` follow the same people for 20 and 30 years. In `mdd`, a BIP
onset before MDD ends MDD follow-up as a competing event.

### relative_windows.tsv

Optional. Sets `max_followup_relatives` for one trait and relationship. This row follows
parents for 50 years while probands get 20:

```
trait      relationship  max_followup_relatives
adhd_fu20  PO            50
```

### analyses.tsv

One row per estimate, with `analysis_id, analysis, trait, relatives_trait, relationship`.
`analysis_id` is your name for the estimate and appears on every output row.

`analysis` is `h2` or `rg`. For h2, `relatives_trait` equals `trait`. For rg, the estimate
uses the `trait` outcomes of probands whose relatives have `relatives_trait`. That is one
direction, so list both rows if you want both.

| `relationship` | Relatives | Relatedness |
|---|---|---|
| `PO` | parents | 0.5 |
| `FS` | full siblings, MZ twins included | 0.5 |
| `HS` | half siblings | 0.25 |
| `mHS`, `pHS` | maternal or paternal half siblings | 0.25 |
| `Av` | aunts and uncles | 0.25 |
| `1G` | grandparents | 0.25 |
| `1C` | first cousins | 0.125 |

A relative counts only if they have a row in the trait file. PO, Av and 1G follow the
pedigree, not birth order: an uncle younger than his nephew is still his uncle.

## Outputs

Tables in `out/` round numbers to 6 significant digits. `out/4_tables/tables.rds` has
the unrounded values.

| File | Contents |
|---|---|
| `h2.tsv` | One row per stratum and a pooled row for each h2 analysis: ages used, h2, sandwich SE and 95% interval, EPIMIGHT's own SE, and a note |
| `rg.tsv` | The same for rg, plus `rhh` and both h2 values at the age rg uses |
| `cif.tsv` | The cumulative incidence curves each analysis uses |
| `cohort_summary.tsv` | Probands, outcomes and relatives per trait, relationship and stratum |
| `run.yaml` | Versions, input checksums, settings, warnings and EPIMIGHT's calls |

Report the sandwich interval. `se_native` treats relatives as independent and is there
only for comparison. When EPIMIGHT can't estimate a stratum or an analysis, its row stays
with NA and a note giving the reason.

## When a run stops

The check step stops on any input it can't use: unknown keys or columns, missing files,
bad dates, ages or statuses, an age that disagrees with its date, duplicate ids, ids
missing from the pedigree, trait files with different people, a missing stratum value,
pedigree errors from pedsum, or installed packages that don't match the pins. Each line
of `out/1_check/findings.tsv` has a code, the file, a count, examples and what is wrong.

Some problems are warnings and don't stop the run, for example parents without their own
row, or fewer than 10 cases in a stratum.

Two later stops can happen. The cohort step stops if a trait's rules leave nobody. The
tables step stops if EPIMIGHT fails in a way the kit didn't predict. Please report that
one.

## Repository layout

- `R/`, `docs/`, `Definitions/`: the collaborators' scripts, guide and phenotype
  definitions.
- `nordicepimight/`: the kit's R package. `pixi run test` and `pixi run lint` check it.
- `steps/`: one script per step.
- `selftest/`: the toy study and its expected results.
- `GLOSSARY.md`, `docs/adr/`: terms and design decisions.
- `docs/open-questions.md`: questions for the collaborators that may change the kit.
