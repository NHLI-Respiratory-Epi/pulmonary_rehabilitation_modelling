clear all
set more off

cd "E:\Mtech PR Modelling"

local start = clock("$S_DATE $S_TIME", "DMY hms")

local raw_data_dir "E:\AUK-BLF COPD Prevalence"

local analysis_dir "C:\Users\pstone\OneDrive - Imperial College London\Work\Mtech PR Modelling\Stata"

/* Create log file */
capture log close
log using "`analysis_dir'/build_logs/PostEligiblePR", text replace

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts


// PR STATUS FOLLOWING DATE OF ELIGIBILITY FOR PR

foreach cohort in prevalent incident qof {
	
	display "Cohort: `cohort'"
	
	use builds/cohort_`cohort'_copd_stratvars_value_denom, clear
	
	keep if `cohort' == 1
	
	//Merge with Observation file that includes codelists
	merge 1:m patid using "`raw_data_dir'/builds/Observation_compact_all"
	keep if _merge == 3
	drop _merge
	
	//Just keep PR events
	drop if pr == .
	
	//Remove events after end of follow-up
	drop if obsdate > end_fu

	//Remove events before eligibility
	drop if obsdate < pr_eligible
	
	gsort patid obsdate

	keep patid obsdate pr_eligible considered referred commenced completed

	replace considered = obsdate if considered == 1
	replace referred = obsdate if referred == 1
	replace commenced = obsdate if commenced == 1
	replace completed = obsdate if completed == 1

	format %td considered referred commenced completed

	by patid: egen pr_elig_considered = min(considered)
	by patid: egen pr_elig_referred = min(referred)
	by patid: egen pr_elig_commenced = min(commenced)
	by patid: egen pr_elig_completed = min(completed)

	format %td pr_elig_considered pr_elig_referred pr_elig_commenced pr_elig_completed

	by patid: keep if _n == 1

	keep patid pr_elig_considered pr_elig_referred pr_elig_commenced pr_elig_completed

	//Assume that necessary prior events happened at same time
	//e.g. if first event was commencement of PR, assume referral happened at same time
	//replace pr_elig_considered = min(pr_elig_considered, pr_elig_referred, pr_elig_commenced, pr_elig_completed)
	//replace pr_elig_referred = min(pr_elig_referred, pr_elig_commenced, pr_elig_completed)
	//replace pr_elig_commenced = min(pr_elig_commenced, pr_elig_completed)

	compress

	tempfile temp_pr_`cohort'
	save `temp_pr_`cohort''
	
	use builds/cohort_`cohort'_copd_stratvars_value_denom, clear
	
	merge 1:1 patid using `temp_pr_`cohort''
	drop _merge
	
	order pr_elig_considered pr_elig_referred pr_elig_commenced pr_elig_completed, after(pr_completed)
	
	display "Events before eligible..."
	count if pr_elig_considered < pr_eligible & pr_eligible != .
	count if pr_elig_referred < pr_eligible & pr_eligible != .
	count if pr_elig_commenced < pr_eligible & pr_eligible != .
	count if pr_elig_completed < pr_eligible & pr_eligible != .
	
	display "Events before referred..."
	count if pr_elig_commenced < pr_elig_referred & pr_elig_referred != .
	count if pr_elig_completed < pr_elig_referred & pr_elig_referred != .
	
	save builds/cohort_`cohort'_copd_stratvars_value_denom_eligible, replace
}



log close