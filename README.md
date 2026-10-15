# nordic-geno-epimight

A series of R scripts (kit) to run [EPIMIGHT](https://github.com/BioPsyk/epimight) analyses in parallel across the registers of Denmark, Norway and Sweden. Birth year-stratified estimates of cumulative incidence function (CIF), heritability (h²) and genetic correlation (rg) are produced within each country.

Repo structure: The repo is split into `plan/` and `local/` folders. The `plan/` folder applies to all countries and contains files describing the traits and the analyses to be conducted. The `local/` folder contains a single config file, unique to each country, describing how to find the input data and a bit about how to run the analysis (e.g. number of cores). The repo also contains some documentation and associated files.

The kit checks the data, builds input for EPIMIGHT, runs EPIMIGHT, and collects the output. In addition to the raw output, the kit can produce plots and summaries of the results, as well as prepare the results for export by suppressing small counts.

| # | Step | Description |
|---|---|---|
| 0 | `prepare` | Convert country-specific registry data to common phenotype and pedigree data formats. Prerequisite for these analyses. |
| 1 | `check` | Checks and validates input data - including both phenotype and pedigree data |
| 2 | `cohort` | Selects individuals for analysis, applies the trait rules and counts each person's relatives, writing `cohort.tsv` |
| 3 | `epimight` | Runs EPIMIGHT once for each estimate the analyses need |
| 4 | `tables` | Collects and synthesizes the EPIMIGHT output |
| 5 | `report` | Prepares plots of the results and summaries |
| 6 | `export` | Prepares the data for export by suppressing PII. |

Each step relies on the output of previous step(s). Rerunning a step deletes the output of
the steps after it. If an input file changes after `check`, the later steps stop until you
rerun `check`.

Current status: **preliminary**.

## Install

The kit needs [pixi](https://pixi.sh) 0.82. pixi installs one binary under
`~/.pixi/bin` and doesn't need root. Its installer fetches the latest release unless told
otherwise, and the kit refuses any other series, so name the version:

```sh
curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION=v0.82.0 bash
export PATH="$HOME/.pixi/bin:$PATH"
pixi --version
```

The installer also adds `~/.pixi/bin` to `PATH` in your shell's startup file. If
`pixi --version` fails in a new terminal, add the `export` line there yourself. If you
already have pixi at another version, switch with:

```sh
pixi self-update --version v0.82.0
```

Then get the kit and install it:

```sh
git clone https://github.com/rwaples/nordic-geno-epimight.git
cd nordic-geno-epimight
pixi install --locked
pixi run setup
pixi run selftest selftest-out/
```

`setup` downloads and compiles EPIMIGHT and pedigreegraph from Github at the commits pinned in
`kit/nordicepimight/inst/pins.yaml`. It needs internet access and takes about 3 minutes
the first time. Every run checks that the installed versions match the pins.

`selftest` runs the kit on a simulated toy site and compares its results with values
computed independently. It takes about 2 minutes, prints one PASS, FAIL or SKIP line per
check, and exits 1 if any check fails. Run it before using your own data.
`kit/selftest/README.md` describes each check.

## Run at your site

1. Prepare your data folder (step 0, below).
2. Copy `local/example.yaml` to `local/<your site>.yaml` and fill it in. Files in `local/`
   are not committed.
3. Run every step:

   ```sh
   pixi run study local/denmark.yaml out/
   ```

4. Send `out/6_export/`. Nothing else in `out/` may leave your server: it holds
   individual-level data.

Start with the initial plan. For the complete one, change `plan:` in your site file to
`../plan/complete.yaml` and use a new output folder.

`pixi run study` runs six steps in order. You can run one at a time with
`pixi run <step> local/denmark.yaml out/`. To try it on the toy site, use
`kit/selftest/toy/site.yaml` in place of your site file.

| Step | Output | Does |
|---|---|---|
| `prepare` | your data folder | Your own scripts; the kit has no command for it (below) |
| `check` | `out/1_check/` | Checks every input and lists each problem in `findings.tsv` |
| `cohort` | `out/2_cohort/` | Applies the trait rules and counts each person's relatives, writing `cohort.tsv` |
| `epimight` | `out/3_epimight/` | Runs EPIMIGHT once for each estimate the analyses need |
| `tables` | `out/*.tsv`, `out/run.yaml` | Writes the result tables |
| `report` | `out/report.html` | Writes one page with every result and plot |
| `export` | `out/6_export/` | Writes the folder to share, with small counts suppressed |

### Step 0: prepare your data

Each site converts its own registers into the kit's formats. The trait files go in one
data folder, one file per trait in `plan/traits.tsv`, named as its `file` column says
(`MDD.tsv`, ...). The pedigree file can be anywhere; the site file names both. The
formats are under [Inputs](#inputs). Trait definitions, including ICD codes, are in
`Definitions/Phenotype_list.tsv`.

See the statistical analysis plan (`docs/Firstpass_SAP_Scandinavian_Genealogy.txt`) for a list of considerations when preparing this data.

A partial list:
- Remove known legal but not biological pedigree links:
  - Adoption
  - Same-sex parents: keep the birth mother if identified
- Disregard major depressive disorder (MDD), bipolar disorder (BD), and schizophrenia (SCZ) diagnoses before age 10.
- Main vs auxiliary (secondary) diagnoses (open question 9).
- Birth location and civil register - any special handling that is necessary.
- For making the analysis windows (W1 - W4) implement appropriate filters on diagnosis time. Do not filter by birth year here; that will happen in step 2.

Last, repair the pedigree with pedsum. The kit never changes the pedigree. Its check step
runs `pedsum validate` and stops on anything pedsum finds, such as a parent without a row
of its own, a duplicate row or a sex that contradicts a parent role. Add a `birth_year`
column (the year of `birth_date`) and run:

```sh
pixi run pedsum validate --in pedigree.tsv --out pedsum/ --birth-year-col birth_year
gunzip -c pedsum/validate.tsv.gz > pedigree_validated.tsv
```

Then point `pedigree_path` at `pedigree_validated.tsv`. pedsum adds a founder row, with no
`birth_date`, for each parent without a row of its own. Check those parents in
`pedsum/validate.log` first. A parent id with many children is probably a code for an
unknown parent; rerun with `--missing-parent-token <code>`. If pedsum stops or finds
something it doesn't repair, see its `--drop-offending` and `--break-cycles` options.

## Inputs

All tables are tab-separated and include a header row. Missing values are `NA` or an
empty cell. Ids are read as text, so `001`, `1` and `1.0` are three different people.
Relative paths are resolved from the folder of the file that names them; the trait files
from your data folder.

### Site file

```yaml
site: Denmark                         # the name your results carry
plan: ../plan/initial.yaml            # the shared plan
data_folder: /path/to/trait/files     # the trait files
pedigree_path: /path/to/pedigree.tsv  # the pedigree; it need not be in data_folder
study_end: 2021-12-31                 # end of register follow-up at this site
threads: 4                            # optional, default 1
```

### Plan

Two plan files hold the settings every site shares: `plan/initial.yaml` for the initial
analysis and `plan/complete.yaml` for the complete one (`plan/README.md`). Each looks
like this:

```yaml
traits: traits.tsv
analyses: analyses_initial.tsv
relative_windows: relative_windows.tsv   # optional
stratify: [birth_year]                   # pedigree columns, or birth_year
birth_year_bin: 5                        # default 1
max_degree: 3                            # 1 to 5, default 3
export_min_count: 5                      # default 5
```

EPIMIGHT estimates each stratum separately and then pools them. `birth_year` is the year
of `birth_date`, grouped into `birth_year_bin`-year bins named by their first year.

`max_degree` sets which relative pairs enter the sandwich SE. It must reach the furthest
relationship analysed: 1 for PO and FS, 2 for HS, mHS, pHS, Av and 1G, 3 for 1C.

### Pedigree

One row per person with `id, mother, father, sex, birth_date`, plus any column you
stratify on. Write an unknown parent as `NA`, empty or `-1`. Use `0` only if 0 is a real
id. Sex is 1 for male, 2 for female and 0 for unknown. Dates are `YYYY-MM-DD`. Everyone
in the trait files needs a `birth_date`; other people may leave it empty. pedsum validate
must find nothing wrong with the file (step 0).

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

### plan/traits.tsv

One row per trait. A trait is a name, a file and optional rules. Several traits can share
a file.

| Column | Meaning |
|---|---|
| `trait` | Name used in the analyses: letters, digits, `_`, `.` or `-` |
| `type` | `tte` (time to event), the only type so far |
| `file` | The trait file's name in each site's data folder |
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

### plan/relative_windows.tsv

Optional. Sets `max_followup_relatives` for one trait and relationship. This row follows
parents for 50 years while probands get 20:

```
trait      relationship  max_followup_relatives
adhd_fu20  PO            50
```

### plan/analyses.tsv

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
| `run.yaml` | Site, plan checksum, versions, input checksums, settings, warnings and EPIMIGHT's calls |

Report the sandwich interval. `se_native` treats relatives as independent and is there
only for comparison. When EPIMIGHT can't estimate a stratum or an analysis, its row stays
with NA and a note giving the reason.

### The folder to share

`out/6_export/` holds the five files above and a report built from them. Every count
from 1 to `export_min_count` (5) is suppressed: such cells in `cohort_summary.tsv` are
NA, and so are the other two of cases, competing and censored when one of them is, since
they sum to the probands. CIF rows whose cumulative cases are 1 to 5 are left out.
`run.yaml` names the input files without their paths and records what was suppressed.
These rules are preliminary: nothing yet covers small differences between neighbouring
cells, such as one new case between two ages of a CIF curve.

## When a run stops

The check step stops on any input it can't use: unknown keys or columns, missing files,
bad dates, ages or statuses, an age that disagrees with its date, duplicate ids, ids
missing from the pedigree, trait files with different people, a missing stratum value,
anything pedsum validate finds in the pedigree, or installed packages that don't match
the pins. Each line of `out/1_check/findings.tsv` has a code, the file, a count, examples
and what is wrong.

Some problems are warnings and don't stop the run, for example fewer than 10 cases in a
stratum.

Two later stops can happen. The cohort step stops if a trait's rules leave nobody. The
tables step stops if EPIMIGHT fails in a way the kit didn't predict. Please report that
one.

## Repository layout

- `plan/`: the shared analysis plan.
- `local/`: each site's file (not committed), and `example.yaml`.
- `kit/`: the kit's R package (`nordicepimight/`), its setup script, and the self-test's
  toy site, expected results and the scripts that build them. `pixi run test` and
  `pixi run lint` check the package.
- `R/`, `Definitions/`: the collaborators' scripts and phenotype definitions.
- `docs/`: the glossary, design decisions (`adr/`), open questions, the collaborators'
  guide and statistical analysis plan (SAP), and where the kit falls short of the SAP
  (`SAP_kit_gaps.md`).
