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
libname stock 'Q:\MFP\SAS Libraries\Manufacturing\Capital\stock';
libname final 'Q:\MFP\SAS Libraries\Manufacturing\Capital\final';
libname exports 'Q:\MFP\SAS Libraries\Manufacturing\Capital\exports';
libname IP 'Q:\MFP\SAS Libraries\Manufacturing\IP';


/*Adding all equipment categories to get total equipment for 2002-forward*/
Data work.NewCapexp_Equip_Total;
set capital.newcapexp;
Equipment= Total - Structures;
Keep NAICS Year Equipment Structures;
run;

/*Truncating the 1958-&last data set to be from 1958-2001*/
data work.naicscapexp;
set capital.naicscapexp (where=(year<2002));
drop total;
run;

/*Creating and 1958-&last data set with total equipment and structure investment*/
data work.naicscap_all_years;
set work.naicscapexp
    work.NewCapexp_Equip_Total;
run;

proc sort data=work.naicscap_all_years;
by year naics;
run;

/*Putting equipment investment on a CFT and ACES industry basis*/

proc transpose data=work.naicscap_all_years out=work.equipment;
by year;
id naics;
var equipment;
run;

data work.CFT_equipment;
set work.equipment;
xime15= _3111 + _3112 + _3113 + _3114 + _3115 + _3116 + _3117 + _3118 + _3119;
xime16 = _3121;
xime17 = _3122;
xime18 = _3131 + _3132 + _3133;
xime19 = _3141 + _3149;
xime20 = _3151 + _3152 + _3159;
xime21 = _3161 + _3162 + _3169;
xime22 = _3211 + _3212 + _3219;
xime23 = _3221;
xime24 = _3222;
xime25 = _3231;
xime26 = _3241;
xime27 = _3251;
xime28 = _3252;
xime29 = _3253;
xime30 = _3254;
xime31 = _3255;
xime32 = _3256;
xime33 = _3259;
xime34 = _3261 + _3262;
xime35 = _3271 + _3272 + _3273 + _3274 + _3279;
xime36 = _3311 + _3312;
xime37 = _3313 + _3314;
xime38 = _3315;
xime39 = _3321;
xime40 = _3322;
xime41 = _3323;
xime42 = _3324;
xime43 = _3325 + _3326 + _3327 + _3328 + _3329;
xime44 = 0; /*industry 44 is a vector of zeros for equipment - other fabricated metal
product manufacturing*/
xime45 = _3331;
xime46 = _3332;
xime47 = _3333;
xime48 = _3334;
xime49 = _3335;
xime50 = _3336;
xime51 = _3339;
xime52 = _3341;
xime53 = _3342 + _3343;
xime54 = _3344;
xime55 = _3345;
xime56 = _3346;
xime57 = _3351;
xime58 = _3352;
xime59 = _3353;
xime60 = _3359;
xime61 = _3361;
xime62 = _3362 +  _3363;
xime63 = _3364;
xime64 = _3365 + _3366 + _3369;
xime65 = _3371 + _3372 + _3379;
xime66 = _3391;
xime67 = _3399;
run;

data work.ACES_Equipment;
set work.equipment;
ACES_xime1 =  _3111 + _3112 + _3113 + _3114 + _3115 + _3116 + _3117 + _3118 + _3119;
ACES_xime2 =  _3121;
ACES_xime3 =  _3122;
ACES_xime4 =  _3131 + _3132 + _3133 + _3141 + _3149;
ACES_xime5 =  _3151 + _3152 + _3159;
ACES_xime6 =  _3161 + _3162 + _3169;
ACES_xime7 =  _3211 + _3212 + _3219;
ACES_xime8 =  _3221 + _3222;
ACES_xime9 =  _3231;
ACES_xime10 = _3241;
ACES_xime11 = _3251 + _3252;
ACES_xime12 = _3253;
ACES_xime13 = _3254;
ACES_xime14 = _3255 + _3256 + _3259;
ACES_xime15 = _3261 + _3262;
ACES_xime16 = _3271 + _3272;
ACES_xime17 = _3273 + _3274 + _3279;
ACES_xime18 = _3311 + _3312;
ACES_xime19 = _3313 + _3314;
ACES_xime20 = _3315;
ACES_xime21 = _3321 + _3322 + _3323 + _3324 + _3325 + _3326 + _3327 + _3328 + _3329;
ACES_xime22 = _3331;
ACES_xime23 = _3332 + _3335 + _3339;
ACES_xime24 = _3333 + _3334;
ACES_xime25 = _3336;
ACES_xime26 = _3341;
ACES_xime27 = _3342 + _3343;
ACES_xime28 = _3344;
ACES_xime29 = _3345;
ACES_xime30 = _3346;
ACES_xime31 = _3351 + _3352 + _3353 + _3359;
ACES_xime32 = _3361 + _3362 + _3363;
ACES_xime33 = _3364;
ACES_xime34 = _3365 + _3366 + _3369;
ACES_xime35 = _3371 + _3372 + _3379;
ACES_xime36 = _3391;
ACES_xime37 = _3399;
run;

/*Putting structures investment on a CFT and ACES industry basis*/

proc transpose data=work.naicscap_all_years out=work.structures;
by year;
id naics;
var structures;
run;

data work.CFT_structures;
set work.structures;
xims15= _3111 + _3112 + _3113 + _3114 + _3115 + _3116 + _3117 + _3118 + _3119;
xims16 = _3121;
xims17 = _3122;
xims18 = _3131 + _3132 + _3133;
xims19 = _3141 + _3149;
xims20 = _3151 + _3152 + _3159;
xims21 = _3161 + _3162 + _3169;
xims22 = _3211 + _3212 + _3219;
xims23 = _3221;
xims24 = _3222;
xims25 = _3231;
xims26 = _3241;
xims27 = _3251;
xims28 = _3252;
xims29 = _3253;
xims30 = _3254;
xims31 = _3255;
xims32 = _3256;
xims33 = _3259;
xims34 = _3261 + _3262;
xims35 = _3271 + _3272 + _3273 + _3274 + _3279;
xims36 = _3311 + _3312;
xims37 = _3313 + _3314;
xims38 = _3315;
xims39 = _3321;
xims40 = _3322;
xims41 = _3323;
xims42 = _3324;
xims43 = _3325 + _3326 + _3327 + _3328 + _3329;
xims44 = 0; /*industry 44 is a vector of zeros for structures - other fabricated metal
product manufacturing*/
xims45 = _3331;
xims46 = _3332;
xims47 = _3333;
xims48 = _3334;
xims49 = _3335;
xims50 = _3336;
xims51 = _3339;
xims52 = _3341;
xims53 = _3342 + _3343;
xims54 = _3344;
xims55 = _3345;
xims56 = _3346;
xims57 = _3351;
xims58 = _3352;
xims59 = _3353;
xims60 = _3359;
xims61 = _3361;
xims62 = _3362 +  _3363;
xims63 = _3364;
xims64 = _3365 + _3366 + _3369;
xims65 = _3371 + _3372 + _3379;
xims66 = _3391;
xims67 = _3399;
run;

data work.ACES_structures;
set work.structures;
ACES_xims1 =  _3111 + _3112 + _3113 + _3114 + _3115 + _3116 + _3117 + _3118 + _3119;
ACES_xims2 =  _3121;
ACES_xims3 =  _3122;
ACES_xims4 =  _3131 + _3132 + _3133 + _3141 + _3149;
ACES_xims5 =  _3151 + _3152 + _3159;
ACES_xims6 =  _3161 + _3162 + _3169;
ACES_xims7 =  _3211 + _3212 + _3219;
ACES_xims8 =  _3221 + _3222;
ACES_xims9 =  _3231;
ACES_xims10 = _3241;
ACES_xims11 = _3251 + _3252;
ACES_xims12 = _3253;
ACES_xims13 = _3254;
ACES_xims14 = _3255 + _3256 + _3259;
ACES_xims15 = _3261 + _3262;
ACES_xims16 = _3271 + _3272;
ACES_xims17 = _3273 + _3274 + _3279;
ACES_xims18 = _3311 + _3312;
ACES_xims19 = _3313 + _3314;
ACES_xims20 = _3315;
ACES_xims21 = _3321 + _3322 + _3323 + _3324 + _3325 + _3326 + _3327 + _3328 + _3329;
ACES_xims22 = _3331;
ACES_xims23 = _3332 + _3335 + _3339;
ACES_xims24 = _3333 + _3334;
ACES_xims25 = _3336;
ACES_xims26 = _3341;
ACES_xims27 = _3342 + _3343;
ACES_xims28 = _3344;
ACES_xims29 = _3345;
ACES_xims30 = _3346;
ACES_xims31 = _3351 + _3352 + _3353 + _3359;
ACES_xims32 = _3361 + _3362 + _3363;
ACES_xims33 = _3364;
ACES_xims34 = _3365 + _3366 + _3369;
ACES_xims35 = _3371 + _3372 + _3379;
ACES_xims36 = _3391;
ACES_xims37 = _3399;
run;

/*Remove Special Tools from Total Equipment Investment for CFT Indy 61 and 62
  Sum equipment across industries
  Calculate industry proportions
  Use proportions to break out total asset investment from BEA*/
data work.cft_equipment2;
merge work.cft_equipment 
      sptools.special_tools (where=(year>1957))
      invest.beainv (where=(year>1957));
by year;
If year<1972 then nomspt=0;
sptools61_sptools62= Xime61 + Xime62;
Prop61 = Xime61/sptools61_sptools62;
Prop62 = 1-prop61;
Xime61 = Xime61 - (Nomspt * Prop61);
Xime62 = Xime62 - (Nomspt * Prop62);
CFT_Total_Equipment = sum (of xi:);
%macro loop;
	%do indy=15 %to 67;
	proportion_&indy = XIME&indy / CFT_Total_Equipment;
	BIME&Indy = Proportion_&Indy * Total_Equip_Nom_Asset_Invest;
%end;
%mend loop;
%loop;
run;

/*Remove Special Tools from ACES industry 32
  Sum investment across industries
  Calculate industry proportions
  Use proportions to break out total asset investment from BEA*/
Data work.Aces_Equipment2;
set work.Aces_Equipment;
merge work.Aces_Equipment 
      sptools.special_tools (where=(year>1957))
	  invest.beainv (where=(year>1957));
by year;
If year<1972 then nomspt=0;
Aces_Xime32 = ACES_Xime32 - nomspt;
ACES_Total_Equipment = sum (of ACES_Xi:);
%macro loop;
	%do indy=1 %to 37;
	proportion_&indy = ACES_XIME&indy / ACES_Total_Equipment;
	ACES_BIME&Indy = Proportion_&Indy * Total_Equip_Nom_Asset_Invest;
%end;
%mend loop;
%loop;
run;

/*Sum structure investment across industries
  Sum investment across industries
  Calculate industry proportions
  Use proportions to break out total asset investment from BEA*/
data work.cft_structures2;
merge work.cft_structures
	  invest.beainv (where=(year>1957));
CFT_Total_Structures = sum (of xi:);
%macro loop;
	%do indy=15 %to 67;
	proportion_&indy = XIMS&indy / CFT_Total_Structures;
	BEA_Investment&Indy = Proportion_&Indy * Total_Struct_Nom_Asset_Invest;
%end;
%mend loop;
%loop;
run;
data work.aces_structures2;
merge work.aces_structures
      invest.beainv (where=(year>1957));
ACES_Total_Structures = sum (of ACES_xi:);
%macro loop;
	%do indy=1 %to 37;
	proportion_&indy = ACES_XIMS&indy / ACES_Total_Structures;
	ACES_BIMS&Indy = Proportion_&Indy * Total_Struct_Nom_Asset_Invest;
%end;
%mend loop;
%loop;
run;

/*writing out final nominal BEA investment data to RAS library*/
data ras.bime;
set work.cft_equipment2;
keep bime:;
run;

data ras.aces_bime;
set work.aces_equipment2;
keep aces_bime:;
run;

data ras.aces_bims;
set work.aces_structures2;
keep aces_bims:;
run;
