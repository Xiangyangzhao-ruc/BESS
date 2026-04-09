est clear
capture postclose buffer 
capture mkdir "Figures"
capture mkdir "Placebo_Plots"
set scheme s1color 

xtset city_code year
capture confirm string variable prov
if _rc==0 encode prov, gen(prov_id)

winsor2 IPAG_A IPAG_M IPAG_K POP PGDP PM25 AKNOWL pol_acc pol_rate, replace cuts(1 99)

foreach v in IPAG_A IPAG_M IPAG_K {
    capture drop ln_`v'
    gen ln_`v' = ln(`v' + 1)
}

capture drop ln_POP ln_PGDP ln_PM25 ln_AKNOWL
gen ln_POP    = ln(POP)
gen ln_PGDP   = ln(PGDP)
gen ln_PM25   = ln(PM25)
gen ln_AKNOWL = ln(AKNOWL + 1)
global controls "ln_POP ln_PGDP STRUC ln_PM25 ln_AKNOWL"

capture drop adopt_year temp_min
bysort city_code: egen temp_min = min(year) if pol_acc > 0
bysort city_code: egen adopt_year = min(temp_min)
replace adopt_year = 0 if missing(adopt_year)
drop temp_min

quietly summarize year
local min_yr = r(min) + 1
local max_yr = r(max) - 1
local bound_yr = `max_yr' + 1

foreach m in A M K {
    display ">>> Processing Method `m' using CSDID ..."
    
    quietly csdid ln_IPAG_`m' $controls, ivar(city_code) time(year) gvar(adopt_year) vce(cluster city_code)
    
    quietly estat simple, estore(`m'_Avg_Bin)
    matrix b_simple = r(b)
    global TB_`m' = b_simple[1,1] 
    
    quietly estat event, window(-5 5) estore(`m'_Evt_Bin)
    
    coefplot `m'_Evt_Bin, vertical ///
    keep(Tm5 Tm4 Tm3 Tm2 Tm1 Tp0 Tp1 Tp2 Tp3 Tp4 Tp5) ///
    rename(Tm5=-5 Tm4=-4 Tm3=-3 Tm2=-2 Tm1=-1 Tp0=0 Tp1=1 Tp2=2 Tp3=3 Tp4=4 Tp5=5) ///
    recast(connected) lcolor(gs5) lwidth(medthick) msymbol(O) mfcolor(white) mlcolor(gs5) msize(medlarge) ///
    ciopts(recast(rcap) lpattern(dash) color(gs5)) ///
    yline(0, lpattern(dash) lcolor(gs10)) xline(6, lpattern(dash) lcolor(maroon)) ///
    xtitle("Years relative to BESS policy", size(vlarge)) ///
    ytitle("CSDID Coefficients", size(vlarge)) ///
    xlabel(, labsize(vlarge)) ///
    ylabel(, labsize(vlarge)) ///
    graphregion(color(white)) name(`m'_CSDID_Plt, replace)
        
    graph export "Figures/CSDID_Event_`m'.png", width(2000) replace

    esttab `m'_Avg_Bin `m'_Evt_Bin using "Results_CSDID_`m'.csv", replace ///
        b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) r2 obslast nogaps compress plain ///
        mtitles("CSDID_ATT" "CSDID_Event")
}

set seed 1234567  
tempfile base_data true_treated all_cities fake_treated
save `base_data', replace  

keep city_code
duplicates drop
save `all_cities', replace

use `base_data', clear
keep if adopt_year > 0
keep city_code adopt_year
duplicates drop
local n_treat = _N  
save `true_treated', replace

capture postclose buffer
postfile buffer b_A p_A b_M p_M b_K p_K using "Placebo_Results_Final.dta", replace

display ">>> Running 500 Fast Placebo Simulations for CSDID (Strict Memory Mode)..."
forvalues i = 1/500 {
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
        rename adopt_year f_yr
        
        merge 1:m city_code using `base_data'
        replace f_yr = 0 if _merge == 2  // 
        drop _merge
        
        local current_res ""
        
        foreach y in A M K {
            local b_val = .
            local p_val = .
            
            cap csdid ln_IPAG_`y' $controls, ivar(city_code) time(year) gvar(f_yr) vce(cluster city_code)
            if _rc == 0 {
                cap estat simple
                if _rc == 0 {
                    matrix b_mat = r(b)
                    matrix v_mat = r(V)
                    local b_val = b_mat[1,1]
                    local se_val = sqrt(v_mat[1,1])
                    if `se_val' > 0 {
                        local p_val = 2 * normal(-abs(`b_val' / `se_val')) 
                    }
                }
            }
            local current_res "`current_res' (`b_val') (`p_val')"
        }
        
        post buffer `current_res'
    }
    if mod(`i', 50) == 0 display "Iteration `i' finished"
}
postclose buffer

clear
capture mkdir "Placebo_Plots"

use "Placebo_Results_Final.dta", clear

global TB_A = 0.110  // 
global TB_M = 0.133  // 
global TB_K = 0.183  // 

display ">>> Generating 3 CSDID Placebo Plots from saved data..."

foreach y in A M K {
    
    local t_beta = ${TB_`y'}
    
    capture confirm variable b_`y'
    if _rc != 0 {
        display as error "Warning: can not find b_`y'！"
        continue // 
    }
    
    quietly summarize b_`y'
    local b_min = r(min)
    local b_max = r(max)
    local max_l = max(abs(`b_min'), abs(`b_max'), abs(`t_beta'))
    local bound = `max_l' * 1.3
    
    twoway (kdensity b_`y', recast(area) color(gs14) yaxis(2)) /// 
           (scatter p_`y' b_`y', msymbol(Oh) mcolor(gs8) msize(medium) yaxis(1)) /// 
           (function y=0.1, range(-`bound' `bound') yaxis(1) lcolor(blue) lpattern(dash) lwidth(medium)), /// 
           xline(`t_beta', lcolor(red) lwidth(thick) lpattern(solid)) /// 
           xlabel(-`bound' 0 `t_beta' `bound', format(%9.2f) labsize(vlarge)) ///
           xtitle("Placebo Coefficients", size(vlarge)) ///
           ytitle("P-value", axis(1) size(vlarge)) ///
           ytitle("Kernel Density", axis(2) size(vlarge)) ///
           ylabel(, labsize(vlarge) axis(1)) ///
           ylabel(, labsize(vlarge) axis(2)) ///
           legend(order(2 "Placebo P-values" 1 "Kernel Density") pos(6) cols(2) size(vlarge)) ///
           graphregion(color(white)) plotregion(lcolor(black) lwidth(vthin)) /// 
           name(Plc_CSDID_`y', replace)
    
    graph export "Placebo_Plots/Placebo_CSDID_`y'.png", width(2000) replace
}

display ">>> ALL CSDID PLACEBO PLOTS GENERATED SUCCESSFULLY."