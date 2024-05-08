clear all
set more off

cd "E:\Mtech PR Modelling"

local start = clock("$S_DATE $S_TIME", "DMY hms")

local raw_data_dir "E:\AUK-BLF COPD Prevalence"

local analysis_dir "C:\Users\pstone\OneDrive - Imperial College London\Work\Mtech PR Modelling\Stata"

/* Create log file */
capture log close
log using "`analysis_dir'/build_logs/BuildCOPDCohort", text replace

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts


use builds/cohort, clear


//Merge with observation file that includes codelists
merge 1:m patid using "`raw_data_dir'/builds/Observation_compact_all"
keep if _merge == 3
drop _merge

gsort patid obsdate


rename copd_validated copd_prevalent

//Get first event for each definition in Observation file
foreach var in copd_prevalent copd_incident copd_qof smoking_status {
	
	preserve

	keep if `var' != .
	
	if inlist("`var'", "smoking_status") {
		
		display "Removing non-smoker events."
		
		drop if smoking_status == 1
	}
	
	by patid: keep if _n == 1

	generate `var'_first = obsdate
	format %td `var'_first

	keep patid `var'_first
	
	tempfile temp_`var'
	save `temp_`var''

	restore
}


//Add vars to dataset
use builds/cohort, clear

foreach var in smoking_status copd_qof copd_incident copd_prevalent {
	
	merge 1:1 patid using `temp_`var'', nogenerate keep(match master)
	
	if inlist("`var'", "copd_prevalent", "copd_incident", "copd_qof") {
		
		gen `var'_age = year(`var'_first) - yob  //everyone born on 1st Jan
		order `var'_age, before(`var'_first)
	}
}

summarize copd_incident_age copd_prevalent_age copd_qof_age, detail

// Replace prevalent date with incident date if incident date first (or prevalent missing)
replace copd_prevalent_first = copd_incident_first if copd_incident_first < copd_prevalent_first
replace copd_prevalent_age = year(copd_prevalent_first) - yob


// Remove incident date if prevalent code before incident code
replace copd_incident_first = . if copd_prevalent_first < copd_incident_first
replace copd_incident_age = year(copd_incident_first) - yob

summarize copd_incident_age copd_prevalent_age, detail


preserve


// INCIDENT COPD COHORT
//======================

//Remove if no COPD diagnosis
drop if copd_incident_first == .

//Make sure diagnosis is in follow-up peroid
drop if copd_incident_first < start_fu | copd_incident_first > end_fu

count

gsort patid

compress
save builds/cohort_incident_copd, replace


restore, preserve


// PREVALENT COPD COHORT
//=======================

//Remove if no COPD diagnosis
drop if copd_prevalent_first == .

//Make sure diagnosis is before end of follow-up peroid
drop if copd_prevalent_first > end_fu

//not removed patients with diagnosis at <35 years as this is done at the denominator stage

count

gsort patid

compress
save builds/cohort_prevalent_copd, replace


// Label prevalent cases with a prevalent code during study period

//Merge with observation file that includes codelists
merge 1:m patid using "`raw_data_dir'/builds/Observation_compact_all"
keep if _merge == 3
drop _merge

gsort patid obsdate


keep if copd_validated != .

drop if obsdate < `study_start' - 365.25
drop if obsdate > `study_end'

generate byte prevalent_in_study = 1

keep patid prevalent_in_study

bysort patid: keep if _n == 1


merge 1:1 patid using builds/cohort_prevalent_copd, nogenerate
order prevalent_in_study, last


recode prevalent_in_study (. = 0)
tab prevalent_in_study, missing

//drop if not prevalent during study period
drop if prevalent_in_study == 0
drop prevalent_in_study

gsort patid

save builds/cohort_prevalent_copd, replace


restore


// QOF COPD COHORT
//=================

//Remove if no COPD diagnosis
drop if copd_qof_first == .

//Make sure diagnosis is before end of follow-up peroid
drop if copd_qof_first > end_fu

count

gsort patid

compress
save builds/cohort_qof_copd, replace


log close