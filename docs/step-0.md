# Step 0: from registers to the kit's input files

Each country's registers differ, so each site writes its own scripts for this step. This
guide gives, for each file the kit reads, its format and the rules to apply while
building it. The rules come from the statistical analysis plan, version 8
(`SAP_Scandinavian_Genealogy.md`).

Every rule carries a tag that says where it comes from:

| Tag | Meaning |
|---|---|
| **[SAP x.y]** | Required by that section of the SAP. The same in every country |
| **[kit]** | Required by the kit. Its `check` step stops if the rule is broken |
| **[recommended]** | Not in the SAP. A suggested default: follow it, or record what you did instead |

The kit checks formats, not register logic. It can't tell whether a diagnosis before age
10 was dropped or an emigration was missed, so every **[SAP]** and **[recommended]** rule
is the site's responsibility. Points still undecided are collected in
[section 5](#5-unsettled).

Nothing produced in this step leaves your server.

## Checklist

1. Build the pedigree (section 1) and validate it with pedsum (1.4).
2. Build one trait file per trait (section 2), for window W1.
3. Write the site file (section 3).
4. Run your own checks (section 4) and keep the numbers.
5. Run `pixi run check local/<site>.yaml out/` and fix every finding.
6. Write your site note (4.3).

## General rules for every file

- Tab-separated text with a header row. **[kit]**
- Missing values are `NA` or an empty cell. **[kit]**
- Ids are read as text: `001`, `1` and `1.0` are three different people. Write each id
  the same way in every file. **[kit]**
- Dates are `YYYY-MM-DD`. **[kit]**

## 1. Pedigree file

One file, shared by every trait and window.

### 1.1 Format

One row per person.

| Column | Content | |
|---|---|---|
| `id` | Person id | required |
| `mother` | Mother's id, or missing | required |
| `father` | Father's id, or missing | required |
| `sex` | `1` male, `2` female, `0` unknown | required |
| `birth_date` | `YYYY-MM-DD`. Required for everyone in the trait files; may be empty for others | required |
| `birth_year` | Must agree with `birth_date`. Helps pedsum order generations when dates are missing | optional |
| multiple-birth id | Same value for everyone born in one delivery, empty for everyone else. Name it in the site file's `multiple_birth_column` | optional |

- A missing parent is `NA`, empty, `-1`, or another token you pass to pedsum with
  `--missing-parent-token`. Use `0` only if 0 is a real id. **[kit]**
- Every parent id should have a row of its own. pedsum adds a founder row for a parent
  that doesn't (1.4).

### 1.2 Who is in it

- Everyone in the civil register with a valid birth date and sex, and all their recorded
  parents, through every generation the parent-link registers reach (Table 1 of the
  SAP). **[SAP 4.1]**

### 1.3 Rules

- **Adoptions.** Use the parents as the register records them. Links between adoptees
  and their adoptive parents are kept, not removed or replaced by biological parents.
  Norway has no adoption information and Denmark's covers only a short period, so
  removing them would make the countries less comparable. **[SAP 4.1]**
- **Same-sex parents.** With two mothers registered, set the father ID to `-1`. With two
  fathers registered, set the mother ID to `-1`. **[SAP 4.1]**
- **Unknown-parent codes.** A placeholder such as `9999` used for every unknown parent
  turns thousands of people into siblings. Replace it with a missing value, or let pedsum
  do it (1.4). **[kit]**
- **Twins.** Use the register's twin or multiple-birth id where you have one (all three
  countries have a twin flag), through `multiple_birth_column`. Otherwise the kit takes
  full siblings born at most a day apart as one multiple birth. **[recommended]** Don't
  remove twins or twin links yourself: the kit handles them (section 5). **[kit]**

### 1.4 Validate with pedsum

The kit never changes the pedigree; pedsum checks and repairs it (ADR 0005). The kit's
`check` step runs `pedsum validate` and stops on anything it finds, so run it first:
**[kit]**

```sh
pixi run pedsum validate --in pedigree.tsv --out pedsum/ --birth-year-col birth_year \
  --birth-date-col birth_date --twin-max-days 1 \
  --max-children-mother 20 --max-children-father 50
gunzip -c pedsum/validate.tsv.gz > pedigree_validated.tsv
```

With a register multiple-birth id, replace `--twin-max-days 1` with
`--multiple-birth-col <column>`. Point the site file's `pedigree_path` at
`pedigree_validated.tsv`.

Read `pedsum/validate.log`:

| Finding | What to do |
|---|---|
| Parent without a row | pedsum adds a founder row. Check that these are real people, not codes |
| `parent_child_count` | A mother with more than 20 children or a father with more than 50 is almost always an unknown-parent code. Delete that code's own row if it has one, then rerun with `--missing-parent-token <code>` |
| Duplicate row, sex that contradicts a parent role, parent born after their child, cycle | Fix at the source if you can; otherwise see pedsum's `--drop-offending` and `--break-cycles` |
| `multiple births:` line | A set that spans more than a day suggests placeholder birth dates. A set whose members aren't all full siblings is cleared, and its members count as single births |

## 2. Trait files

One file per trait, all in one data folder.

### 2.1 Format

Each file has one row per person in the study population (2.2).

| Column | Content |
|---|---|
| `id` | Person id, as in the pedigree |
| `trait` | One value for the whole file, for example `MDD` |
| `status` | `1` has the trait, `2` death from another cause (competing event), `0` censored |
| `age` | Years from birth to `date`. May have fractions |
| `date` | Date of the event that sets `status` (2.7), `YYYY-MM-DD` |

The kit stops on any of these: **[kit]**

- a missing or duplicate `id`, or an `id` with no pedigree row;
- more than one value in `trait`;
- `status` other than 0, 1, 2;
- `age` missing, negative or not a number;
- `date` not a date, before `birth_date`, or after `study_end`;
- `age` that differs from `(date - birth_date) / 365.25` by more than a day. Compute
  `age` exactly that way;
- trait files that don't list exactly the same people;
- someone in the trait files with no `birth_date` in the pedigree.

It warns when a trait has fewer than 10 cases in a birth-year stratum.

### 2.2 Who gets a row

The kit treats everyone with a row as a proband and counts them as a relative of
others. Someone without a row is not an unaffected relative: they don't count at all.
**[kit]**

- Give a row to everyone in the civil register with a valid birth date and sex, born on
  or before `study_end`. **[recommended]**
- Give the same people a row in every trait file. Someone a rule removes from a trait
  keeps a censored row (`status 0`). **[kit]**
- Parents known only from parent links, never in the civil register, can stay in the
  pedigree without trait rows; they then don't count as relatives. The `check` step
  counts these people per birth decade (`pedigree_coverage.tsv`). **[recommended]**
- Keep people born abroad, and record how many there are (section 5). **[recommended]**
- Don't filter by birth year. Relatives of any birth year need their rows. **[kit]**

### 2.3 The traits

The plan's 19 traits (`plan/traits.tsv`), with ICD-8, ICD-9 and ICD-10 codes in
`Definitions/Phenotype_list.tsv`:

| File | Trait | Age limit |
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

The SAP's code list is `ICD_codes_Mental_CVD v.14.6.2026.xlsx`, and the codes per
country and disorder are under review **[SAP 5]**. Use the repository's list until the
reviewed codes replace it.

Deliver MDD, BD and SCZ as they are. The plan applies the mental-disorder hierarchy
(people with BD leave MDD, people with SCZ leave BD) with the kit's trait2 rules, which
need each trait's own onsets. **[SAP 5.3]**

### 2.4 Windows

The SAP runs every analysis in three windows. **[SAP 4.2]**

| | W1 | W2 | W3 |
|---|---|---|---|
| Diagnoses counted | All years, all ICD versions | As W1 | Only those made 1 January 2008 to 31 December 2021, ICD-10 only |
| `study_end` | Last follow-up: DK 2023-12-31, SE 2024-12-31, NO 2021-12-31 | As W1 | 2021-12-31 |
| Probands | All birth cohorts | Born 1960 to 2007 | Born 1985 to 2005 (to 2015 for the ASD sensitivity analysis) |
| Data folder | Its own | W1's | Its own |

W2 differs from W1 only in which people are probands, so it uses W1's trait files. W3
needs its own trait files, built with the W3 filters in 2.5 to 2.7.

The kit can't yet restrict probands by birth year (`SAP_kit_gaps.md`), so only W1 runs
end to end for now. Build W1 first.

### 2.5 Which diagnoses count

- **Hospital contacts.** Any inpatient or outpatient contact with the code as the main
  (primary) or a secondary diagnosis. **[SAP 5.1]**
- **Causes of death.** Causes of death count as diagnoses, so a death from the trait is
  `status 1`, not a competing event. For CVD, combine the patient registers and the
  cause of death register: the first record in either sets onset. **[SAP 5.1]**
- **Primary care.** Not among the SAP's sources; leave it out. **[recommended]**
- **ICD versions.** W1 and W2: ICD-8, ICD-9 and ICD-10, as the country has them. W3:
  ICD-10 only. **[SAP 5.1]**
- **W3.** Ignore every diagnosis made before 2008, for everyone. A Danish or Swedish
  person first diagnosed in 2004 and seen again in 2010 is a case in 2010. **[SAP 4.2]**
- **Code matching.** The list gives codes at different levels (`F32` covers `F32.0` to
  `F32.9`). Match on the code prefix, and handle each country's format: with or without
  the dot, Swedish ICD-9 letter suffixes such as `296B`. **[recommended]**

### 2.6 Age limits

| Traits | Ignore diagnoses before age |
|---|---|
| MDD, BD, SCZ | 10 |
| ASD | 4 |

The first diagnosis at or after the limit sets `status 1` and its age. Someone whose
only diagnoses were before the limit is coded as if never diagnosed. In W3, the limit
applies to the age at the first diagnosis inside the window. Other traits have no age
limit. **[SAP 5.2]**

### 2.7 Status and date

For each person and trait, from the diagnoses left after 2.5 and 2.6:

| Situation | `status` | `date` | |
|---|---|---|---|
| At least one qualifying diagnosis | 1 | The earliest | **[SAP 5.2]** |
| No diagnosis; died | 2 | Date of death | **[SAP 4.1]** |
| No diagnosis; emigrated | 0 | Emigration date | **[SAP 4.1]** |
| No diagnosis; still followed | 0 | `study_end` | **[SAP 4.1]** |

- The date of a diagnosis is the start (admission) date of the contact, or the date of
  death for a cause of death. Use the same rule for every trait and source.
  **[recommended]**
- A diagnosis and death on the same day: the diagnosis wins (`status 1`).
  **[recommended]**
- Someone who emigrates and returns is censored at the first emigration.
  **[recommended]**
- Don't drop anyone for short follow-up; follow-up rules belong in the plan. **[kit]**

### 2.8 Worked example

A Danish W1 pedigree, `study_end` 2023-12-31:

```
id   mother  father  sex  birth_date
P2   -1      -1      2    1955-11-02
P6   -1      -1      1    1950-02-01
P1   P2      P6      1    1990-03-15
P4   P2      P6      2    1998-01-10
P3   -1      P6      1    2001-07-30
P5   -1      -1      2    2005-05-05
```

And its `MDD.tsv`:

```
id   trait  status  age      date
P1   MDD    1       22.2149  2012-06-01
P2   MDD    2       63.4634  2019-04-20
P3   MDD    0       17.0897  2018-09-01
P4   MDD    0       25.9713  2023-12-31
P5   MDD    0       18.6557  2023-12-31
P6   MDD    0       73.9110  2023-12-31
```

- P1 was first diagnosed with MDD on 2012-06-01.
- P2 died in 2019 without an MDD diagnosis.
- P3 emigrated on 2018-09-01.
- P4 and P6 were followed to `study_end`.
- P5's only MDD diagnosis was at age 8.07, below the limit of 10, so it is ignored.
- `age` is `(date - birth_date) / 365.25` in each row: for P1, 8114 days / 365.25 =
  22.2149.

Every one of these six people has a row in every other trait file too.

## 3. Site file

Copy `local/example.yaml` to `local/<site>.yaml`, one per window:

```yaml
site: Denmark
plan: ../plan/initial.yaml
data_folder: /path/to/trait/files                # this window's trait files
pedigree_path: /path/to/pedigree_validated.tsv   # pedsum's output (1.4)
study_end: 2023-12-31                            # this window's study_end (2.4)
threads: 4
# multiple_birth_column: delivery_id             # the pedigree's multiple-birth id (1.3)
```

`study_end` must be on or after every `date` in the trait files. **[kit]**

## 4. Checks before running the kit

### 4.1 What the kit checks

The formats in 1.1 and 2.1, the pedigree through pedsum (1.4), and that every trait file
lists the same people. Nothing else.

### 4.2 What you check

Check each, per trait, and keep the numbers. **[recommended]**

| Check | Look for |
|---|---|
| Study population per birth decade | Against the civil register |
| Pedigree people without trait rows, per birth decade | Who they are; `pedigree_coverage.tsv` after `check` |
| Share with a known mother and father, per birth decade | A sharp rise where the parent-link registers start |
| Cases per trait and birth decade | Against published prevalence |
| Onset ages | No MDD, BD or SCZ case before 10, no ASD case before 4; piles of onsets at one age often mark a register start |
| Cases by calendar year of diagnosis | Steps at the outpatient start (DK 1995, SE 2001) and ICD changes (DK 1994, SE 1987 and 1997), and nowhere else |
| Status mix per birth decade | Older cohorts should have more deaths; check deaths aren't missing |
| CVD cases from the cause of death register only | How many |
| W3 trait files | No `status 1` date before 2008-01-01 and no `date` after 2021-12-31 |

### 4.3 Your site note

Write a short note, kept with your scripts and not exported, that records: **[recommended]**

- the register extracts and their dates;
- the codes used per trait, if they differ from `Definitions/Phenotype_list.tsv`;
- every **[recommended]** rule you did differently;
- how many people born abroad are in the trait files;
- the numbers from 4.2.

The collaborators compare these notes across countries, so that differences in the
results can be traced to differences in the data.

## 5. Unsettled

These are still open. Follow the guide's current rule, and record what you did.

| Point | Current rule | Where it's tracked |
|---|---|---|
| Probands must be born in the country **[SAP 4.1]**; the kit can't restrict them yet | Keep people born abroad; record how many | `SAP_kit_gaps.md` |
| Proband birth ranges for W2 and W3 | Only W1 runs | `SAP_kit_gaps.md` |
| Twins: the SAP keeps sex-discordant pairs as full siblings and leaves out sex-concordant pairs **[SAP 4.1]**; the kit leaves out every pair | Nothing for sites to do | `SAP_kit_gaps.md`, open question 5 |
| Main vs secondary diagnoses | Count both | Open question 9 |
| Which causes of death count: underlying only, or contributing too | Record what you used | Not yet raised |
| W3: people who died or emigrated before 2008, and relatives outside the window | Wait | Open questions 6 and 7 |
| Reviewed ICD codes per country | `Definitions/Phenotype_list.tsv` | SAP 5 |
