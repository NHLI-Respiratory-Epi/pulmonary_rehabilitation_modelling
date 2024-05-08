clear all
set more off

cd "E:\Mtech PR Modelling"

local start = clock("$S_DATE $S_TIME", "DMY hms")

local raw_data_dir "E:\AUK-BLF COPD Prevalence"

local analysis_dir "C:\Users\pstone\OneDrive - Imperial College London\Work\Mtech PR Modelling\Stata"

/* Create log file */
capture log close
log using "`analysis_dir'/build_logs/StratificationVars", text replace

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts

local first_year = year(`study_start')
local last_year = year(`study_end')
local month = 7


foreach cohort in prevalent incident qof {
	
	use builds/cohort_`cohort'_copd, clear

	//Merge with Observation file that includes codelists
	merge 1:m patid using "`raw_data_dir'/builds/Observation_compact_all"
	keep if _merge == 3
	drop _merge

	//Remove events after end of follow-up
	drop if obsdate > end_fu

	gsort patid obsdate


	preserve


	// Ethnicity
	//===========
	drop if eth5 == .
	keep patid obsdate eth5

	gsort patid -obsdate  //most recent first

	by patid: gen patobs = _N

	//count of each ethnicity
	by patid: egen whitecount = count(eth5) if eth5 == 0
	by patid: egen southasiancount = count(eth5) if eth5 == 1
	by patid: egen blackcount = count(eth5) if eth5 == 2
	by patid: egen othercount = count(eth5) if eth5 == 3
	by patid: egen mixedcount = count(eth5) if eth5 == 4
	by patid: egen notstatedcount = count(eth5) if eth5 == 5

	//total columns for each patient
	by patid: egen whitemax = max(whitecount)
	by patid: egen southasianmax = max(southasiancount)
	by patid: egen blackmax = max(blackcount)
	by patid: egen othermax = max(othercount)
	by patid: egen mixedmax = max(mixedcount)
	by patid: egen notstatedmax = max(notstatedcount)

	foreach var of varlist whitemax southasianmax blackmax othermax mixedmax notstatedmax {
		
		replace `var' = 0 if `var' == .
	}

	//generate global ethnicity
	drop whitecount southasiancount blackcount othercount mixedcount notstatedcount

	//if all ethnicities are the same, set that as ethnicity
	gen byte ethnicity = eth5 if patobs == whitemax ///
								| patobs == southasianmax ///
								| patobs == blackmax ///
								| patobs == othermax ///
								| patobs == mixedmax ///
								| patobs == notstatedmax

	label values ethnicity eth5

	//where there are multiple ethnicities, choose the most common one
	replace ethnicity = 0 if whitemax > southasianmax ///
						   & whitemax > blackmax ///
						   & whitemax > othermax ///
						   & whitemax > mixedmax

	replace ethnicity = 1 if southasianmax > whitemax ///
						   & southasianmax > blackmax ///
						   & southasianmax > othermax ///
						   & southasianmax > mixedmax

	replace ethnicity = 2 if blackmax > whitemax ///
						   & blackmax > southasianmax ///
						   & blackmax > othermax ///
						   & blackmax > mixedmax

	replace ethnicity = 3 if othermax > whitemax ///
						   & othermax > southasianmax ///
						   & othermax > blackmax ///
						   & othermax > mixedmax

	replace ethnicity = 4 if mixedmax > whitemax ///
						   & mixedmax > southasianmax ///
						   & mixedmax > blackmax ///
						   & mixedmax > othermax
						   
	//where there are 2 or more equally common ethnicities, choose the most recent
	drop if ethnicity == . & eth5 == 5  //get rid of "Not stated" options
	by patid: keep if _n == 1
	replace ethnicity = eth5 if ethnicity == .

	keep patid ethnicity

	compress

	tempfile temp_ethnicity
	save `temp_ethnicity'


	restore, preserve


	// Pulmonary rehabilitation status
	//=================================
	//drop if obsdate < copd_`cohort'_first
	drop if pr == .

	keep patid obsdate considered referred commenced completed

	replace considered = obsdate if considered == 1
	replace referred = obsdate if referred == 1
	replace commenced = obsdate if commenced == 1
	replace completed = obsdate if completed == 1

	format %td considered referred commenced completed

	by patid: egen pr_considered = min(considered)
	by patid: egen pr_referred = min(referred)
	by patid: egen pr_commenced = min(commenced)
	by patid: egen pr_completed = min(completed)

	format %td pr_considered pr_referred pr_commenced pr_completed

	by patid: keep if _n == 1

	keep patid pr_considered pr_referred pr_commenced pr_completed

	//Assume that necessary prior events happened at same time
	//e.g. if first event was commencement of PR, assume referral happened at same time
	//replace pr_considered = min(pr_considered, pr_referred, pr_commenced, pr_completed)
	//replace pr_referred = min(pr_referred, pr_commenced, pr_completed)
	//replace pr_commenced = min(pr_commenced, pr_completed)

	compress

	tempfile temp_pr
	save `temp_pr'


	restore, preserve


	// Smoking status
	//================
	drop if smoking_status == .
	keep patid obsdate smoking_status

	//most recent smoking status at time of prevalence calculation
	forvalues year = `first_year'/`last_year' {
		
		gen byte smoking_status`year' = smoking_status if obsdate <= mdy(`month', 1, `year')
	}

	label values smoking_status20* smoking_status

	//collapse to one row per patient
	collapse (lastnm) smoking_status20*, by(patid)

	label values smoking_status20* smoking_status

	//change never smokers to ex-smokers if they have a history of smoking
	forvalues year = `first_year'/`last_year' {
		
		if `year' > `first_year' {
			
			local prev_year = `year'-1
			
			replace smoking_status`year' = 2 if smoking_status`year' == 1 ///
											  & (smoking_status`prev_year' == 2 ///
												 | smoking_status`prev_year' == 3)
		}
	}

	compress

	tempfile temp_smoking
	save `temp_smoking'


	restore


	// Moderate exacerbations in the year following diagnosis
	//========================================================

	/* AECOPD ALGORITHM:
	*
	*	Excluding annual review days:
	*		- ABX and OCS for 5–14 days; or
	*		- Symptom (2+) definition with prescription of antibiotic or OCS; or
	*		- LRTI code; or
	*		- AECOPD code
	*
	*/

	drop if copd_annualreview == . & cough == . & aecopd_breathlessness == . & sputum == . & lrti == . & aecopd == .
	keep patid start_fu end_fu copd_`cohort'_first obsdate copd_annualreview cough aecopd_breathlessness sputum lrti aecopd

	compress

	tempfile aecopd_lrti
	save `aecopd_lrti'


	//Get drug codes
	use builds/cohort_`cohort'_copd, clear

	keep patid start_fu end_fu copd_`cohort'_first

	//Merge with DrugIssue file that includes codelists
	merge 1:m patid using "`raw_data_dir'/builds/DrugIssue_compact_all"
	keep if _merge == 3
	drop _merge

	//Remove events after end of follow-up
	drop if issuedate > end_fu

	gsort patid issuedate


	preserve


	drop if category_rx == .
	keep patid start_fu end_fu copd_`cohort'_first issuedate category_rx

	rename issuedate obsdate
	append using `aecopd_lrti'

	gsort patid obsdate

	label list category_rx

	gen byte abx = 1 if category_rx == 1
	gen byte ocs = 1 if category_rx == 2
	order cough aecopd_breathlessness sputum, after(ocs)

	//ignore events more than 14 days before COPD diagnosis
	drop if obsdate < copd_`cohort'_first-14

	//collapse to get all events on the same day
	collapse (max) copd_annualreview abx ocs cough aecopd_breathlessness sputum lrti aecopd, by(patid copd_`cohort'_first obsdate)

	//remove events on an annual review day
	drop if copd_annualreview == 1
	drop copd_annualreview

	egen symptoms = rowtotal(cough aecopd_breathlessness sputum)
	order symptoms, after(sputum)

	//only keep days where both antibiotics and oral corticosteroids were prescribed, patient had 2 symptoms and an antibiotic or oral corticosteroid prescribed, or a patient received an AECOPD or LRTI code
	keep if (abx == 1 & ocs == 1) ///
		  | (symptoms >= 2 & (abx == 1 | ocs == 1)) ///
		  | aecopd == 1 ///
		  | lrti == 1

	//count events as exacerbations, excluding those closer together than 14 days
	by patid: gen exacerbation = 1 if _n == 1 | obsdate[_n-1] < obsdate-14

	//exacerbations in the year following diagnosis
	gen exacerbations = 1 if exacerbation == 1 & obsdate <= copd_`cohort'_first + 365.25

	//collapse to get exacerbation count per year for each patient
	collapse (sum) exacerbations, by(patid)

	rename exacerbations moderate_1yr_count
	keep patid moderate_1yr_count

	compress

	tempfile temp_aecopd_moderate
	save `temp_aecopd_moderate'


	restore


	// Inhaled therapy (dual therapy vs. triple therapy)
	//===================================================
	drop if issuedate < copd_`cohort'_first
	
	drop if groups == .
	keep patid issuedate groups

	label list lab1

	//just keep LABA, LAMA, and ICS inhalers
	tab groups, missing
	keep if groups >= 3 & groups <= 8
	tab groups, missing

	gen ics = issuedate if groups == 6 | groups == 7 | groups == 8
	gen laba = issuedate if groups == 4 | groups == 5 | groups == 7 | groups == 8
	gen lama = issuedate if groups == 3 | groups == 5 | groups == 8

	format %td ics laba lama

	//Therapy received in year until time of prevalence calculation
	forvalues year = `first_year'/`last_year' {
		
		gen ics`year' = 1 if ics > mdy(`month', 1, `year'-1) ///
						   & ics <= mdy(`month', 1, `year')
		
		gen laba`year' = 1 if laba > mdy(`month', 1, `year'-1) ///
							& laba <= mdy(`month', 1, `year')
		
		gen lama`year' = 1 if lama > mdy(`month', 1, `year'-1) ///
							& lama <= mdy(`month', 1, `year')
	}

	//collapse to one row per patient
	collapse (max) ics20* laba20* lama20*, by(patid)


	//Determine whether on dual or triple therapy
	forvalues year = `first_year'/`last_year' {
		
		gen byte medication`year' = 1 if ics`year' == . & laba`year' != . & lama`year' != .
		replace medication`year' = 2 if ics`year' != . & laba`year' != . & lama`year' != .
		
		order medication`year', after(lama`year')
	}

	label define medication 1 "Dual therapy (LABA & LAMA)" 2 "Triple therapy (LABA & LAMA & ICS)"
	label values medication20* medication

	keep patid medication20*

	compress

	tempfile temp_medication
	save `temp_medication'



	// Severe exacerbations in the year following diagnosis
	//======================================================

	use builds/cohort_`cohort'_copd, clear
	
	//Merge with HES events
	merge 1:m patid using "`raw_data_dir'/builds/HES_episode_COPD"
	keep if _merge == 3
	drop _merge

	//Restrict to primary and secondary diagnoses
	drop if d_order > 2
	tab d_order, missing

	summarize epistart, format detail

	//Remove events after end of follow-up
	drop if epistart > end_fu

	//Ignore events more than 14 days before COPD diagnosis
	drop if epistart < copd_`cohort'_first-14

	gsort patid epistart

	//count events as exacerbations, excluding those closer together than 14 days
	by patid: gen exacerbation = 1 if _n == 1 | epistart[_n-1] < epistart-14

	//exacerbations in the year following diagnosis
	gen exacerbations = 1 if exacerbation == 1 & epistart <= copd_`cohort'_first + 365.25
	
	//collapse to get exacerbation count per year for each patient
	collapse (sum) exacerbations (min) first_severe_aecopd=epistart (first) copd_`cohort'_first, by(patid)
	
	//Set first severe AECOPD as diagnosis date if the AECOPD occured in the 2 weeks prior to diagnosis (see line 385)
	display "Number of first severe AECOPDs before COPD diagnosis:"
	replace first_severe_aecopd = copd_`cohort'_first if first_severe_aecopd < copd_`cohort'_first
	
	rename exacerbations severe_1yr_count
	keep patid severe_1yr_count first_severe_aecopd

	compress

	tempfile temp_aecopd_severe
	save `temp_aecopd_severe'



	// Merge in variables
	//====================
	use builds/cohort_`cohort'_copd, clear


	foreach var in ethnicity pr smoking medication aecopd_moderate aecopd_severe {
		
		merge 1:1 patid using `temp_`var'', nogenerate keep(match master)
	}

	recode moderate_1yr_count severe_1yr_count (. = 0)

	recode ethnicity (. = 5)
	order ethnicity, after(imd2015_5)


	compress
	save builds/cohort_`cohort'_copd_stratvars, replace
}

log close