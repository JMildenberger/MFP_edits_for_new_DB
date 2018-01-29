/*Allows SEG to replace variable names with spaces from Excel files with an underscore*/
options validvarname=v7;
options nosyntaxcheck;

/**********************************************************************************************************************
*   Last change: June 21, 2017 by CG to sort sptool.special_tools by year                                             *
*																					                                  *
**********************************************************************************************************************/	

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

/*Creating a macro variable for the update year*/
 data _null_;
      length dataset $29;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input dataset firstyr lastyr baseperiod;
      call symput('last', trim(left(put(lastyr, 4.))));
run;
 %put &last;
 
/*Investment in Asset 1 is always zero so DMSP does not provide that data. The following code creates an Asset 1
  dataset and set all values to zero*/

 data capital.Ia1;
 set capital.Ia2;
 Constant=0;
 run;

/****************Summing BEA Constant Dollar Investment by asset across industries for all years **************/

/*BEA industry 70 is a duplicate of 20+21 and 71 is a duplicate of 18+19. 70 and 71 are renamed to match up with 
  BEA deflators 20 and 18 from the Btot file*/
%macro rename;
%do asset=1 %to 95;
data work.IA&asset;
set capital.ia&asset;
Constant_Asset&asset=constant;
If industry= 19 then delete;
If industry= 21 then delete;
If industry= 18 then delete;
If industry= 20 then delete;
If industry= 70 then industry= 20;
If industry= 71 then industry= 18;
if industry > 28 then delete;
drop constant;
run;

proc sort data=work.ia&asset;
by industry;
run;

%end;
%mend rename;
%rename;

%macro combined;
data work.BEA_Investment;
merge 
	%do asset=1 %to 95;
	work.Ia&asset
	%end;
;
by  industry;
run;
%mend combined;
%combined;

proc sort data=work.bea_investment;
by year;
run;
proc means data=work.BEA_Investment n sum noprint;
by year;
output out=capital.Bea_Investment_Asset_Totals Sum (constant:) = constant_Asset1-constant_asset95;
run;
/*Replacing missing data with zeros*/
data capital.Bea_Investment_Asset_Totals;
set capital.Bea_Investment_Asset_Totals;
%macro loop;
%do asset=1 %to 95;
if constant_asset&asset = . then constant_asset&asset = 0;
%end;
%mend loop;
%loop;
run;

/******Rebasing the BEA deflators to 1997=1****************/
proc transpose data=deflator.btot out=work.btot_t (rename=(_name_=Asset) drop=_label_);
id year;
run;

data work.btot_t;
set work.btot_t;
%macro rebase;
%do year=1901 %to &last;
	Rebased_&year= _&year/_1997;
%end;
%mend rebase;
%rebase;
keep asset rebased:;
run;

proc transpose data=work.btot_t out=deflator.btot_rebased;
id asset;
run;
data deflator.btot_rebased;
set deflator.btot_rebased;
Year=substr(_name_,9)*1;
drop _name_;
run;

/**********************Calculating Total Asset across industries Nominal Investment******************/
data work.nominal_Total_Asset_invest;
retain year;
merge deflator.btot_rebased 
      capital.Bea_Investment_Asset_Totals;
by year;
%macro current;
%do asset=1 %to 95;
	current_investment&asset= PA&asset * Constant_Asset&asset;
	if current_investment&asset = . then current_investment&asset = 0;
%end;
%mend current;
%current;
keep year current:;
run;

/*************Calculating asset/indy nominal investment****************/
%macro all;
%do asset=1 %to 95;
proc sort data=work.ia&asset;
by year;
run;

data work.Current_BEA&asset;
merge work.ia&asset
      deflator.btot_rebased;
by year;
Current_Asset&asset=Constant_Asset&asset * PA&asset;
Keep year industry constant_Asset&asset current_Asset&asset PA&asset;
run;
%end;
%mend All;
%all;

proc sort data=sptools.Special_Tools;
by year;
run;

/*Removing special tools from Asset 11, Industry 15*/
data work.Current_BEA11;
merge work.Current_BEA11
      sptools.Special_Tools;
by year;
If Year < 1972 then nomspt=0;
if industry=15 then current_asset11=current_asset11 - nomspt;
drop nomspt defspt realspt;
run;


/******************Adjusting BEA equipment investment for software and ASM asset categories*********************/
%macro combined;
data work.BEA_Equip_Invest_Adjust;
merge 
	%do asset=1 %to 42;
	work.Current_BEA&asset
	%end;
;
by  year industry;
drop constant: pa:;
run;
%mend combined;
%combined;

data work.softrat_all_Indys;
set work.BEA_Equip_Invest_Adjust;
total_NoSoft_Invest=sum (of current_Asset1-Current_Asset39);
Software_Invest= sum( of current_Asset40-current_Asset42);
Software_Ratio= Software_Invest / total_NoSoft_Invest;
total_NoSoft_Invest_ASM = sum (of current_Asset1-Current_Asset31)- Current_Asset20- Current_Asset21- Current_Asset22;
Software_Ratio_ASM=Software_Invest/total_NoSoft_Invest_ASM;
If year <=2001 then SoftRat_All=Software_Ratio;
If year > 2001 then SoftRat_All=Software_Ratio_ASM;
/*keep year industry SoftRat_All;*/
run;

/*Remove special tools from total asset current and constant investment*/
data work.nominal_total_asset_invest;
merge work.nominal_total_asset_invest
      sptools.special_tools;
by year;
current_investment11= current_investment11 - nomspt;
Total_Equip_Nom_Asset_Invest=sum (of current_investment1-current_investment42);
Software_Nom= sum (of current_investment40-current_investment42);
Equip_no_soft= Total_Equip_Nom_Asset_Invest - Software_Nom;
SoftRat_1= Software_Nom/Total_Equip_Nom_Asset_Invest;
Equip_no_soft_ASM = Equip_no_soft - current_investment20 - current_investment21 - current_investment22 -
                    current_investment32;
SoftRat_2= Software_Nom / Equip_no_soft_ASM;
If year <=2001 then SoftRat= SoftRat_1;
if year > 2001 then SoftRat= SoftRat_2;
Total_Struct_Nom_Asset_Invest= current_investment43 + current_investment44 + current_investment45 + current_investment46 + 
			current_investment51 +
			current_investment54 + current_investment55 + current_investment57 + current_investment59 + current_investment60
			+ current_investment63 +
			current_investment87 + current_investment88 + current_investment89 + current_investment90 + current_investment95;
run;

data work.Total_Asset_SoftRat;
set work.nominal_total_asset_invest;
keep year softrat;
run;
data invest.Total_Asset_SoftRat;
set work.softrat_all_Indys;
keep year industry softrat_all;
run;

/*Creating a data set for each BEA industry with its software ratio*/
%macro loop;
%do indy=8 %to 28;
data invest.softrat_all_i&indy;
set invest.total_asset_softrat (where=(Industry=&indy));
run;
%end;
%mend loop;
%loop;

data invest.BeaInv;
set work.nominal_total_asset_invest;
keep year Total_Equip_Nom_Asset_Invest Total_Struct_Nom_Asset_Invest;
run;

data work.constant_total_asset_invest;
merge capital.Bea_Investment_Asset_Totals
      sptools.special_tools;
by year;
constant_asset11= constant_asset11 - realspt;
run;


data work.ACES_Nom_Invest;
set work.nominal_total_asset_invest;

/*Equipment*/
aces_ecuri1 = current_investment32 + current_investment33 + current_investment34 + current_investment35 + 
              current_investment36 + current_investment37 + current_investment38 + current_investment39;
aces_ecuri2 = current_investment14 + current_investment26;
aces_ecuri3 = current_investment16;
aces_ecuri4 = current_investment29;
aces_ecuri5 = current_investment28;
aces_ecuri6 = current_investment27;
aces_ecuri7 = current_investment40 +current_investment41 + current_investment42;
aces_ecuri8 = current_investment3;
aces_ecuri9 = current_investment11;
aces_ecuri10= current_investment12;
aces_ecuri11= current_investment13;
aces_ecuri12= current_investment20 + current_investment22;
aces_ecuri13= current_investment21;
aces_ecuri14= current_investment23;
aces_ecuri15= current_investment24 + current_investment25;
aces_ecuri16= current_investment4 + current_investment5;
aces_ecuri17= current_investment17;
aces_ecuri18= current_investment18 + current_investment19;
aces_ecuri19= current_investment10;
aces_ecuri20= current_investment1 + current_investment2;
aces_ecuri21= current_investment6 + current_investment8;
aces_ecuri22= current_investment7 + current_investment9;
aces_ecuri23= current_investment15;
aces_ecuri24= current_investment30;
/*Structures*/
aces_scuri1 = current_investment43;
aces_scuri2 = current_investment44;
aces_scuri3 = current_investment46;
aces_scuri4 = current_investment45;
aces_scuri5 = current_investment51 + current_investment87 + current_investment88;
aces_scuri6 = current_investment54 + current_investment63;
aces_scuri7 = current_investment57 + current_investment55;
aces_scuri8 = current_investment89 + current_investment90;
aces_scuri9 = current_investment59 + current_investment60;
aces_scuri10 = current_investment95;
keep year aces:;
run;

data work.ACES_Constant_Invest;
set work.constant_total_asset_invest;
/*Equipment*/
aces_econi1 = constant_asset32 + constant_asset33 + constant_asset34 + constant_asset35 + 
              constant_asset36 + constant_asset37 + constant_asset38 + constant_asset39;
aces_econi2 = constant_asset14 + constant_asset26;
aces_econi3 = constant_asset16;
aces_econi4 = constant_asset29;
aces_econi5 = constant_asset28;
aces_econi6 = constant_asset27;
aces_econi7 = constant_asset40 +constant_asset41 + constant_asset42;
aces_econi8 = constant_asset3;
aces_econi9 = constant_asset11;
aces_econi10= constant_asset12;
aces_econi11= constant_asset13;
aces_econi12= constant_asset20 + constant_asset22;
aces_econi13= constant_asset21;
aces_econi14= constant_asset23;
aces_econi15= constant_asset24 + constant_asset25;
aces_econi16= constant_asset4 + constant_asset5;
aces_econi17= constant_asset17;
aces_econi18= constant_asset18 + constant_asset19;
aces_econi19= constant_asset10;
aces_econi20= constant_asset1 + constant_asset2;
aces_econi21= constant_asset6 + constant_asset8;
aces_econi22= constant_asset7 + constant_asset9;
aces_econi23= constant_asset15;
aces_econi24= constant_asset30;
/*Structures*/
aces_sconi1 = constant_asset43;
aces_sconi2 = constant_asset44;
aces_sconi3 = constant_asset46;
aces_sconi4 = constant_asset45;
aces_sconi5 = constant_asset51 + constant_asset87 + constant_asset88;
aces_sconi6 = constant_asset54 + constant_asset63;
aces_sconi7 = constant_asset57 + constant_asset55;
aces_sconi8 = constant_asset89 + constant_asset90;
aces_sconi9 = constant_asset59 + constant_asset60;
aces_sconi10 = constant_asset95;
keep year aces:;
run;

/*Calculate asset deflators for 1901-forward*/
data work.asset_deflators;
merge work.aces_constant_invest
      work.ACES_Nom_Invest;
by year;
/*structures deflators*/
struct_pri1=aces_scuri1/aces_sconi1;
struct_pri2=aces_scuri2/aces_sconi2;
struct_pri3=aces_scuri3/aces_sconi3;
struct_pri4=aces_scuri4/aces_sconi4;
struct_pri5=aces_scuri5/aces_sconi5;
struct_pri6=aces_scuri6/aces_sconi6;
struct_pri7=aces_scuri7/aces_sconi7;
struct_pri8=aces_scuri8/aces_sconi8;
struct_pri9=aces_scuri9/aces_sconi9;
struct_pri10=aces_scuri10/aces_sconi10;

/*asset deflators*/
equip_pri1 = aces_ecuri1/aces_econi1;
equip_pri2 = aces_ecuri2/aces_econi2;
equip_pri3 = aces_ecuri3/aces_econi3;
equip_pri4 = aces_ecuri4/aces_econi4;
equip_pri5 = aces_ecuri5/aces_econi5;
equip_pri6 = aces_ecuri6/aces_econi6;
equip_pri7 = aces_ecuri7/aces_econi7;
equip_pri8 = aces_ecuri8/aces_econi8;
equip_pri9 = aces_ecuri9/aces_econi9;
equip_pri10 = aces_ecuri10/aces_econi10;
equip_pri11 = aces_ecuri11/aces_econi11;
equip_pri12 = aces_ecuri12/aces_econi12;
equip_pri13 = aces_ecuri13/aces_econi13;
equip_pri14 = aces_ecuri14/aces_econi14;
equip_pri15 = aces_ecuri15/aces_econi15;
equip_pri16 = aces_ecuri16/aces_econi16;
equip_pri17 = aces_ecuri17/aces_econi17;
equip_pri18 = aces_ecuri18/aces_econi18;
equip_pri19 = aces_ecuri19/aces_econi19;
equip_pri20 = aces_ecuri20/aces_econi20;
equip_pri21 = aces_ecuri21/aces_econi21;
equip_pri22 = aces_ecuri22/aces_econi22;
equip_pri23 = aces_ecuri23/aces_econi23;
equip_pri24 = aces_ecuri24/aces_econi24;
keep equip_pri: struct_pri:;
run;

data beadfnew.aces_pri;
retain year;
merge work.asset_deflators
      work.total_asset_softrat;
run;

/******transposing current dollar asset totals so that years are columns. these will be used in step 5 for the RAS 
       procedure                                                                                                  *******/

Proc transpose data=work.aces_nom_invest out=work.aces_nom_invest_t;
id year;
run;

data ras.cdey;
set work.aces_nom_invest_t;
if substr(_name_,6,1)="s" then delete;
drop _1901-_1946;
run;
data ras.cdsy;
set work.aces_nom_invest_t;
if substr(_name_,6,1)="e" then delete;
run;
