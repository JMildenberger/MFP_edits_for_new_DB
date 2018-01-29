/*Allows SEG to replace variable names with spaces from Excel files with an underscore*/
options validvarname=v7;
options nosyntaxcheck;

libname capital 'Q:\MFP\SAS Libraries\Manufacturing\Capital\capital';
libname comp 'Q:\MFP\SAS Libraries\Manufacturing\Capital\comp';
libname deflator 'Q:\MFP\SAS Libraries\Manufacturing\Capital\deflator';
libname sptools 'Q:\MFP\SAS Libraries\Manufacturing\Capital\sptools';
libname lives 'Q:\MFP\SAS Libraries\Manufacturing\Capital\lives';
libname ras 'Q:\MFP\SAS Libraries\Manufacturing\Capital\ras';
libname beadfnew 'Q:\MFP\SAS Libraries\Manufacturing\Capital\beadfnew';
libname invest 'Q:\MFP\SAS Libraries\Manufacturing\Capital\invest';
libname rental 'Q:\MFP\SAS Libraries\Manufacturing\Capital\rental';
libname kdetails 'Q:\MFP\SAS Libraries\Manufacturing\Capital\kdetails';
libname kstock4d 'Q:\MFP\SAS Libraries\Manufacturing\Capital\kstock4d';
libname pqfork 'Q:\MFP\SAS Libraries\Manufacturing\Capital\pqfork';
libname stock 'Q:\MFP\SAS Libraries\Manufacturing\Capital\stock';
libname final 'Q:\MFP\SAS Libraries\Manufacturing\Capital\final';
libname exports 'Q:\MFP\SAS Libraries\Manufacturing\Capital\exports';
libname IP 'Q:\MFP\SAS Libraries\Manufacturing\IP';

options errors=0;
/*Creating a macro variable for the update year*/
 data _null_;
      length updateid 3 firstyr 4 lastyr 4 baseperiod 3;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input updateid firstyr lastyr baseperiod;
      call symput('last', trim(left(put(lastyr, 4.))));
run;
 %put &last;

/*****************Calculating BLS PPI deflators for 1987-forward for industry/asset combination**************/

/*First step, calculate each industry's share weight by using the 1997 commodity flow table*/
proc sort data=capital.commodity_flow_table;
by commodity;
run;
proc sort data=deflator.commodity_flow_ppi;
by commodity;
run;
data work.commodity;
merge capital.commodity_flow_table deflator.commodity_flow_ppi;
by commodity;
if aces_asset= . then delete;
keep commodity ppi aces_asset cft:;
run;

proc sort data=work.commodity;
by aces_asset;
run;

proc means data=commodity n sum noprint;
by aces_asset;
output out=work.commodity_asset_totals sum 
								(CFT3110	CFT3121	CFT3122	CFT3130	CFT3140	CFT3150	CFT3160	CFT3210	CFT3221	CFT3222	
								CFT3230	CFT3240	CFT3251	CFT3252	CFT3253	CFT3254	CFT3255	CFT3256	CFT3259	CFT3260	
								CFT3270	CFT331A	CFT331B	CFT3315	CFT3321	CFT3322	CFT3323	CFT3324	CFT332A	CFT332B	
								CFT3331	CFT3332	CFT3333	CFT3334	CFT3335	CFT3336	CFT3339	CFT3341	CFT334A	CFT3344	
								CFT3345	CFT3346	CFT3351	CFT3352	CFT3353	CFT3359	CFT3361	CFT336A	CFT3364	CFT336B		
								CFT3370	CFT3391	CFT3399) =
								sum_CFT3110	sum_CFT3121	sum_CFT3122	sum_CFT3130	sum_CFT3140	sum_CFT3150	sum_CFT3160	
								sum_CFT3210	sum_CFT3221	sum_CFT3222	sum_CFT3230	sum_CFT3240	sum_CFT3251	sum_CFT3252	
								sum_CFT3253	sum_CFT3254	sum_CFT3255	sum_CFT3256	sum_CFT3259	sum_CFT3260	sum_CFT3270	
								sum_CFT331A	sum_CFT331B	sum_CFT3315	sum_CFT3321	sum_CFT3322	sum_CFT3323	sum_CFT3324	
								sum_CFT332A	sum_CFT332B	sum_CFT3331	sum_CFT3332	sum_CFT3333	sum_CFT3334	sum_CFT3335	
								sum_CFT3336	sum_CFT3339	sum_CFT3341	sum_CFT334A	sum_CFT3344	sum_CFT3345	sum_CFT3346	
								sum_CFT3351	sum_CFT3352	sum_CFT3353	sum_CFT3359	sum_CFT3361	sum_CFT336A	sum_CFT3364	
								sum_CFT336B	sum_CFT3370	sum_CFT3391	sum_CFT3399;
run;

data work.commodity_shares;
merge work.commodity work.commodity_asset_totals;
by aces_asset;
array indy {*} cft:;
array totals {*} sum:;
array shares {*}    cft_shares3110 cft_shares3121 cft_shares3122	cft_shares3130	cft_shares3140	cft_shares3150	
					cft_shares3160	cft_shares3210	cft_shares3221	cft_shares3222	cft_shares3230	cft_shares3240	
					cft_shares3251	cft_shares3252	cft_shares3253	cft_shares3254	cft_shares3255	cft_shares3256	
					cft_shares3259	cft_shares3260	cft_shares3270	cft_shares331A	cft_shares331B	cft_shares3315	
					cft_shares3321	cft_shares3322	cft_shares3323	cft_shares3324	cft_shares332A	cft_shares332B	
					cft_shares3331	cft_shares3332	cft_shares3333	cft_shares3334	cft_shares3335	cft_shares3336	
					cft_shares3339	cft_shares3341	cft_shares334A	cft_shares3344	cft_shares3345	cft_shares3346	
					cft_shares3351	cft_shares3352	cft_shares3353	cft_shares3359	cft_shares3361	cft_shares336A	
					cft_shares3364	cft_shares336B	cft_shares3370	cft_shares3391	cft_shares3399;
	do i=1 to dim(indy);
		shares {i} = indy {i}/ totals {i};
	end;

keep commodity ppi aces_asset cft_shares:;
run;

proc sort data=deflator.commodity_flow_ppi;
by aces_asset;
run;

/*Second, merge industry commodity shares with the PPI dataset and TQ each PPIs for similiar assets */

%macro loop ;
%do indy=3110 %to 3399;
/*calculating the change in logs of each commodity PPI index*/
data work.tq&indy;
merge deflator.commodity_flow_ppi work.commodity_shares;
by aces_asset;
if aces_asset=. then delete;
array index {*} index1987-index&last;
array logs {*} logs1987-logs&last;
	do i=2 to dim(index);
		logs {i} = log(index {i}) - log(index {i-1});
	end;
keep commodity ppi aces_asset cft_shares&indy logs:;	
run;
/*Multiply each commodity PPI change in log by corresponding industry weight*/
data work.tq&indy;
set work.tq&indy;
array logs {*} logs1987-logs&last;
array weighted {*} weighted1987-weighted&last;
	do i= 1 to dim(logs);
	weighted {i} = logs {i} * cft_shares&indy;
	end;
keep aces_asset weighted:;
run;
/*Sum weighted logs by asset*/
proc means data=work.tq&indy n sum noprint;
by aces_asset;
var weighted1987-weighted&last;
output out=work.tq2&indy sum (weighted1987-weighted&last)= sumwtd1987-sumwtd&last;
run;
/*Chain link each asset for 1987-forward*/
data work.PPI_&indy;
set work.tq2&indy;
array sumwtd {*} sumwtd:;
array divind {*} divind1987-divind&last;
	do i=1 to dim(sumwtd);
	divind {i} = exp(sumwtd {i});
	end;
array chain {*} chain_&indy._1987-chain_&indy._&last;
chain_&indy._1987=100;
	do i=2 to dim(chain);
	chain {i} = chain {i-1} * divind {i};
	end;
/*rebasing deflators to 1997*/
array tq {*} PPIs_&indy._1987-PPIs_&indy._&last;
	do i=1 to dim(tq);
	TQ {i} = chain {i} / Chain_&indy._1997;
	if tq {i} = . then tq {i}=0;
	end;
keep aces_asset ppis:;
run;
%end;
%mend loop;
%loop;

%macro loop2 (indy =) ;
/*calculating the change in logs of each commodity PPI index*/
data work.tq&indy;
merge deflator.commodity_flow_ppi work.commodity_shares;
by aces_asset;
if aces_asset=. then delete;
array index {*} index1987-index&last;
array logs {*} logs1987-logs&last;
	do i=2 to dim(index);
		logs {i} = log(index {i}) - log(index {i-1});
	end;
keep commodity ppi aces_asset cft_shares&indy logs:;	
run;
/*Multiply each commodity PPI change in log by corresponding industry weight*/
data work.tq&indy;
set work.tq&indy;
array logs {*} logs1987-logs&last;
array weighted {*} weighted1987-weighted&last;
	do i= 1 to dim(logs);
	weighted {i} = logs {i} * cft_shares&indy;
	end;
/*keep aces_asset weighted:;*/
run;
/*Sum weighted logs by asset*/
proc means data=work.tq&indy n sum noprint;
by aces_asset;
var weighted1987-weighted&last;
output out=work.tq2&indy sum (weighted1987-weighted&last)= sumwtd1987-sumwtd&last;
run;
/*Chain link each asset for 1987-forward*/
data work.PPI_&indy;
set work.tq2&indy;
array sumwtd {*} sumwtd:;
array divind {*} divind1987-divind&last;
	do i=1 to dim(sumwtd);
	divind {i} = exp(sumwtd {i});
	end;
array chain {*} chain_&indy._1987-chain_&indy._&last;
chain_&indy._1987=100;
	do i=2 to dim(chain);
	chain {i} = chain {i-1} * divind {i};
	end;
/*rebasing deflators to 1997*/
array tq {*} PPIs_&indy._1987-PPIs_&indy._&last;
	do i=1 to dim(tq);
	TQ {i} = chain {i} / Chain_&indy._1997;
	if tq {i} = . then tq {i}=0;
	end;
keep aces_asset ppis:;
run;
%mend loop2;
%loop2 (indy=331A);
%loop2 (indy=331B);
%loop2 (indy=332A);
%loop2 (indy=332B);
%loop2 (indy=334A);
%loop2 (indy=336A);
%loop2 (indy=336B);

 proc copy in= work
			out= deflator;
			select  ppi_3110 ppi_3121 ppi_3122	ppi_3130	ppi_3140	ppi_3150	
					ppi_3160	ppi_3210	ppi_3221	ppi_3222	ppi_3230	ppi_3240	
					ppi_3251	ppi_3252	ppi_3253	ppi_3254	ppi_3255	ppi_3256	
					ppi_3259	ppi_3260	ppi_3270	ppi_331A	ppi_331B	ppi_3315	
					ppi_3321	ppi_3322	ppi_3323	ppi_3324	ppi_332A	ppi_332B	
					ppi_3331	ppi_3332	ppi_3333	ppi_3334	ppi_3335	ppi_3336	
					ppi_3339	ppi_3341	ppi_334A	ppi_3344	ppi_3345	ppi_3346	
					ppi_3351	ppi_3352	ppi_3353	ppi_3359	ppi_3361	ppi_336A	
					ppi_3364	ppi_336B	ppi_3370	ppi_3391	ppi_3399;
run;

/***********Linking the 1987-forward equipment PPI asset deflators with historical BEA deflators *********************/

/*Creating a macro variable for the number of rows in the BEA deflators dataset*/
data _null_;
set beadfnew.aces_pri nobs=obs;
call symputx ('BEA_Number_Years', obs);
run;
%put &BEA_Number_Years;

proc transpose data=beadfnew.aces_pri out=work.aces_pri
 (rename=(col1-col&BEA_Number_Years=BEA_Deflator1901-BEA_Deflator&last));
run;
/*Truncating the name of the assets to match those from the PPI datasets and removing structures from the dataset*/
data work.aces_pri;
set work.aces_pri ;
if _name_="year" then delete;
if _name_="SoftRat" then delete;
if substr(_name_,1,1)="s" then delete;
Aces_Asset=substr(_name_,10)*1;
drop _name_ _label_ BEA_Deflator1901-BEA_Deflator1946 ;
run;

/*Merging the BEA deflator and PPI deflator datasets*/
%macro loop;
%do indy=3110 %to 3399;
/*First, replace the PPI for asset 5 with CapDefAsset5 */
data work.deflator&indy;
merge deflator.ppi_&indy deflator.capdefasset5;
by aces_asset;
array ppi {*} PPIs_&indy._1987-PPIs_&indy._&last;
array asset_5 {*} Year1987-Year&last;
	do i=1 to dim(ppi);
	if aces_asset=5 then ppi {i} = asset_5 {i};
	end;
run;

data work.deflator&indy;
merge work.aces_pri work.deflator&indy;
by aces_asset;

	array bea_deflator_linked {*} BEA_Deflator_Linked1947-BEA_Deflator_Linked&last;
	array bea_deflator {*} BEA_Deflator1947-BEA_Deflator&last;
	array deflator {*} deflator_1947-deflator_&last;
	array ppi {*} PPIs_&indy._1947-PPIs_&indy._&last;
	array ppi_replace {*} PPIs_&indy._1987-PPIs_&indy._&last;
	array bea_replace {*} BEA_Deflator1987-BEA_Deflator&last;

	/*Creating a variable to see if the sum of PPI deflators across years 1987-forward for any asset equals zero*/
	Zero = sum (of PPIs_&indy._:);

	/*Replacing PPI deflators that are zero for all years with BEA Deflators*/
	do i=1 to dim(ppi_replace);
	if zero = 0 then  ppi_replace (i)  = bea_replace (i) ;
	end;


	Link_1987=PPIs_&indy._1987/BEA_Deflator1987;
		do i=1 to dim(deflator);
		Bea_Deflator_Linked {i} = BEA_Deflator {i} * link_1987;
		end;
	/*assigning 1947-1986 BEA deflators*/
		do i=1 to 40;
		deflator {i}= BEA_Deflator_Linked {i};
		end;
	/*Assinging PPIs for 1987-forward*/
		do i= 41 to dim(deflator);
		deflator {i} = ppi {i};
	    end;
	/*Using BEA deflator for all years for asset 7 software*/
		do i=1 to dim(bea_deflator);
		if aces_asset=7 then deflator {i} = BEA_Deflator {i};
		end;
keep aces_asset deflator:;
run;
%end;
%mend loop;
%loop;

/*Merging the BEA deflator and PPI deflator datasets*/
%macro loop2 (indy = );
/*First, replace the PPI for asset 5 with CapDefAsset5 */
data work.deflator&indy;
merge deflator.ppi_&indy deflator.capdefasset5;
by aces_asset;
array ppi {*} PPIs_&indy._1987-PPIs_&indy._&last;
array asset_5 {*} Year1987-Year&last;
	do i=1 to dim(ppi);
	if aces_asset=5 then ppi {i} = asset_5 {i};
	end;
run;

data work.deflator&indy;
merge work.aces_pri work.deflator&indy;
by aces_asset;

	array bea_deflator_linked {*} BEA_Deflator_Linked1947-BEA_Deflator_Linked&last;
	array bea_deflator {*} BEA_Deflator1947-BEA_Deflator&last;
	array deflator {*} deflator_1947-deflator_&last;
	array ppi {*} PPIs_&indy._1947-PPIs_&indy._&last;
	array ppi_replace {*} PPIs_&indy._1987-PPIs_&indy._&last;
	array bea_replace {*} BEA_Deflator1987-BEA_Deflator&last;

	/*Creating a variable to see if the sum of PPI deflators across years 1987-forward for any asset equals zero*/
	Zero = sum (of PPIs_&indy._:);

	/*Replacing PPI deflators that are zero for all years with BEA Deflators*/
	do i=1 to dim(ppi_replace);
	if zero = 0 then  ppi_replace (i)  = bea_replace (i) ;
	end;

	Link_1987=PPIs_&indy._1987/BEA_Deflator1987;
		do i=1 to dim(deflator);
		Bea_Deflator_Linked {i} = BEA_Deflator {i} * link_1987;
		end;
	/*assigning 1947-1986 BEA deflators*/
		do i=1 to 40;
		deflator {i}= BEA_Deflator_Linked {i};
		end;
	/*Assinging PPIs for 1987-forward*/
		do i= 41 to dim(deflator);
		deflator {i} = ppi {i};
	    end;
	/*Using BEA deflator for all years for asset 7 software*/
		do i=1 to dim(bea_deflator);
		if aces_asset=7 then deflator {i} = BEA_Deflator {i};
		end;
keep aces_asset deflator:;
run;
%mend loop2;
%loop2;
%loop2 (indy=331A);
%loop2 (indy=331B);
%loop2 (indy=332A);
%loop2 (indy=332B);
%loop2 (indy=334A);
%loop2 (indy=336A);
%loop2 (indy=336B);


/*Assigning CFT Industry Deflators to their ASM Industry counterparts*/
data work.deflator3111 work.deflator3112 work.deflator3113 work.deflator3114 work.deflator3115 work.deflator3116
	 work.deflator3117 work.deflator3118 work.deflator3119;
set work.deflator3110; 
run;
data work.deflator3131 work.deflator3132 work.deflator3133;
set work.deflator3130;
run;
data work.deflator3141 work.deflator3149;
set work.deflator3140;
run;
data work.deflator3151 work.deflator3152 work.deflator3159;
set work.deflator3150;
run;
data work.deflator3161 work.deflator3162 work.deflator3169;
set work.deflator3160;
run;
data work.deflator3211 work.deflator3212 work.deflator3219;
set work.deflator3210;
run;
data work.deflator3231;
set work.deflator3230;
data work.deflator3241;
set work.deflator3240;
data work.deflator3261 work.deflator3262;
set work.deflator3260;
run;
data work.deflator3271 work.deflator3272 work.deflator3273 work.deflator3274 work.deflator3279;
set work.deflator3270;
run;
data work.deflator3311 work.deflator3312;
set work.deflator331A;
run;
data work.deflator3313 work.deflator3314;
set work.deflator331B;
run;
data work.deflator3325 work.deflator3326 work.deflator3327 work.deflator3328 work.deflator3329;
set work.deflator332B;
run;
data work.deflator3329;
set work.deflator332A;
run;
data work.deflator3342 work.deflator3343;
set work.deflator334A;
run;
data work.deflator3362 work.deflator3363;
set work.deflator336A;
data work.deflator3365 work.deflator3366 work.deflator3369;
set work.deflator336B;
data work.deflator3371 work.deflator3372 work.deflator3379;
set work.deflator3370;
run;

 proc copy in= work
			out= deflator;
			select  deflator3111	deflator3112	deflator3113	deflator3114	deflator3115	deflator3116	
			deflator3117	deflator3118	deflator3119	deflator3121	deflator3122	deflator3131	deflator3132	
			deflator3133	deflator3141	deflator3149	deflator3151	deflator3152	deflator3159	deflator3161	
			deflator3162	deflator3169	deflator3211	deflator3212	deflator3219	deflator3221	deflator3222	
			deflator3231	deflator3241	deflator3251	deflator3252	deflator3253	deflator3254	deflator3255	
			deflator3256	deflator3259	deflator3261	deflator3262	deflator3271	deflator3272	deflator3273	
			deflator3274	deflator3279	deflator3311	deflator3312	deflator3313	deflator3314	deflator3315	
			deflator3321	deflator3322	deflator3323	deflator3324	deflator3325	deflator3326	deflator3327	
			deflator3328	deflator3329	deflator3331	deflator3332	deflator3333	deflator3334	deflator3335	
			deflator3336	deflator3339	deflator3341	deflator3342	deflator3343	deflator3344	deflator3345	
			deflator3346	deflator3351	deflator3352	deflator3353	deflator3359	deflator3361	deflator3362	
			deflator3363	deflator3364	deflator3365	deflator3366	deflator3369	deflator3371	deflator3372	
			deflator3379	deflator3391	deflator3399;
run;

/******************Deflating Nominal Capital Expenditures*********************************/

/*Tranpose nominal investment so that years are columns and assets are rows*/
%macro loop;
%do indy=3111 %to 3399;
proc transpose data=capital.capexn&indy out=work.capexn&indy;
run;
data work.capexn&indy;
set work.capexn&indy;
aces_asset=substr(_name_,7)*1;
array years {*} capexp1958-capexp&last;
array columns {*} col:;
	do i=1 to dim(years);
	years {i} = columns {i};
	end;
drop col: i _name_;
run;

data work.Real_Investment_&indy;
merge work.capexn&indy deflator.deflator&indy;
by aces_asset;
/*replacing missing deflator values with a value of 1*/
array deflator {*} deflator_1958-deflator_&last;
	do i=1 to dim(deflator);
	if deflator {i} = . then deflator {i} = 1;
	if deflator {i} = 0 then deflator {i} = 1;
	end;

/*Calculating Real Investment*/
array nominal_investment {*} capexp1958-capexp&last;
array real_investment {*} real_investment1958-real_investment&last;
	do i=1 to dim(nominal_investment);
	real_investment {i} = nominal_investment {i} / deflator {i};
	end;
keep aces_asset real_investment:;
run;
%end;
%mend loop;
%loop;

 proc copy in= work
			out= capital;
			select  real_investment_3111	real_investment_3112	real_investment_3113	real_investment_3114	real_investment_3115	real_investment_3116	
			real_investment_3117	real_investment_3118	real_investment_3119	real_investment_3121	real_investment_3122	real_investment_3131	real_investment_3132	
			real_investment_3133	real_investment_3141	real_investment_3149	real_investment_3151	real_investment_3152	real_investment_3159	real_investment_3161	
			real_investment_3162	real_investment_3169	real_investment_3211	real_investment_3212	real_investment_3219	real_investment_3221	real_investment_3222	
			real_investment_3231	real_investment_3241	real_investment_3251	real_investment_3252	real_investment_3253	real_investment_3254	real_investment_3255	
			real_investment_3256	real_investment_3259	real_investment_3261	real_investment_3262	real_investment_3271	real_investment_3272	real_investment_3273	
			real_investment_3274	real_investment_3279	real_investment_3311	real_investment_3312	real_investment_3313	real_investment_3314	real_investment_3315	
			real_investment_3321	real_investment_3322	real_investment_3323	real_investment_3324	real_investment_3325	real_investment_3326	real_investment_3327	
			real_investment_3328	real_investment_3329	real_investment_3331	real_investment_3332	real_investment_3333	real_investment_3334	real_investment_3335	
			real_investment_3336	real_investment_3339	real_investment_3341	real_investment_3342	real_investment_3343	real_investment_3344	real_investment_3345	
			real_investment_3346	real_investment_3351	real_investment_3352	real_investment_3353	real_investment_3359	real_investment_3361	real_investment_3362	
			real_investment_3363	real_investment_3364	real_investment_3365	real_investment_3366	real_investment_3369	real_investment_3371	real_investment_3372	
			real_investment_3379	real_investment_3391	real_investment_3399;
run;

/*******************************Deflating Struture investment********************************/
data work.structure_pri;
set beadfnew.aces_pri;
drop equip: softrat;
run;
proc transpose data=work.structure_pri out=work.structure_pri ;
id year;
run; 
/*Replace missing values*/
data work.structure_pri ;
set work.structure_pri;
array forward {*} _1901-_&last;
do i= 2 to dim(forward);
	if forward {i} = . then forward {i} = forward {i-1};
end;
drop i;
run;
proc sort data=work.structure_pri;
by _name-;
run;
proc transpose data=work.structure_pri out=beadfnew.structure_pri (drop=_name_) ;
run; 

/*Deflating nominal structure investment*/
%macro loop;
%do indy=3111 %to 3399;
data work.capexnstr&indy;
set capital.capexnstr&indy (rename=(year=year2));
year=year2;
if substr(year2,1,1)="c" then year=substr(year,6);
drop year2;
run;
data work.real_investment_struct&indy;
merge beadfnew.structure_pri work.capexnstr&indy;

array deflator {*} struct_pri:;
array investment {*} capexpstr:;
array real {*} real_investment1-real_investment10;
	do i=1 to dim(deflator);
	real {i}= investment {i} / deflator {i};
	end;
keep year real_investment:;
run;
%end;
%mend loop;
%loop;
proc copy in= work
			out= capital;
			select  real_investment_struct3111	real_investment_struct3112	real_investment_struct3113	real_investment_struct3114	real_investment_struct3115	real_investment_struct3116	
			real_investment_struct3117	real_investment_struct3118	real_investment_struct3119	real_investment_struct3121	real_investment_struct3122	real_investment_struct3131	real_investment_struct3132	
			real_investment_struct3133	real_investment_struct3141	real_investment_struct3149	real_investment_struct3151	real_investment_struct3152	real_investment_struct3159	real_investment_struct3161	
			real_investment_struct3162	real_investment_struct3169	real_investment_struct3211	real_investment_struct3212	real_investment_struct3219	real_investment_struct3221	real_investment_struct3222	
			real_investment_struct3231	real_investment_struct3241	real_investment_struct3251	real_investment_struct3252	real_investment_struct3253	real_investment_struct3254	real_investment_struct3255	
			real_investment_struct3256	real_investment_struct3259	real_investment_struct3261	real_investment_struct3262	real_investment_struct3271	real_investment_struct3272	real_investment_struct3273	
			real_investment_struct3274	real_investment_struct3279	real_investment_struct3311	real_investment_struct3312	real_investment_struct3313	real_investment_struct3314	real_investment_struct3315	
			real_investment_struct3321	real_investment_struct3322	real_investment_struct3323	real_investment_struct3324	real_investment_struct3325	real_investment_struct3326	real_investment_struct3327	
			real_investment_struct3328	real_investment_struct3329	real_investment_struct3331	real_investment_struct3332	real_investment_struct3333	real_investment_struct3334	real_investment_struct3335	
			real_investment_struct3336	real_investment_struct3339	real_investment_struct3341	real_investment_struct3342	real_investment_struct3343	real_investment_struct3344	real_investment_struct3345	
			real_investment_struct3346	real_investment_struct3351	real_investment_struct3352	real_investment_struct3353	real_investment_struct3359	real_investment_struct3361	real_investment_struct3362	
			real_investment_struct3363	real_investment_struct3364	real_investment_struct3365	real_investment_struct3366	real_investment_struct3369	real_investment_struct3371	real_investment_struct3372	
			real_investment_struct3379	real_investment_struct3391	real_investment_struct3399;
run;
