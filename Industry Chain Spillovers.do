est clear
capture postclose buffer 
capture mkdir "Figures"
capture mkdir "Placebo_Plots"
capture erase "Results_All.csv" 
set scheme s1color 

xtset city_code year
capture confirm string variable prov
if _rc==0 encode prov, gen(prov_id)

winsor2 IPAG_M IPAG_MU IPAG_MM IPAG_MD POP PGDP PM25 AKNOWL ///
        pol_acc upol_acc mpol_acc dpol_acc, replace cuts(1 99)

foreach v in IPAG_M IPAG_MU IPAG_MM IPAG_MD {
    capture drop ln_`v'
    gen ln_`v' = ln(`v' + 1)
}

capture drop ln_POP ln_PGDP ln_PM25 ln_AKNOWL
gen ln_POP    = ln(POP)
gen ln_PGDP   = ln(PGDP)
gen ln_PM25   = ln(PM25)
gen ln_AKNOWL = ln(AKNOWL + 1)
global controls "ln_POP ln_PGDP STRUC ln_PM25 ln_AKNOWL"

foreach p in pol upol mpol dpol {
    capture drop temp_min
    bysort city_code: egen temp_min = min(year) if `p'_acc > 0
    bysort city_code: egen adopt_`p' = min(temp_min)
    replace adopt_`p' = 0 if missing(adopt_`p')
    drop temp_min
}

global event_dummies "pre_5 pre_4 pre_3 pre_2 pre_1 current post_1 post_2 post_3 post_4 post_5"
local rnm_rule "pre_5=-5 pre_4=-4 pre_3=-3 pre_2=-2 pre_1=-1 current=0 post_1=1 post_2=2 post_3=3 post_4=4 post_5=5"

local x_vars "upol_acc mpol_acc dpol_acc pol_acc pol_acc pol_acc upol_acc upol_acc upol_acc mpol_acc mpol_acc mpol_acc dpol_acc dpol_acc dpol_acc"
local y_vars "IPAG_M IPAG_M IPAG_M IPAG_MU IPAG_MM IPAG_MD IPAG_MU IPAG_MM IPAG_MD IPAG_MU IPAG_MM IPAG_MD IPAG_MU IPAG_MM IPAG_MD"
local p_names "upol mpol dpol pol pol pol upol upol upol mpol mpol mpol dpol dpol dpol"

forvalues i = 1/15 {
    local x_var : word `i' of `x_vars'
    local y_var : word `i' of `y_vars'
    local p_name : word `i' of `p_names'
    
    display ">>> Processing Model `i'/15: `x_var' -> `y_var' (Adopt based on `p_name')"
    
    local current_adopt "adopt_`p_name'"
    gen treat_post = (year >= `current_adopt' & `current_adopt' > 0)
    
    gen event_time = year - `current_adopt'
    replace event_time = . if `current_adopt' == 0 
    
    gen pre_5 = (event_time <= -5 & event_time != .)
    forvalues t = 4(-1)2 {
        gen pre_`t' = (event_time == -`t' & event_time != .)
    }
    gen pre_1 = 0  
    gen current = (event_time == 0 & event_time != .)
    forvalues t = 1/4 {
        gen post_`t' = (event_time == `t' & event_time != .)
    }
    gen post_5 = (event_time >= 5 & event_time != .)

    reghdfe ln_`y_var' treat_post $controls, absorb(city_code year) vce(cluster city_code)
    eststo m`i'_Avg
    global TB_m`i' = _b[treat_post] // 
    
    reghdfe ln_`y_var' $event_dummies $controls, absorb(city_code year) vce(cluster city_code)
    eststo m`i'_Evt
    
    coefplot m`i'_Evt, keep($event_dummies) omitted vertical rename(`rnm_rule') ///
        recast(connected) lcolor(gs5) lwidth(medthick) msymbol(O) mfcolor(white) mlcolor(gs5) msize(medium) ///
        ciopts(recast(rcap) lpattern(dash) color(gs5)) ///
        yline(0, lpattern(dash) lcolor(gs10)) xline(5, lpattern(dash) lcolor(maroon)) ///
        xtitle("Years relative to BESS policy") ytitle("Coefficients") ///
        graphregion(color(white)) name(Plt_`i', replace)
    graph export "Figures/Event_`x_var'_to_`y_var'.png", width(2000) replace

    esttab m`i'_Avg m`i'_Evt using "Results_All.csv", append ///
        b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) r2 obslast nogaps compress plain ///
        mtitles("`x_var'_to_`y_var'_Avg" "`x_var'_to_`y_var'_Evt")

    drop treat_post event_time pre_* current post_*
}

set seed 1234567  
tempfile base_data true_treated all_cities fake_treated
save `base_data', replace  

keep city_code
duplicates drop
save `all_cities', replace

use `base_data', clear
keep if adopt_pol > 0
keep city_code adopt_pol adopt_upol adopt_mpol adopt_dpol
duplicates drop
local n_treat = _N  
save `true_treated', replace

local post_vars ""
forvalues i = 1/15 {
    local post_vars "`post_vars' b_m`i' p_m`i'"
}
capture postclose buffer
postfile buffer `post_vars' using "Placebo_Results_Final.dta", replace

display ">>> Running 500 Placebo Simulations for 15 Models (Strict Two-Step Permutation)..."
forvalues iter = 1/500 {
    quietly {
        use `true_treated', clear
        gen rsort = runiform()
        sort rsort
        gen match_id = _n
        drop city_code // 
        save `fake_treated', replace
        
        use `all_cities', clear
        gen rsort = runiform()
        sort rsort
        keep in 1/`n_treat'
        gen match_id = _n
        
        merge 1:1 match_id using `fake_treated', nogenerate
        drop rsort match_id
        rename adopt_pol f_adopt_pol
        rename adopt_upol f_adopt_upol
        rename adopt_mpol f_adopt_mpol
        rename adopt_dpol f_adopt_dpol
        
        merge 1:m city_code using `base_data'
        
        replace f_adopt_pol  = 0 if _merge == 2
        replace f_adopt_upol = 0 if _merge == 2
        replace f_adopt_mpol = 0 if _merge == 2
        replace f_adopt_dpol = 0 if _merge == 2
        drop _merge

        local current_res ""
        forvalues i = 1/15 {
            local y_var : word `i' of `y_vars'
            local p_name : word `i' of `p_names'
            
            local f_adopt "f_adopt_`p_name'"
            gen fdid = (year >= `f_adopt' & `f_adopt' > 0)

            cap reghdfe ln_`y_var' fdid $controls, absorb(city_code year) vce(cluster city_code)
            if _rc == 0 {
                local b_val = _b[fdid]
                local p_val = 2 * ttail(e(df_r), abs(_b[fdid]/_se[fdid])) 
            }
            else {
                local b_val = .
                local p_val = .
            }
            local current_res "`current_res' (`b_val') (`p_val')"
            drop fdid
        }
        post buffer `current_res'
    }
    if mod(`iter', 50) == 0 display "Iteration `iter' finished"
}
postclose buffer

clear
use "Placebo_Results_Final.dta", clear

local x_vars "upol_acc mpol_acc dpol_acc pol_acc pol_acc pol_acc upol_acc upol_acc upol_acc mpol_acc mpol_acc mpol_acc dpol_acc dpol_acc dpol_acc"
local y_vars "IPAG_M IPAG_M IPAG_M IPAG_MU IPAG_MM IPAG_MD IPAG_MU IPAG_MM IPAG_MD IPAG_MU IPAG_MM IPAG_MD IPAG_MU IPAG_MM IPAG_MD"

capture mkdir "Placebo_Plots"

forvalues i = 1/15 {
    local x_var : word `i' of `x_vars'
    local y_var : word `i' of `y_vars'
    
    local t_beta = ${TB_m`i'}
    
    if "`t_beta'" == "" {
        local t_beta = 0
        display as error "Warning: Global macro TB_m`i' is missing. Red line set to 0 for `x_var' -> `y_var'."
    }
    
    quietly summarize b_m`i'
    local b_min = r(min)
    local b_max = r(max)
    local max_l = max(abs(`b_min'), abs(`b_max'), abs(`t_beta'))
    local bound = `max_l' * 1.3
    
    twoway (kdensity b_m`i', recast(area) color(gs14) yaxis(2)) /// 
           (scatter p_m`i' b_m`i', msymbol(Oh) mcolor(gs8) msize(small) yaxis(1)) /// 
           (function y=0.1, range(-`bound' `bound') yaxis(1) lcolor(blue) lpattern(dash) lwidth(medium)), /// 
           xline(`t_beta', lcolor(red) lwidth(thick) lpattern(solid)) /// 
           xlabel(-`bound' 0 `t_beta' `bound', format(%9.3f) labsize(small)) ///
           xtitle("Placebo Coefficients", size(small)) /// 
           ytitle("P-value", axis(1) size(small)) ytitle("Kernel Density", axis(2) size(small)) ///
           legend(order(2 "Placebo P-values" 1 "Kernel Density") pos(6) cols(2) size(small)) ///
           graphregion(color(white)) plotregion(lcolor(black) lwidth(medium)) ///
           name(Plc_`i', replace)
    
    graph export "Placebo_Plots/Placebo_`x_var'_to_`y_var'.png", width(1600) replace
}

display ">>> ALL 15 MODELS PROCESSES COMPLETED SUCCESSFULLY."