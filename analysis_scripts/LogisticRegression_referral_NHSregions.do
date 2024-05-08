//===============================================+
// REFERRAL IN 1 YEAR FOR THOSE WHO ARE ELIGIBLE |
//===============================================+

clear all
set more off

cd "Z:\Group_work\Phil\Mtech PR Modelling"

/* Create log file */
capture log close
log using analysis_logs/LogisticRegression_referral_NHSregions, smcl replace

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts

local first_year = year(`study_start')
local last_year = year(`study_end')
local month = 7


//Using QOF cohort as this will be the data input to the model
use builds/cohort_qof_copd_stratvars_value_denom_eligible, clear


//Just keep the QOF definition (get rid of incident/prevalent definitions)
drop copd_incident_age copd_incident_first copd_prevalent_age copd_prevalent_first

//Not interested in consideration
drop pr_considered pr_elig_considered

//Just keep the referral, commenced, and completed events following eligibility date
drop pr_referred pr_commenced pr_completed


//Infer previous events from subequent events
//e.g. assume referred if commenced (and use same date)
replace pr_elig_commenced = pr_elig_completed if pr_elig_commenced > pr_elig_completed
replace pr_elig_referred = pr_elig_commenced if pr_elig_referred > pr_elig_commenced


//Just keep patients with a COPD diagnosis
drop if copd_qof_first == .

//Just keep patients that are eligible for PR
drop if pr_eligible == .


//Remove patients with ELIGIBLE before start of follow-up
drop if pr_eligible < start_fu

//Remove patients with less than a year follow-up after ELIGIBLE
drop if end_fu < (pr_eligible + 365.25)


//Age at ELIGIBLE
gen age = year(pr_eligible) - yob
summarize age, detail
order age, after(pr_eligible)

//Categorical age
assert age != .
gen age_cat = 1 if age >= 35
replace age_cat = 2 if age >= 50
replace age_cat = 3 if age >= 60
replace age_cat = 4 if age >= 70
replace age_cat = 5 if age >= 80
label define age_cat 1 "35-49" 2 "50-59" 3 "60-69" 4 "70-79" 5 "80+"
label values age_cat age_cat
order age_cat, after(age)


//Generate NHS region
label list Region
label define nhs_region ///
	1 "North East and Yorkshire" ///
	2 "North West" ///
	3 "Midlands" ///
	4 "East of England" ///
	5 "South West" ///
	6 "London" ///
	7 "South East"
recode region (3=1) (4 5=3) (6=4) (7=5) (8 10=7) (9=6), generate(nhs_region)
label values nhs_region nhs_region
order nhs_region, after(region)
tab region nhs_region
drop region


//Outcome (within 1 year of ELIGIBLE)
gen byte referred = (pr_elig_referred <= (pr_eligible + 365.25))
order referred, after(pr_elig_referred)



// Summary statistics
//====================

//Predictors
summarize age, detail
tab1 age_cat gender imd2015_5 ethnicity nhs_region

//Outcomes
tab1 referred



// Outcome stratified by predictors (age, gender, IMD, ethnicity)
//================================================================

  ** ONLY PROVIDES PERCENTAGE (%), NOT FREQUENCY **
  
table (age_cat gender imd2015_5 ethnicity) (referred) (nhs_region), statistic(percent) //statistic(mean age)



// Logistic regression models
//============================

//Nationally
logit referred i.age_cat i.gender i.imd2015_5 i.ethnicity, base


//Regionally
tab nhs_region, nolabel
describe nhs_region
label list nhs_region

forvalues eng_region = 1/7 {
	
	display "{hline 100}"
	display "English region: `eng_region'"
	tab nhs_region if nhs_region == `eng_region'

	logit referred i.age_cat i.gender i.imd2015_5 i.ethnicity if nhs_region == `eng_region', base
}


log close
translate analysis_logs/LogisticRegression_referral_NHSregions.smcl ///
		  outputs/LogisticRegression_referral_NHSregions.pdf