# Step 0: Getting country-specific register data into common formats

This is a guide to step 0, preparing your register data for the kit. The rules come
from version 8 of the statistical analysis plan, `SAP_Scandinavian_Genealogy.md`.

Each rule has a tag:

| Tag | Meaning |
|---|---|
| **[SAP x.y]** | Required by that section of the SAP |
| **[kit]** | Required by the kit. `check` stops if you break it |
| **[kit, unchecked]** | The kit's results depend on it, but `check` can't see it |
| **[recommended]** | Our default. If you do something else, write it down |

The kit checks formats, and pedsum checks the pedigree's structure (section 1.4). The
**[SAP]**, **[kit, unchecked]** and **[recommended]** rules are yours to get right.

This page is the one reference for the input formats. The commands below are written
for a checkout of the kit ([run-with-pixi.md](run-with-pixi.md)): run them from the kit's
folder. With the Apptainer image, [run-with-image.md](run-with-image.md) gives each one
in image form. Terms in bold are in the [glossary](glossary.md); the open questions
cited below are in [open-questions.md](open-questions.md).

The initial plan uses window W1 (section 2.4) only, so you need one data folder and one
site file. W2 and W3 can't be run yet.

## The short version

1. Export the pedigree and run it through pedsum (section 1).
2. Build one trait file per trait for window W1 (section 2).
3. Write your site file (section 3).
4. Run `pixi run check local/<site>.yaml /path/to/out/` and fix every finding (section
   4.1).
5. Do your own checks (section 4.2).
6. Write your site note (section 4.3).

## Rules for every file

- Tab-separated text files, with a header row. **[kit]**
- Missing values: `NA` or an empty cell. pedsum's output writes empty cells, which is
  fine. In the trait files anything else, such as Stata's `.`, is read as a value.
- The kit reads ids as text: `001`, `1` and `1.0` are three different people.
- `0` is an ordinary id. If your register writes an unknown parent as `0`, see 1.1.
- Column names are case-sensitive: `Code` is not `code`. Other columns are allowed and
  ignored.
- Dates should be in this format: `YYYY-MM-DD`. **[kit]**
- No commas within numbers.

## 1. The pedigree

One file, used by every trait and window.

### 1.1 Format

One row per person.

| Column | Type | Content | |
|---|---|---|---|
| `id` | text | Person id | required |
| `mother` | text | Mother's id, or missing | required |
| `father` | text | Father's id, or missing | required |
| `sex` | integer | `1` male, `2` female, `0` unknown | required |
| `birth_date` | date, `YYYY-MM-DD` | Date of birth. Everyone with trait rows needs one; other people may have `NA` | required **[kit]** |
| `birth_year` | integer, 4 digits | Must agree with `birth_date` | optional |
| `multiple_birth_id` | integer | Same number for everyone born in one delivery, `NA` for single births. Each delivery gets its own number | optional |
| `birth_place` | text | Country of birth as an ISO 3166-1 alpha-2 code (`DK`, `SE`, `NO`, ...), `NA` if unknown | optional |

- Missing parent: `NA`, `-1`, or your own code passed to pedsum with
  `--missing-parent-token`. pedsum stops on a `0` parent that has no row of
  its own unless you pass `--missing-parent-token 0`. **[kit]**
- Give every parent a row of their own where you can.
- Fill `birth_place` if your register has it. The SAP restricts probands to people born
  in the country (4.1). The kit doesn't use the column yet (issue #12). **[recommended]**

### 1.2 Who goes in

Everyone in the civil register, including people without phenotypes, since they connect
other relatives. **[SAP 4.1]**

### 1.3 Rules

- **Adoptions.** Keep adoptive parent links. Don't replace or sever them. **[SAP 4.1]**
- **Same-sex parents.** Two mothers: set the father ID to `-1`. Two fathers: set the
  mother ID to `-1`. **[SAP 4.1]**
- **Unknown-parent codes.** Replace any placeholder used for unknown parents, such as
  `9999`, with a missing value, or let pedsum do it (1.4). **[kit]**
- **Twins.** If your register records multiple births, put them in the `multiple_birth_id` column
  and set `multiple_birth_column: multiple_birth_id` in your site file. **[recommended]**
  The kit leaves same-sex pairs from one multiple birth, and pairs with an unknown sex,
  out of FS as possible MZ twins. Boy-girl pairs stay full siblings. **[SAP 4.1]**
  Don't remove twins from the pedigree.
  Twins stay probands and every other kind of relative: a twin's children are still the
  co-twin's nieces and nephews.
- **Multiple-birth sets without `multiple_birth_id`.** The kit's check step makes full
  siblings born at most a day apart a set (pedsum `--twin-max-days 1`), whatever you
  used in 1.4.

### 1.4 Run pedsum

**pedsum** checks and repairs the pedigree; it comes with the kit (v0.18.0). Run it with
the same settings the kit's check step uses, from the kit's folder, with your paths in
full and outside the kit's folder:

```sh
pixi run pedsum validate --in /path/to/data/pedigree.tsv --out /path/to/data/pedsum/ \
  --birth-year-col birth_year --birth-date-col birth_date --twin-max-days 1 \
  --max-children-mother 20 --max-children-father 50
gunzip -c /path/to/data/pedsum/validate.tsv.gz > /path/to/data/pedigree_validated.tsv
```

In PowerShell on Windows, use the same commands from [windows.md](windows.md#4-step-0-in-powershell).

With `multiple_birth_id`, replace `--twin-max-days 1` with
`--multiple-birth-col multiple_birth_id`. If your register writes unknown parents as `0`
or another code, add `--missing-parent-token <code>`.

Use `pedigree_validated.tsv`, pedsum's output, as `pedigree_path` in your site file
(section 3). The kit's check step runs pedsum again on it and stops on any finding. Your
original file would fail that check wherever pedsum repaired it, for example by adding a
**founder row** for a parent without one.

Go through `/path/to/data/pedsum/validate.log` and what pedsum prints:

| Finding | Do this |
|---|---|
| `parent_child_count` | A mother with more than 20 children or a father with more than 50. Almost always a code for an unknown parent, such as `9999`: check that the id is such a code, then delete its own row if it has one and rerun with `--missing-parent-token <code>` |
| Duplicate row, wrong sex for a parent, parent born after child, cycle | Fix it in your source data. Otherwise use `--drop-offending` or `--break-cycles` |
| `multiple births:` line, printed to the terminal | Counts of multiple-birth sets. To spot placeholder birth dates, run pedsum once more with `--twin-max-days 7` (pedsum's most) and `--out` set to another folder, and compare the counts: sets found at 7 days but not at 1 usually mean placeholder dates. Fix them. Don't use that run's output |
| Multiple-birth set whose members aren't all full siblings, or with one member | pedsum clears it and its members count as single births. Check `multiple_birth_id` or the parent links |

## 2. The trait files

One file per trait, all in one folder (`data_folder` in the site file), named as the `file`
column of `plan/traits.tsv` says (section 2.3). **[kit]**

### 2.1 Format

One row per person in the study population (2.2).

| Column | Type | Content |
|---|---|---|
| `id` | text | Person id, matches ids in the pedigree |
| `trait` | text | One value for the whole file, for example `MDD`, matching the trait definitions in `Definitions/Phenotype_list.tsv`. The kit doesn't compare it with anything |
| `status` | integer | `1` has the trait (affected), `2` mortality while unaffected, `0` censored |
| `status_date` | date, `YYYY-MM-DD` | The date that set `status` |
| `code` | text | Optional. ICD code of the first diagnosis for cases (`status 1`), `NA` for everyone else |

Don't put `age` in the trait files. The kit computes it from `birth_date` and
`status_date`.

`check` stops if: **[kit]**

- an `id` is missing, duplicated, or not in the pedigree
- `trait` doesn't hold exactly one value
- `status` isn't 0, 1 or 2
- `status_date` isn't a date, is before the birth date, or is after `study_end`
- `code`, if present, isn't `NA` for someone whose `status` is 0 or 2
- the trait files don't all list the same people
- someone in the trait files has no birth date in the pedigree

### 2.2 Who gets a row

- Everyone in the civil register with a valid birth date and sex. **[recommended]**
- Born on or before `study_end`. **[kit]**
- The same people in every trait file. Someone a rule excludes from a trait keeps a row
  with `status 0`. **[kit]**
- No birth-year filter. Relatives of every age need rows. **[kit, unchecked]**
- Keep people born abroad, and count them. **[recommended]**
- Parents found only through parent links may stay in the pedigree without trait rows.
  They won't count as relatives. **[recommended]**

### 2.3 The traits

Codes are in `Definitions/Phenotype_list.tsv` until the reviewed list replaces it.
**[SAP 5]**

| File | Trait | Ignore diagnoses before age |
|---|---|---|
| `MDD.tsv` | Major depressive disorder | 10 |
| `ASD.tsv` | Autism spectrum disorder | 4 |
| `BD.tsv` | Bipolar disorder | 10 |
| `SCZ.tsv` | Schizophrenia | 10 |
| `SSD.tsv` | Schizophrenia spectrum disorder | |
| `CVD.tsv` | Cardiovascular disorders combined | |
| `CMD.tsv` | Cardiometabolic disorders combined | |
| `AS.tsv` | Any stroke | |
| `T2.tsv` | Type 2 diabetes | |
| `MI.tsv` | Myocardial infarction | |
| `IHD.tsv` | Ischaemic heart disease | |
| `HF.tsv` | Heart failure | |
| `AF.tsv` | Atrial fibrillation/flutter | |
| `PAD.tsv` | Peripheral artery disease/atherosclerosis | |
| `OBE.tsv` | Obesity | |
| `DYS.tsv` | Dyslipidaemia | |
| `HYP.tsv` | Essential hypertension | |
| `HS.tsv` | Haemorrhagic stroke | |
| `IS.tsv` | Ischaemic stroke | |

Deliver MDD, BD and SCZ as they are, without removing anyone for having another of the
three. The plan is meant to apply the hierarchy with second-trait rules; the current
preliminary plan has none yet (open question 10). **[SAP 5.3]**

### 2.4 Windows

**[SAP 4.2]**

| | W1 | W2 | W3 |
|---|---|---|---|
| Diagnoses counted | All years, all ICD versions | Same as W1 | Made 2008-01-01 to 2021-12-31, ICD-10 only |
| `study_end` | DK 2023-12-31, SE 2024-12-31, NO 2021-12-31 | Same as W1 | 2021-12-31 |
| Probands | All | Born 1960 to 2007 | Born 1985 to 2005 (2015 for ASD) |
| Trait files | Own set | W1's | Own set |

Build W1 first. It's the only window the kit can run today.

### 2.5 Which diagnoses count

- Inpatient and outpatient contacts, main or secondary diagnosis. **[SAP 5.1]**
- Causes of death. A death from the trait is `status 1`. For CVD, take the earlier of the
  patient registers and the cause of death register. **[SAP 5.1]**
- Not primary care. **[recommended]**
- ICD versions: ICD-8, ICD-9 and ICD-10 in W1 and W2, ICD-10 only in W3. **[SAP 5.1]**
- W3: ignore every diagnosis before 2008, for everyone. **[SAP 4.2]**
- Match codes by prefix (`F32` matches `F32.0` to `F32.9`). Handle your country's
  formats, with or without the dot, and Swedish ICD-9 letter endings such as `296B`.
  **[recommended]**

### 2.6 Age limits

- MDD, BD, SCZ: ignore diagnoses before age 10. **[SAP 5.2]**
- ASD: ignore diagnoses before age 4. **[SAP 5.2]**
- Someone whose only diagnoses fall before the limit counts as never diagnosed.
  **[SAP 5.2]**
- W3: apply the limit to the first diagnosis inside the window. **[SAP 5.2]**

### 2.7 Status and date

| What happened | `status` | `status_date` | |
|---|---|---|---|
| A diagnosis that counts | 1 | The earliest one | **[SAP 5.2]** |
| No diagnosis, died | 2 | Date of death | **[SAP 4.1]** |
| No diagnosis, emigrated | 0 | Emigration date | **[SAP 4.1]** |
| No diagnosis, still followed | 0 | `study_end` | **[SAP 4.1]** |

- Date a diagnosis by the contact's start (admission) date, or the date of death for a
  cause of death. **[recommended]**
- Diagnosis and death on the same day: `status 1`. **[recommended]**
- Emigrated and came back: censor at the first emigration. **[recommended]**
- Don't drop anyone for short follow-up. **[kit, unchecked]**

### 2.8 Example

Danish W1, `study_end` 2023-12-31.

The blocks are aligned for reading; the real files are tab-separated.

Pedigree:

```
id   mother  father  sex  birth_date
P2   -1      -1      2    1955-11-02
P6   -1      -1      1    1950-02-01
P1   P2      P6      1    1990-03-15
P4   P2      P6      2    1998-01-10
P3   -1      P6      1    2001-07-30
P5   -1      -1      2    2005-05-05
```

`MDD.tsv`:

```
id   trait  status  status_date  code
P1   MDD    1       2012-06-01   F32
P2   MDD    2       2019-04-20   NA
P3   MDD    0       2018-09-01   NA
P4   MDD    0       2023-12-31   NA
P5   MDD    0       2023-12-31   NA
P6   MDD    0       2023-12-31   NA
```

| id | Why |
|---|---|
| P1 | First MDD diagnosis 2012-06-01, code F32 |
| P2 | Died 2019-04-20, never diagnosed |
| P3 | Emigrated 2018-09-01 |
| P4, P6 | Followed to `study_end` |
| P5 | Only diagnosis at age 8, below the limit, so censored at `study_end` |

The kit computes P1's age as 8114 days / 365.25 = 22.2149. All six people also need a
row in the other 18 trait files.

## 3. The site file

Copy `local/example.yaml` to `local/<site>.yaml`. With the image, start from
`apptainer run IMAGE template > <site>.yaml` instead, in any folder.

```yaml
site: Denmark
plan: ../plan/initial.yaml
data_folder: /path/to/trait/files
pedigree_path: /path/to/pedigree_validated.tsv
study_end: 2023-12-31
threads: 4
# multiple_birth_column: multiple_birth_id
```

| Key | Meaning | |
|---|---|---|
| `site` | The name your results carry | required |
| `plan` | The shared plan. `../plan/initial.yaml` in a checkout, `/opt/kit/plan/initial.yaml` in the image; later `complete.yaml` | required |
| `data_folder` | The folder of the trait files (section 2) | required |
| `pedigree_path` | `pedigree_validated.tsv` from section 1.4; it need not be in `data_folder` | required |
| `study_end` | This window's end of follow-up (section 2.4). On or after every `status_date` | required |
| `threads` | Cores to use, a whole number from 1 to 1024. Don't set it above the cores you were given | optional, default 1 |
| `multiple_birth_column` | The pedigree's multiple-birth column, if it has one (section 1.3) | optional |

Any other key stops `check`. Relative paths are read from the site file's folder, not the
folder you run from; with the image, use full paths. **[kit]**

## 4. Checks

### 4.1 What the kit checks

The site file and the plan (section 3), formats (1.1, 2.1), the pedigree through pedsum
(1.4), that every trait file has the same people, and that the installed software
matches the kit's pins. Problems go to `out/1_check/findings.tsv`, one row each with a
severity: `STOP` ends the run, `WARN` doesn't. A `few_cases` warning means a trait has
fewer than 10 cases in some birth-year stratum. When the check passes it also writes
`out/1_check/pedigree_coverage.tsv` (4.2).

### 4.2 What you check

For each trait. Keep the numbers. **[recommended]**

| Check | Expect |
|---|---|
| Study population per birth decade | Matches the civil register |
| Pedigree people without trait rows per birth decade (`pedigree_coverage.tsv`) | Only people you meant to leave out |
| Share with known mother and father per birth decade | A jump where parent links start |
| Cases per trait and birth decade | In line with published prevalence |
| Onset ages | No MDD, BD or SCZ before 10, no ASD before 4 |
| Cases by year of diagnosis | Jumps only at outpatient starts (DK 1995, SE 2001) and ICD changes (DK 1994, SE 1987 and 1997) |
| Status mix per birth decade | More deaths in older cohorts |
| CVD cases from cause of death only | Report the count |
| W3 trait files | No `status 1` before 2008-01-01, no `status_date` after 2021-12-31 |

### 4.3 Site note

Keep a note with your scripts, on your server. Record: **[recommended]**

- register extracts and their dates
- codes per trait, if different from `Definitions/Phenotype_list.tsv`
- every **[recommended]** rule you did differently
- the number of people born abroad in the trait files
- your numbers from 4.2

## 5. Still undecided

Follow the current rule and note what you did.

| Open point | For now | Tracked in |
|---|---|---|
| Probands born in the country only **[SAP 4.1]** | Keep people born abroad, count them, fill `birth_place` | issue #12 |
| Proband birth ranges for W2 and W3 | Run W1 only | `SAP_kit_gaps.md` |
| Twins: out of FS only, or out of every relationship? Triplets judged pair by pair? | Nothing to do; the kit assumes FS only, pair by pair | Open question 5 |
| Main diagnoses only, or secondary too | Count both | Open question 9 |
| Underlying cause of death only, or contributing too | Note which you used | Not raised yet |
| W3: people who died or emigrated before 2008, relatives outside the window | Wait | Open questions 6 and 7 |
| The MDD, BD, SCZ hierarchy, and whether it applies to relatives | Deliver the three as they are (2.3) | Open question 10 |
| Reviewed ICD codes per country | Use `Definitions/Phenotype_list.tsv` | SAP 5 |
