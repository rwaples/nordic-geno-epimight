# Statistical Analysis Plan (SAP)

Scandinavian genealogy: heritability and genetic correlation of mental and cardiometabolic disorders in Denmark, Sweden and Norway

*Version 8, 20 October 2026. Coordinating centre: Institute of Biological Psychiatry, Roskilde*

<!-- Converted from SAP_Scandinavian_Genealogy_v8.docx. The docx is the source; edit it, then convert again. -->

## 1. Aim and set-up

We estimate heritability (h2) and genetic correlation (rg) of mental and cardiometabolic disorders (CMD) in Denmark, Sweden and Norway using national genealogies, and compare the countries. Earlier work covered Denmark and Sweden only and read estimates off each country's own register coverage (Meijsen et al., Nat Commun 2024 and 2025). Here every country runs the same analyses with the same software, in three analysis windows that make the countries comparable step by step.

- Each country runs the analyses on its own server and returns only aggregate, disclosure-checked tables. No individual-level data leave a country.
- Fixed software for all countries: pedsum (genealogy), the shared make_epimight_tte rules (EPIMIGHT input, implemented in the nordic-geno-epimight kit) and EPIMIGHT (h2, rg), each at one agreed version.
- Every analysis is run in three windows: W1 (all available data), W2 (a birth cohort shared by all three countries) and W3 (a birth cohort and diagnosis period shared by all three countries).

## 2. Objectives

1. **O1. Genealogy.** Describe each national genealogy (size, depth, completeness, relative pairs) with pedsum.
2. **O2. Descriptive statistics.** Incidence and prevalence of every phenotype by sex, age and period.
3. **O3. Heritability.** Liability-scale h2 per phenotype and country, from full siblings (main) and five other relationship types.
4. **O4. Genetic correlation.** rg for mental x mental, mental x CVD and CVD x CVD pairs.
5. **O5. Comparison.** Meta-analysis across countries and between-country heterogeneity, W1 versus W2 and W3.

## 3. Data sources

| Item                            | Denmark                                                | Sweden                                              | Norway                                          |
|---------------------------------|--------------------------------------------------------|-----------------------------------------------------|-------------------------------------------------|
| Civil register                  | CPR (1968 onwards)                                     | Total Population Register (1968 onwards)            | Population Register (1960 onwards)              |
| Parent links                    | CPR; MGR-beta (births from 1920); MGR-lite (from 1953) | Multi-Generation Register (born 1932 or later)      | Population-register parent links (1960 onwards) |
| Inpatient diagnoses from        | Psychiatric 1969, somatic 1977                         | Psychiatric 1973, somatic 1964 (national 1987)      | 2008                                            |
| Outpatient diagnoses from       | 1995                                                   | 2001                                                | 2008                                            |
| ICD versions                    | ICD-8 to 1993, ICD-10 from 1994                        | ICD-8 to 1986, ICD-9 1987 to 1996, ICD-10 from 1997 | ICD-10 from 2008                                |
| Primary care diagnoses          | No                                                     | Stockholm and Västra Götaland only                  | Nationwide from 2006                            |
| Cause of death register         | Yes                                                    | Yes                                                 | Yes                                             |
| Emigration, household registers | Yes                                                    | Yes                                                 | Yes                                             |
| Adoption information            | Partial (ADOP 1988 to 2009, plus proxies)              | Yes                                                 | No                                              |
| Twin flag                       | Yes (Medical Birth Register)                           | Yes                                                 | Yes                                             |
| Last follow-up                  | 31-12-2023                                             | 31-12-2024                                          | 31-12-2021                                      |
| Minimum cell size               | 5                                                      | 11                                                  | 5                                               |

*Table 1. Register coverage. Norway sets the overlap: diagnoses from 2008, follow-up to 2021, parent links from 1960.*

## 4. Study population and analysis windows

### 4.1 Genealogy and inclusion

- Genealogy: everyone in the civil register with a valid birth date and sex, and all their recorded parents.
- **Adoptions.** Links between adoptees and their adoptive parents are kept. Norway has no adoption information and the Danish adoption register only covers a short period, so removing these links would make the countries less comparable.
- **Same-sex parents.** With two mothers registered, the father ID is set to missing (-1). With two fathers registered, the mother ID is set to missing (-1).
- **Twins.** Twins are identified and are no longer counted as full siblings. Sex-discordant twin pairs are kept, as they are known to be fraternal. Sex-concordant twin pairs are left out, as identical and fraternal pairs cannot be told apart.
- Index persons must be born in the country (EPIMIGHT analyses). People born abroad still appear as relatives.
- Status: 1 = diagnosis, 2 = death from another cause (competing risk), 0 = censored (emigration or end of follow-up).

### 4.2 The three windows

|                   | W1: All available data                                  | W2: Common birth cohort                                             | W3: Common birth cohort and diagnosis period                                          |
|-------------------|---------------------------------------------------------|---------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Countries         | DK, SE, NO                                              | DK, SE, NO                                                          | DK, SE, NO                                                                            |
| Index persons     | All birth cohorts with linked parents                   | Born 1960 to 2007                                                   | Born 1985 to 2005                                                                     |
| Follow-up         | All register years in that country                      | To the end of follow-up in each country (DK 2023, SE 2024, NO 2021) | 1 January 2008 to 31 December 2021                                                    |
| Diagnoses counted | All years and ICD versions                              | All years and ICD versions available in that country                | Only those made 2008 to 2021 (ICD-10). In DK and SE all earlier diagnoses are ignored |
| Relatives         | Any birth year; affected at any time                    | Any birth year; affected at any time                                | Any birth year; affected only if diagnosed 2008 to 2021                               |
| Used for          | Main estimates per country; link to published estimates | Same birth cohorts in all three countries                           | Like-for-like comparison between countries                                            |

*Table 2. Analysis windows.*

**W1** uses everything each country has, regardless of the differences between countries. It gives the main heritability estimates (Section 6.4).

**W2** restricts index persons to the birth cohorts all three countries cover (born 1960 to 2007, from the start of Norwegian parent links) and follows them to the end of follow-up in each country. Norway has diagnoses only from 2008, so W2 compares the same birth cohorts, not the same observed ages.

**W3** is set by Norway. Norway has hospital diagnoses only from 2008 and follow-up to 2021. To make the Danish and Swedish cohorts comparable to Norway, all diagnoses an individual received before 2008 are ignored in Denmark and Sweden, for index persons and relatives alike. A Danish or Swedish person first diagnosed in 2004 and seen again in 2010 therefore counts as a case in 2010, as Norway would record them. People born 1985 to 2005 are observed at the ages when mental disorders start (born 1985 at ages 23 to 36, born 2005 at ages 3 to 16).

**W3 sensitivity analysis.** The birth cohort is extended from 2005 to 2015 to boost power for ASD.

**Cardiometabolic traits.** W3 index persons are too young for most CMD. CMD in W3 is estimated in the parent generation of the W3 index persons, using their siblings and parents as relatives.

## 5. Phenotypes

Phenotypes follow the shared mapping ICD_codes_Mental_CVD v.14.6.2026.xlsx. The diagnostic codes used per country and disorder are being reviewed (Øyvind) and will be presented at the next meeting.

| Domain          | Main traits                                                                     | Supplementary traits                                                                                                                                                              |
|-----------------|---------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mental          | MDD; autism spectrum disorder (ASD); bipolar disorder (BD); schizophrenia (SCZ) | Schizophrenia spectrum                                                                                                                                                            |
| Cardiometabolic | CVD combined; CMD combined; any stroke; type 2 diabetes; myocardial infarction  | Ischaemic heart disease; heart failure; atrial fibrillation/flutter; peripheral artery disease; obesity; dyslipidaemia; essential hypertension; haemorrhagic and ischaemic stroke |

*Table 3. Phenotypes.*

### 5.1 Sources of a diagnosis

- Any inpatient or outpatient hospital contact with the code as primary or secondary diagnosis.
- **Cause of death.** Unlike earlier work, causes of death also count as diagnoses. This matters most for CVD.
- **CVD.** The patient registers and the cause of death register are combined to decide whether and when a CVD event happened. The first record in either source defines onset. A death from CVD is therefore a CVD event (status 1), not a competing event.
- W3 uses ICD-10 only. W1 and W2 also use ICD-8 and ICD-9 in Denmark and Sweden.

### 5.2 Time to diagnosis

- **MDD, BD and SCZ.** Diagnoses before age 10 are ignored. The first diagnosis from age 10 onwards defines case status and time to event.
- **ASD.** Diagnoses before age 4 are ignored. The first diagnosis from age 4 onwards defines case status and time to event.
- Someone whose only diagnosis was before that age limit is coded as censored (0) with time to event at emigration or end of follow-up. If they died, they are coded as 2 with time to event at death.

### 5.3 Diagnoses that cannot both apply

| Combination | Rule                                                                                                                                                                                                                               |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MDD and BD  | The MDD diagnosis is ignored. The person is only in the BD cohort (excluded from MDD).                                                                                                                                             |
| BD and SCZ  | The BD diagnosis is ignored. The person is only in the SCZ cohort (excluded from BD).                                                                                                                                              |
| MDD and SCZ | No recoding or exclusion. People with schizophrenia can have clinical depression, schizophrenia is far less common than depression, and it has the stronger clinical impact of the two. Both incidences are treated independently. |

*Table 4. Hierarchy between mental disorders. Implemented with the trait2 options of make_epimight_tte (exclude_trait2 = "any", trait2_action = "exclude").*

## 6. Analyses

| Step | What                                     | Tool                                      | Windows                             | Returned                                          |
|------|------------------------------------------|-------------------------------------------|-------------------------------------|---------------------------------------------------|
| 1    | Build and validate the national pedigree | pedsum validate                           | All                                 | Error counts; parent completeness by birth decade |
| 2    | Describe the genealogy                   | pedsum summarize                          | Full pedigree, W2 and W3 cohorts    | Pedigree summaries                                |
| 3    | Descriptive incidence and prevalence     | Own scripts                               | Whole population, W2 and W3 cohorts | Cases and person-years by sex, age, period        |
| 4    | Build the EPIMIGHT input                 | make_epimight_tte rules (kit cohort step) | W1 to W3                            | Summary counts only                               |
| 5    | Heritability                             | EPIMIGHT                                  | W1 to W3                            | K, KR, h2, SE per trait, relationship and stratum |
| 6    | Genetic correlation                      | EPIMIGHT                                  | W1 to W3                            | rg, SE per trait pair, relationship and stratum   |
| 7    | Meta-analysis and heterogeneity          | Coordinating centre                       | W1 to W3                            | (central)                                         |

*Table 5. Overview of analyses. Steps 1 to 6 are run in each country.*

### 6.1 Genealogy (Steps 1 and 2)

Each country builds one pedigree file (id, sex, mother, father, birth year; **-1** for a missing parent or information), applies the rules in Section 4.1, validates it with pedsum, and summarises it for the full pedigree and for the W2 and W3 cohorts with their relatives. The summaries give Table 1 and Figure 1 of the paper.

Return the summary as: `{country}_Genealogysummary_{window}.tsv`

### 6.2 Descriptive statistics (Step 3)

For each phenotype, countries report incidence and prevalence in three groups:

1. **The whole population** of each country.
2. **The W2 cohort** (born 1960 to 2007).
3. **The W3 cohort** (born 1985 to 2005).

All are reported by sex (all, men, women), by age and calendar year.

- **Incidence:** countries return the number of new cases per birth year by age at diagnosis. Each individual is counted once.
- **Incidence:** countries return the number of new cases per year of diagnosis by age at diagnosis. Each individual is counted once.
- **Prevalence:** the share of people alive and living in the country on 1 January of each year who have ever had the diagnosis (since 2008 for the W3 cohort). Countries return the number of people with the diagnosis and the number of people in the population.

Return results as: `{country}_lexisData_Incidence_YOB_{window}.tsv` and `{country}_lexisData_Incidence_YODx_{window}.tsv`

### 6.3 EPIMIGHT input (Step 4)

- The input is built for one trait and one relationship per call, following make_epimight_tte. The kit applies the same rules in its cohort step.
- The window is applied to the phenotype table before the call. W2: no date filter on diagnoses, follow-up to the end of each country's data. W3: only diagnoses made 2008 to 2021 count and everyone is censored at 31 December 2021. Relatives' status comes from the same table, so the window applies to them too.
- The function is run on everyone, and the output is then restricted to the probands of the window (born 1960 to 2007 in W2, 1985 to 2005 in W3, 1985 to 2015 in the W3 ASD sensitivity analysis), so that older relatives are still counted.
- The hierarchy rules in Section 5.3 are applied with the trait2 options.

### 6.4 Heritability (Step 5)

Liability-scale h2 from the population risk (K) and the risk in persons with an affected relative (KR), per relationship type.

| Relationship                 | Code | Relatedness | Role                                        |
|------------------------------|------|-------------|---------------------------------------------|
| Full siblings                | FS   | 0.5         | Main analysis (full available register, W1) |
| Parent-offspring             | PO   | 0.5         | Additional                                  |
| Maternal half siblings       | mHS  | 0.25        | Additional                                  |
| Paternal half siblings       | pHS  | 0.25        | Additional                                  |
| Avuncular (aunts and uncles) | AV   | 0.25        | Additional                                  |
| First cousins                | 1C   | 0.125       | Additional                                  |

*Table 6. Relationship types. Grandparents are not used.*

**Strata.** All estimates are calculated per birth year, per 5-year birth cohort and per 10-year birth cohort. The estimates are meta-analysed within each grouping: all single-year estimates together, all 5-year estimates together and all 10-year estimates together. There is no meta-analysis across the three groupings.

Return the results as: `{country}_h2_{phenotype}_{familyType}_{window}.tsv`. Each file includes the per-stratum and the meta-analysed h2 for each grouping.

### 6.5 Genetic correlation (Step 6)

rg from the cross-trait familial risk (trait 2 in relatives of persons with trait 1), run in both directions and combined.

| Trait pair      | Relationship     | Note                                                                   |
|-----------------|------------------|------------------------------------------------------------------------|
| Mental x mental | Full siblings    |                                                                        |
| Mental x CVD    | Parent-offspring | Uses h2 estimates from the full available dataset (W1) in each country |
| CVD x CVD       | Full siblings    | Combined groups are not correlated with their own components           |

*Table 7. Relationship used per trait pair.*

**Additional.** rg can also be compared across relationships, for example the MD x psychiatric rg from parent-offspring pairs versus avuncular pairs.

Strata and meta-analysis follow Section 6.4. Return the results as: `{country}_rg_{phenotype1_phenotype2}_{familyType}_{window}.tsv`

### 6.6 Meta-analysis and heterogeneity (Step 7)

- Within each country: random-effects meta-analysis across strata, separately for the 1-, 5- and 10-year groupings.
- Across countries: random-effects meta-analysis, Cochran Q and I2, pairwise country differences.
- A difference between countries is checked in W3, where all three countries count diagnoses over the same years. A difference seen in W1 or W2 but not in W3 is reported as a possible effect of register coverage.

## 7. Sensitivity analyses

- W1 versus W2 versus W3.
- W3 with the birth cohort extended to 2015, for ASD.
- h2 and rg compared across relationship types (for example parent-offspring versus avuncular).

## 8. Disclosure and outputs

- No cell below the national minimum (5 in Denmark and Norway, 11 in Sweden) is exported; small cells are merged across adjacent birth years.

| Item     | Content                                                                                          |
|----------|--------------------------------------------------------------------------------------------------|
| Table 1  | Genealogy characteristics per country                                                            |
| Figure 1 | Register coverage per country with the W2 and W3 areas marked                                    |
| Figure 2 | Descriptive incidence and prevalence                                                             |
| Figure 3 | h2 per trait and relationship type, per country and meta-analysed (W1, with W2 and W3 alongside) |
| Figure 4 | rg heat map mental x CVD with between-country heterogeneity                                      |

*Table 8. Planned tables and figures.*
