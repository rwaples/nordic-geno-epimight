# Step 0: from registers to the kit's input files

Each country's registers differ, so each site writes its own scripts for this step. This
document says what those scripts must produce (part 1) and the rules, filters and checks
to apply on the way (part 2). The rules come from the statistical analysis plan, version
8 (`SAP_Scandinavian_Genealogy.md`); section numbers below refer to it.

The kit's `check` step catches format errors but not register logic: it can't tell
whether a diagnosis before age 10 was dropped or an emigration was missed. Everything
under part 2 is the site's responsibility.

Nothing produced in this step leaves your server.

## Overview

A site delivers, per analysis window:

| Output | What it is |
|---|---|
| Pedigree file | One row per person: id, parents, sex, birth date |
| Trait files | One file per trait, one row per person in the study population |
| Site file | `local/<site>.yaml`: paths and `study_end` |

The pedigree is shared by all windows. The trait files and `study_end` change with the
window (section 2.6).

## Part 1: target formats

### 1.1 General rules

- Tab-separated text with a header row. UTF-8.
- Missing values are `NA` or an empty cell.
- Ids are read as text: `001`, `1` and `1.0` are three different people. Write each id
  the same way in every file.
- Dates are `YYYY-MM-DD`.

### 1.2 Pedigree file

One row per person. Required columns:

| Column | Content |
|---|---|
| `id` | Person id |
| `mother` | Mother's id, or missing |
| `father` | Father's id, or missing |
| `sex` | `1` male, `2` female, `0` unknown |
| `birth_date` | `YYYY-MM-DD`. Required for everyone in the trait files; may be empty for others |

Optional columns:

| Column | Content |
|---|---|
| `birth_year` | Must agree with `birth_date`. Helps pedsum order generations when dates are missing |
| A multiple-birth id | Same value for everyone born in one delivery, empty for everyone else. Name it in the site file's `multiple_birth_column` |
| Stratum columns | Any column the plan stratifies on (the current plans use only `birth_year`) |

Rules:

- A missing parent is `NA`, empty, `-1`, or another token you pass to pedsum with
  `--missing-parent-token`. Use `0` only if 0 is a real id.
- Every parent id should have a row of its own. pedsum adds a founder row for a parent
  that doesn't, but check those first (section 2.7).
- The file goes through `pedsum validate`, and the kit uses pedsum's output, not your
  file (section 2.7).

### 1.3 Trait files

One file per trait in `plan/traits.tsv`, named as its `file` column says (`MDD.tsv`,
`ASD.tsv`, ...), all in one data folder. Each file has one row per person in the study
population (section 2.1). Required columns:

| Column | Content |
|---|---|
| `id` | Person id, as in the pedigree |
| `trait` | One value for the whole file, for example `MDD` |
| `status` | `1` has the trait, `2` competing event (death from another cause), `0` censored |
| `age` | Years from birth to the event that sets `status`. May have fractions |
| `date` | Date of that event, `YYYY-MM-DD` |

What `age` and `date` mean for each status:

| `status` | Event | `date` |
|---|---|---|
| 1 | First qualifying diagnosis (sections 2.3 to 2.5) | Date of that diagnosis |
| 2 | Death from another cause, with no qualifying diagnosis before it | Date of death |
| 0 | Neither: still followed at the end, or emigrated | Emigration date or `study_end`, whichever is first |

The kit checks, and stops on:

- a missing or duplicate `id`, or an `id` with no pedigree row;
- more than one value in `trait`;
- `status` other than 0, 1, 2;
- `age` missing, negative or not a number;
- `date` not a date, before `birth_date`, or after `study_end`;
- `age` that differs from `(date - birth_date) / 365.25` by more than a day. Compute
  `age` that way;
- trait files that don't list exactly the same people;
- someone in the trait files with no `birth_date` in the pedigree.

It warns when a trait has fewer than 10 cases in a birth-year stratum.

### 1.4 Site file

Copy `local/example.yaml` to `local/<site>.yaml`:

```yaml
site: Denmark
plan: ../plan/initial.yaml
data_folder: /path/to/trait/files
pedigree_path: /path/to/pedigree_validated.tsv   # pedsum's output (section 2.7)
study_end: 2023-12-31                            # end of follow-up for this window
threads: 4
# multiple_birth_column: delivery_id
```

`study_end` must be on or after every `date` in the trait files.

## Part 2: logic, filters and checks

Work through these in order. Write down every choice you make where the SAP leaves room
(section 2.9).

### 2.1 The study population

The study population is everyone with a row in the trait files. The kit treats each of
them as a proband and counts them as a relative of others. Someone without a row is not
an unaffected relative: they don't count at all.

- Give a row to everyone in the civil register with a valid birth date and sex, born on
  or before `study_end`.
- Give the same people a row in every trait file. Someone a rule removes from a trait
  keeps a censored row (`status 0`).
- Parents known only from parent links, never in the civil register, can stay in the
  pedigree without trait rows. They then don't count as relatives. The kit's `check`
  step counts these people per birth decade (`pedigree_coverage.tsv`); check that the
  count matches what you expect.
- The SAP takes only people born in the country as index persons, while people born
  abroad still count as relatives (4.1). The kit can't make that split yet
  (`SAP_kit_gaps.md`), so keep people born abroad in the trait files for now and record
  how many there are.

### 2.2 The pedigree

- **Source.** Everyone in the civil register and all their recorded parents, through
  every generation the parent-link registers reach (Table 1).
- **Adoptions.** Use the parents as the register records them. Links between adoptees
  and their adoptive parents are kept, not removed or replaced by biological parents
  (4.1). Norway has no adoption information and Denmark's covers only a short period,
  so removing them would make the countries less comparable.
- **Same-sex parents.** With two mothers registered, set the father ID to `-1`. With two
  fathers registered, set the mother ID to `-1` (4.1).
- **Unknown-parent codes.** A placeholder such as `9999` used for every unknown parent
  turns thousands of people into siblings. Replace it with a missing value, or let pedsum
  do it (section 2.7).
- **Twins.** Use the register's twin or multiple-birth id where you have one (Table 1:
  all three countries have a twin flag), through `multiple_birth_column`. Otherwise the
  kit takes full siblings born at most a day apart as one multiple birth. The SAP keeps
  sex-discordant twin pairs as full siblings and leaves out sex-concordant pairs (4.1);
  the kit for now leaves out every pair (`SAP_kit_gaps.md`). Don't remove twins
  yourself.

### 2.3 Which diagnoses count

For each trait, the codes are in `Definitions/Phenotype_list.tsv` (ICD-8, ICD-9, ICD-10
per trait). The SAP's mapping is `ICD_codes_Mental_CVD v.14.6.2026.xlsx`, and the codes
per country and disorder are being reviewed (5). Use the repository's list until the
reviewed codes replace it.

A diagnosis counts when it comes from:

- **Hospital contacts.** Any inpatient or outpatient contact with the code as the main
  (primary) or a secondary diagnosis (5.1). Whether some traits should count main
  diagnoses only is open question 9.
- **Causes of death.** Causes of death count as diagnoses (5.1). For CVD, combine the
  patient registers and the cause of death register: the first record in either sets
  onset, so a CVD death is `status 1`, not a competing event.

Primary care diagnoses (Sweden regionally, Norway nationally) are not among the SAP's
sources; leave them out.

ICD versions depend on the window (section 2.6): W1 and W2 use ICD-8, ICD-9 and ICD-10
where the country has them; W3 uses ICD-10 only.

Code matching: the list gives codes at different levels (`F32` covers `F32.0` to `F32.9`).
Match on the code prefix, and handle each country's format (with or without the dot,
Swedish ICD-9 letter suffixes such as `296B`).

### 2.4 Age limits (5.2)

| Traits | Ignore diagnoses before age |
|---|---|
| MDD, BD, SCZ | 10 |
| ASD | 4 |

The first diagnosis at or after the limit sets `status 1` and its age. Someone whose
only diagnoses were before the limit is coded as if never diagnosed: `status 0` at
emigration or `study_end`, or `status 2` at death.

Other traits have no age limit.

### 2.5 Status and dates for each person and trait

For each person and trait, from the qualifying diagnoses left after sections 2.3, 2.4
and the window filter (section 2.6):

1. If there is one, `status 1` at the earliest. Use the same date for every trait and
   source: the start (admission) date of the contact, or the date of death for a cause
   of death.
2. Otherwise, if the person died, `status 2` at death.
3. Otherwise, `status 0` at the earlier of emigration and `study_end`.

If a diagnosis and death fall on the same day, the diagnosis wins (`status 1`).

The SAP doesn't say how to treat someone who emigrates and returns. Censoring at the
first emigration is the safe choice; record what you do.

Don't apply the mental-disorder hierarchy (5.3) here. Deliver MDD, BD and SCZ files as
they are; the plan removes people with BD from MDD and people with SCZ from BD with the
kit's trait2 rules, which need each trait's own onsets.

Don't drop anyone for short follow-up either. Follow-up rules belong in the plan.

### 2.6 Analysis windows (4.2)

| | W1 | W2 | W3 |
|---|---|---|---|
| Diagnoses counted | All years, all ICD versions | All years, all ICD versions | Only those made 1 January 2008 to 31 December 2021, ICD-10 only |
| `study_end` | Last follow-up (DK 2023-12-31, SE 2024-12-31, NO 2021-12-31) | As W1 | 2021-12-31 |
| Probands | All birth cohorts | Born 1960 to 2007 | Born 1985 to 2005 (to 2015 for the ASD sensitivity analysis) |

- **W1 and W2** use the same trait files. They differ only in which people are
  probands.
- **W3** needs its own data folder. Ignore every diagnosis made before 2008, for
  everyone, including relatives. A Danish or Swedish person first diagnosed in 2004 and
  seen again in 2010 is a case in 2010. Apply the age limits (section 2.4) to the age at
  the first diagnosis inside the window. Censor everyone at 2021-12-31 at the latest.
- **Don't filter trait files by birth year.** Relatives of any birth year need their
  rows. The proband birth range is meant to be applied by the kit, but it can't do
  that yet (`SAP_kit_gaps.md`), so for now only W1 runs end to end.
- How W3 treats people who died or emigrated before 2008 is open questions 6 and 7.

### 2.7 Validate the pedigree with pedsum

The kit never changes the pedigree; pedsum checks and repairs it (ADR 0005). Run it
before the kit, the same way the kit's `check` step does:

```sh
pixi run pedsum validate --in pedigree.tsv --out pedsum/ --birth-year-col birth_year \
  --birth-date-col birth_date --twin-max-days 1 \
  --max-children-mother 20 --max-children-father 50
gunzip -c pedsum/validate.tsv.gz > pedigree_validated.tsv
```

With a register multiple-birth id, replace `--twin-max-days 1` with
`--multiple-birth-col <column>`. Then point `pedigree_path` at `pedigree_validated.tsv`.

Read `pedsum/validate.log`. It reports, among others:

- **Parents without a row.** pedsum adds a founder row for each; check they are real
  people and not codes.
- **`parent_child_count`.** A mother with more than 20 children or a father with more
  than 50 is almost always an unknown-parent code. Delete that code's own row if it has
  one, then rerun with `--missing-parent-token <code>`.
- **Duplicate rows, a sex that contradicts a parent role, a parent born after their
  child, cycles.** Fix them at the source if you can; otherwise see pedsum's
  `--drop-offending` and `--break-cycles`.
- **Multiple-birth sets.** Check the `multiple births:` line. A set that spans more than
  a day suggests placeholder birth dates. A set whose members aren't all full siblings
  is cleared, and its members count as single births.

The kit stops if pedsum still finds anything in the file you give it.

### 2.8 Your own checks before running the kit

The kit can't see these. Check each, per trait and country, and keep the numbers:

- **Population.** Size of the study population per birth decade, against the civil
  register. People in the pedigree without trait rows, per birth decade.
- **Parent completeness.** Share of people with a known mother and father, per birth
  decade. It should rise sharply where the parent-link registers start (Table 1).
- **Case counts.** Cases per trait and birth decade, and the share of the population,
  against published prevalence.
- **Onset ages.** No MDD, BD or SCZ case before age 10, no ASD case before age 4. A pile
  of onsets at one age often marks a register start rather than biology.
- **Register and ICD transitions.** Cases by calendar year of diagnosis: look for steps
  at the outpatient start (DK 1995, SE 2001) and ICD changes (DK 1994, SE 1987 and 1997).
  Steps are expected; check they are where the registers say.
- **Status mix.** Shares of status 0, 1 and 2 per birth decade. Older cohorts should
  have more deaths; check deaths aren't missing.
- **CVD and cause of death.** How many CVD cases come only from the cause of death
  register.
- **W3.** No `status 1` date before 2008-01-01 and no `date` after 2021-12-31.
- **Same people everywhere.** Every trait file has the same ids, and each id has a
  pedigree row with a birth date.

### 2.9 Record what you did

Write a short note for your site (kept with your scripts, not exported) that records:

- the register extracts and their dates;
- the codes used per trait, if they differ from `Definitions/Phenotype_list.tsv`;
- how you matched codes and which date you used for a diagnosis;
- how you handled emigration and return, unknown-parent codes and same-sex parents;
- whether people born abroad are in the trait files, and how many;
- the numbers from section 2.8.

The collaborators compare these notes across countries, so that differences in the
results can be traced to differences in the data.
