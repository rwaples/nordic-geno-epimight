# Step 0: Getting country-specific register data into common formats

This is a guide to step 0, preparing your register data for the kit. The rules come
from version 8 of the statistical analysis plan, `SAP_Scandinavian_Genealogy.md`.

Each rule has a tag:

| Tag | Meaning |
|---|---|
| **[SAP x.y]** | Required by that section of the SAP |
| **[kit]** | Required by the kit. `check` stops if you break it |
| **[recommended]** | Our default. If you do something else, write it down |

The kit checks formats only. The **[SAP]** and **[recommended]** rules are yours to get
right.

## The short version

1. Export the pedigree and run it through pedsum (section 1).
2. Build one trait file per trait for window W1 (section 2).
3. Write your site file (section 3).
4. Run the checks in section 4.
5. Run `pixi run check local/<site>.yaml out/` and fix every finding.
6. Write your site note (section 4.3).

## Rules for every file

- Tab-separated text files, with a header row. **[kit]**
- Missing values: `NA`. Don't leave cells empty.
- Ids are interpreted as text: `001`, `1` and `1.0` are three different people. **[kit]**
- `0` is never an id, in any file.
- Dates should be in this format: `YYYY-MM-DD`. **[kit]**
- Ages can be given as decimals, computed as `(status_date - birth_date) / 365.25`.
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
| `birth_date` | date, `YYYY-MM-DD` | Date of birth | optional |
| `birth_year` | integer, 4 digits | Must agree with `birth_date` | optional |
| `multiple_birth_id` | integer | Same number for everyone born in one delivery, `NA` for single births. Each delivery gets its own number | optional |

- Missing parent: `NA`, `-1`, or your own code passed to pedsum with
  `--missing-parent-token`. Never `0`. **[kit]**
- Give every parent a row of their own where you can.

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
  In addition, the EPIMIGHT analysis excludes same-sex full siblings born within one month
  of each other from FS, as possible MZ twins. Don't remove twins from the pedigree.
  **[kit]** Twins stay probands and every other kind of relative: a twin's children are
  still the co-twin's nieces and nephews.

### 1.4 Run pedsum

**Please re-run validate and summarize, pedsum has been updated.**

Run pedsum validate (old: `python pedigree_summary.py validate`):

```sh
pixi run pedsum validate --in pedigree.tsv --out pedsum/ --birth-year-col birth_year \
  --birth-date-col birth_date --twin-max-days 30 \
  --max-children-mother 20 --max-children-father 50
gunzip -c pedsum/validate.tsv.gz > pedigree_validated.tsv
```

With `multiple_birth_id`, replace `--twin-max-days 30` with `--multiple-birth-col multiple_birth_id`.

Then go through and resolve any issues in `pedsum/validate.log`:

| Finding | Do this |
|---|---|
| `parent_child_count` | It's an unknown-parent code. Delete its own row if it has one and rerun with `--missing-parent-token <code>` |
| Duplicate row, wrong sex for a parent, parent born after child, cycle | Fix it in your source data. Otherwise use `--drop-offending` or `--break-cycles` |
| `multiple births:` line | A set spanning more than a day means placeholder birth dates. Fix them |
| Multiple-birth set whose members aren't all full siblings, or with one member | pedsum clears it and its members count as single births. Check `multiple_birth_id` or the parent links |

## 2. The trait files

One file per trait, all in one folder.

### 2.1 Format

One row per person in the study population (2.2).

| Column | Type | Content |
|---|---|---|
| `id` | text | Person id, matches ids in the pedigree |
| `trait` | text | One value for the whole file, for example `MDD`, matches trait definitions in `Definitions/Phenotype_list.tsv` |
| `status` | integer | `1` has the trait (affected), `2` mortality while unaffected, `0` censored |
| `status_date` | date, `YYYY-MM-DD` | The date that set `status` |

Don't put `age` in the trait files. The kit computes it from `birth_date` and
`status_date`.

`check` stops if: **[kit]**

- an `id` is missing, duplicated, or not in the pedigree
- `trait` has more than one value
- `status` isn't 0, 1 or 2
- `status_date` isn't a date, is before the birth date, or is after `study_end`
- the trait files don't all list the same people
- someone in the trait files has no birth date in the pedigree

### 2.2 Who gets a row

- Everyone in the civil register with a valid birth date and sex, born on or before
  `study_end`. **[recommended]**
- The same people in every trait file. Someone a rule excludes from a trait keeps a row
  with `status 0`. **[kit]**
- No birth-year filter. Relatives of every age need rows. **[kit]**
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
three. The plan applies the hierarchy. **[SAP 5.3]**

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
- Don't drop anyone for short follow-up. **[kit]**

### 2.8 Example

Danish W1, `study_end` 2023-12-31.

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
id   trait  status  status_date
P1   MDD    1       2012-06-01
P2   MDD    2       2019-04-20
P3   MDD    0       2018-09-01
P4   MDD    0       2023-12-31
P5   MDD    0       2023-12-31
P6   MDD    0       2023-12-31
```

| id | Why |
|---|---|
| P1 | First MDD diagnosis 2012-06-01 |
| P2 | Died 2019-04-20, never diagnosed |
| P3 | Emigrated 2018-09-01 |
| P4, P6 | Followed to `study_end` |
| P5 | Only diagnosis at age 8, below the limit, so censored at `study_end` |

The kit computes P1's age as 8114 days / 365.25 = 22.2149. All six people also need a
row in the other 18 trait files.

## 3. The site file

Copy `local/example.yaml` to `local/<site>.yaml`, one per window:

```yaml
site: Denmark
plan: ../plan/initial.yaml
data_folder: /path/to/trait/files                # this window's trait files
pedigree_path: /path/to/pedigree_validated.tsv   # from section 1.4
study_end: 2023-12-31                            # this window's study_end, section 2.4
threads: 4
# multiple_birth_column: multiple_birth_id       # if the pedigree has it, section 1.3
```

`study_end` must be on or after every `status_date` in the trait files. **[kit]**

## 4. Checks

### 4.1 What the kit checks

Formats (1.1, 2.1), the pedigree through pedsum, and that every trait file has the same
people.

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
| Probands born in the country only **[SAP 4.1]** | Keep people born abroad, count them | `SAP_kit_gaps.md` |
| Proband birth ranges for W2 and W3 | Run W1 only | `SAP_kit_gaps.md` |
| Twins: SAP keeps boy-girl pairs as full siblings **[SAP 4.1]**; the kit drops every pair | Nothing to do | `SAP_kit_gaps.md`, open question 5 |
| Main diagnoses only, or secondary too | Count both | Open question 9 |
| Underlying cause of death only, or contributing too | Note which you used | Not raised yet |
| W3: people who died or emigrated before 2008, relatives outside the window | Wait | Open questions 6 and 7 |
| Reviewed ICD codes per country | Use `Definitions/Phenotype_list.tsv` | SAP 5 |
