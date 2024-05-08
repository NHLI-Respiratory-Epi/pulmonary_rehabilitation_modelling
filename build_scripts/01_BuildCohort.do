clear all
set more off

cd "E:\Mtech PR Modelling"

local start = clock("$S_DATE $S_TIME", "DMY hms")

local raw_data_dir "E:\AUK-BLF COPD Prevalence"

local analysis_dir "C:\Users\pstone\OneDrive - Imperial College London\Work\Mtech PR Modelling\Stata"

local linked_dir "E:\AUK-BLF COPD Prevalence\CPRD Full Linked Data (2)\21_000596_Results\Aurum_linked\Final"

/* Create log file */
capture log close
log using "`analysis_dir'/build_logs/BuildCohort", text replace

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts


//Combine Practice files
use "`raw_data_dir'/stata_data/Practice", clear

if `cohorts' > 1 {
	
	forvalues i = 2/`cohorts' {
		
		append using "`raw_data_dir'/stata_data/Practice`i'"
	}
}

summarize lcd, format detail
drop if lcd >= mdy(5, 1, 2021)

tab region, missing
drop if region == .

codebook pracid
bysort pracid: keep if _n == 1

tempfile practices
save `practices'


//Start with Patient file
use "`raw_data_dir'/stata_data/Patient"

if `cohorts' > 1 {
	
	forvalues i = 2/`cohorts' {
		
		append using "`raw_data_dir'/stata_data/Patient`i'"
	}
}

drop usualgpstaffid  //don't need

tab gender, missing  //restrict to male and female patients
keep if gender == 1 | gender == 2
tab gender, missing

tab patienttypeid, missing
drop patienttypeid  //all patients = "Regular"

drop emis_ddate  //apparently not very reliable, use cprd_ddate instead

//Check all date variables & remove if after cut date (May 2021)
summarize yob regstartdate regenddate cprd_ddate, format detail
drop if regstartdate >= mdy(5, 1, 2021)
drop if regenddate >= mdy(5, 1, 2021) & regenddate != .
drop if cprd_ddate >= mdy(5, 1, 2021) & cprd_ddate != .
summarize yob regstartdate regenddate cprd_ddate, format

//Birthday assumed as 1st Jan
gen dob = mdy(1, 1, yob)
gen do35 = mdy(1, 1, yob+35)
order dob do35, after(yob)
format %td dob do35


//Merge Practice data
merge m:1 pracid using `practices'

summarize yob regstartdate regenddate cprd_ddate if _merge == 1, format detail

keep if _merge == 3
drop _merge


preserve //=====================================================================

//Import linkage information

import delimited "`raw_data_dir'/CPRD/Aurum_Linkages_Set_21/linkage_eligibility.txt", clear stringcols(1)

drop death_e cr_e mh_e

cprddate linkdate
tab linkdate, missing
drop linkdate  //they're all the same and this does not affect follow-up time

compress
tempfile link_eligibility
save `link_eligibility'


import delimited "`raw_data_dir'/CPRD/Aurum_Linkages_Set_21/linkage_coverage.txt", clear varnames(1)

cprddate start end

compress
tempfile link_coverage
save `link_coverage'


//Import IMD Data

import delimited "`linked_dir'/patient_imd2015_21_000596_request2.txt", clear stringcols(1)

tempfile imd
save `imd'

restore //======================================================================

//Merge linkage information with cohort
count
merge 1:1 patid using `link_eligibility'
keep if _merge == 3
drop _merge

tab1 hes_e lsoa_e, missing
keep if hes_e == 1 & lsoa_e == 1
tab1 hes_e lsoa_e, missing
drop hes_e lsoa_e

gen data_source = "hes_apc"
merge m:1 data_source using `link_coverage'
drop if _merge == 2
drop _merge data_source
rename start hes_start
rename end hes_end


//Merge with IMD data
merge 1:1 patid using `imd'
keep if _merge == 3
drop _merge


//Calculate follow-up
//require to be at least 35
//require 1 year of follow-up before entering cohort
gen start_fu = max(regstartdate+365.25, hes_start, `study_start', do35)
gen end_fu = min(regenddate, cprd_ddate, lcd, hes_end, `study_end')
format %td start_fu end_fu
drop if start_fu >= end_fu

summarize start_fu end_fu, format detail


compress
save builds/cohort, replace

log close