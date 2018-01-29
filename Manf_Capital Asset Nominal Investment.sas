/*Detailed Asset Investment Program, Step 7a of Manf Capital
  Created by - Corby Garner
  Last Modified - 1/4/2016; program changed to make all NAICS variables text*/
*/

/*Allows SEG to replace variable names with spaces from Excel files with an underscore*/
options validvarname=v7;

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

options errors=0 nosymbolgen;

/*Creating a macro variable for the update year*/
 data _null_;
      length updateid 3 firstyr 4 lastyr 4 baseperiod 3;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input updateid firstyr lastyr baseperiod;
      call symput('last', trim(left(put(lastyr, 4.))));
run;
 %put &last;
/*Creating macro variables for the names of NAICS Industries*/
data _null_;
set capital.indys nobs=x;
      call symputx ("NAICS_Indy"!!left(_n_),NAICS);
 run;

/*Putting the 2008 ACES industry proportions on a NAICS basis*/
%macro loop;
%do year= 1958 %to &last;
data work.aces_2008_rme&year;
set ras.aces_2008_rme&year;
aces_2008_props3111_&year	=	col1;
aces_2008_props3112_&year	=	col1;
aces_2008_props3113_&year	=	col1;
aces_2008_props3114_&year	=	col1;
aces_2008_props3115_&year	=	col1;
aces_2008_props3116_&year	=	col1;
aces_2008_props3117_&year	=	col1;
aces_2008_props3118_&year	=	col1;
aces_2008_props3119_&year	=	col1;
aces_2008_props3121_&year	=	col2;
aces_2008_props3122_&year	=	col3;
aces_2008_props3131_&year	=	col4;
aces_2008_props3132_&year	=	col4;
aces_2008_props3133_&year	=	col4;
aces_2008_props3141_&year	=	col4;
aces_2008_props3149_&year	=	col4;
aces_2008_props3151_&year	=	col5;
aces_2008_props3152_&year	=	col5;
aces_2008_props3159_&year	=	col5;
aces_2008_props3161_&year	=	col6;
aces_2008_props3162_&year	=	col6;
aces_2008_props3169_&year	=	col6;
aces_2008_props3211_&year	=	col7;
aces_2008_props3212_&year	=	col7;
aces_2008_props3219_&year	=	col7;
aces_2008_props3221_&year	=	col8;
aces_2008_props3222_&year	=	col8;
aces_2008_props3231_&year	=	col9;
aces_2008_props3241_&year	=	col10;
aces_2008_props3251_&year	=	col11;
aces_2008_props3252_&year	=	col11;
aces_2008_props3253_&year	=	col12;
aces_2008_props3254_&year	=	col13;
aces_2008_props3255_&year	=	col14;
aces_2008_props3256_&year	=	col14;
aces_2008_props3259_&year	=	col14;
aces_2008_props3261_&year	=	col15;
aces_2008_props3262_&year	=	col15;
aces_2008_props3271_&year	=	col16;
aces_2008_props3272_&year	=	col16;
aces_2008_props3273_&year	=	col17;
aces_2008_props3274_&year	=	col17;
aces_2008_props3279_&year	=	col17;
aces_2008_props3311_&year	=	col18;
aces_2008_props3312_&year	=	col18;
aces_2008_props3313_&year	=	col19;
aces_2008_props3314_&year	=	col19;
aces_2008_props3315_&year	=	col20;
aces_2008_props3321_&year	=	col21;
aces_2008_props3322_&year	=	col21;
aces_2008_props3323_&year	=	col21;
aces_2008_props3324_&year	=	col21;
aces_2008_props3325_&year	=	col21;
aces_2008_props3326_&year	=	col21;
aces_2008_props3327_&year	=	col21;
aces_2008_props3328_&year	=	col21;
aces_2008_props3329_&year	=	col21;
aces_2008_props3331_&year	=	col22;
aces_2008_props3332_&year	=	col23;
aces_2008_props3333_&year	=	col24;
aces_2008_props3334_&year	=	col24;
aces_2008_props3335_&year	=	col23;
aces_2008_props3336_&year	=	col25;
aces_2008_props3339_&year	=	col23;
aces_2008_props3341_&year	=	col26;
aces_2008_props3342_&year	=	col27;
aces_2008_props3343_&year	=	col27;
aces_2008_props3344_&year	=	col28;
aces_2008_props3345_&year	=	col29;
aces_2008_props3346_&year	=	col30;
aces_2008_props3351_&year	=	col31;
aces_2008_props3352_&year	=	col31;
aces_2008_props3353_&year	=	col31;
aces_2008_props3359_&year	=	col31;
aces_2008_props3361_&year	=	col32;
aces_2008_props3362_&year	=	col32;
aces_2008_props3363_&year	=	col32;
aces_2008_props3364_&year	=	col33;
aces_2008_props3365_&year	=	col34;
aces_2008_props3366_&year	=	col34;
aces_2008_props3369_&year	=	col34;
aces_2008_props3371_&year	=	col35;
aces_2008_props3372_&year	=	col35;
aces_2008_props3379_&year	=	col35;
aces_2008_props3391_&year	=	col36;
aces_2008_props3399_&year	=	col37;

drop col:;
run;
%end;
%mend loop;
%loop;

/*Combining each industry's proportions for each year into one industry specific dataset */ 
%macro combine;
data work.big;
merge 
	%do i= 1958 %to &last;
	work.aces_2008_rme&i
	%end;
	;
run;
%mend combine;
%combine;

%macro keeper;
%do indy=1 %to 86;
data ras.aces_2008_propnaics&&NAICS_Indy&indy;
set work.big;
keep aces_2008_props&&NAICS_Indy&indy:;
run;
%end;
%mend keeper;
%keeper;

/*Putting the 2008 ACES structure proportions on a NAICS basis*/
%macro loop;
%do year= 1958 %to &last;
data work.aces_2008_rms&year;
set ras.aces_2008_rms&year;
aces_2008_props3111_&year	=	col1;
aces_2008_props3112_&year	=	col1;
aces_2008_props3113_&year	=	col1;
aces_2008_props3114_&year	=	col1;
aces_2008_props3115_&year	=	col1;
aces_2008_props3116_&year	=	col1;
aces_2008_props3117_&year	=	col1;
aces_2008_props3118_&year	=	col1;
aces_2008_props3119_&year	=	col1;
aces_2008_props3121_&year	=	col2;
aces_2008_props3122_&year	=	col3;
aces_2008_props3131_&year	=	col4;
aces_2008_props3132_&year	=	col4;
aces_2008_props3133_&year	=	col4;
aces_2008_props3141_&year	=	col4;
aces_2008_props3149_&year	=	col4;
aces_2008_props3151_&year	=	col5;
aces_2008_props3152_&year	=	col5;
aces_2008_props3159_&year	=	col5;
aces_2008_props3161_&year	=	col6;
aces_2008_props3162_&year	=	col6;
aces_2008_props3169_&year	=	col6;
aces_2008_props3211_&year	=	col7;
aces_2008_props3212_&year	=	col7;
aces_2008_props3219_&year	=	col7;
aces_2008_props3221_&year	=	col8;
aces_2008_props3222_&year	=	col8;
aces_2008_props3231_&year	=	col9;
aces_2008_props3241_&year	=	col10;
aces_2008_props3251_&year	=	col11;
aces_2008_props3252_&year	=	col11;
aces_2008_props3253_&year	=	col12;
aces_2008_props3254_&year	=	col13;
aces_2008_props3255_&year	=	col14;
aces_2008_props3256_&year	=	col14;
aces_2008_props3259_&year	=	col14;
aces_2008_props3261_&year	=	col15;
aces_2008_props3262_&year	=	col15;
aces_2008_props3271_&year	=	col16;
aces_2008_props3272_&year	=	col16;
aces_2008_props3273_&year	=	col17;
aces_2008_props3274_&year	=	col17;
aces_2008_props3279_&year	=	col17;
aces_2008_props3311_&year	=	col18;
aces_2008_props3312_&year	=	col18;
aces_2008_props3313_&year	=	col19;
aces_2008_props3314_&year	=	col19;
aces_2008_props3315_&year	=	col20;
aces_2008_props3321_&year	=	col21;
aces_2008_props3322_&year	=	col21;
aces_2008_props3323_&year	=	col21;
aces_2008_props3324_&year	=	col21;
aces_2008_props3325_&year	=	col21;
aces_2008_props3326_&year	=	col21;
aces_2008_props3327_&year	=	col21;
aces_2008_props3328_&year	=	col21;
aces_2008_props3329_&year	=	col21;
aces_2008_props3331_&year	=	col22;
aces_2008_props3332_&year	=	col23;
aces_2008_props3333_&year	=	col24;
aces_2008_props3334_&year	=	col24;
aces_2008_props3335_&year	=	col23;
aces_2008_props3336_&year	=	col25;
aces_2008_props3339_&year	=	col23;
aces_2008_props3341_&year	=	col26;
aces_2008_props3342_&year	=	col27;
aces_2008_props3343_&year	=	col27;
aces_2008_props3344_&year	=	col28;
aces_2008_props3345_&year	=	col29;
aces_2008_props3346_&year	=	col30;
aces_2008_props3351_&year	=	col31;
aces_2008_props3352_&year	=	col31;
aces_2008_props3353_&year	=	col31;
aces_2008_props3359_&year	=	col31;
aces_2008_props3361_&year	=	col32;
aces_2008_props3362_&year	=	col32;
aces_2008_props3363_&year	=	col32;
aces_2008_props3364_&year	=	col33;
aces_2008_props3365_&year	=	col34;
aces_2008_props3366_&year	=	col34;
aces_2008_props3369_&year	=	col34;
aces_2008_props3371_&year	=	col35;
aces_2008_props3372_&year	=	col35;
aces_2008_props3379_&year	=	col35;
aces_2008_props3391_&year	=	col36;
aces_2008_props3399_&year	=	col37;

drop col:;
run;
%end;
%mend loop;
%loop;

/*Combining each industry's proportions for each year into one industry specific dataset */ 
%macro combine;
data work.big_struct;
merge 
	%do i= 1958 %to &last;
	work.aces_2008_rms&i
	%end;
	;
run;
%mend combine;
%combine;


%macro keeper;
%do indy=1 %to 86;
data ras.propnaicstr2008&&NAICS_Indy&indy;
set work.big_struct;
keep aces_2008_props&&NAICS_Indy&indy:;
run;
%end;
%mend keeper;
%keeper;

/*Putting the 2012 ACES industry proportions on a NAICS basis*/
%macro loop;
%do year= 1958 %to &last;
data work.aces_2012_rme&year;
set ras.aces_2012_rme&year;
aces_2012_props3111_&year	=	col1;
aces_2012_props3112_&year	=	col1;
aces_2012_props3113_&year	=	col1;
aces_2012_props3114_&year	=	col1;
aces_2012_props3115_&year	=	col1;
aces_2012_props3116_&year	=	col1;
aces_2012_props3117_&year	=	col1;
aces_2012_props3118_&year	=	col1;
aces_2012_props3119_&year	=	col1;
aces_2012_props3121_&year	=	col2;
aces_2012_props3122_&year	=	col3;
aces_2012_props3131_&year	=	col4;
aces_2012_props3132_&year	=	col4;
aces_2012_props3133_&year	=	col4;
aces_2012_props3141_&year	=	col4;
aces_2012_props3149_&year	=	col4;
aces_2012_props3151_&year	=	col5;
aces_2012_props3152_&year	=	col5;
aces_2012_props3159_&year	=	col5;
aces_2012_props3161_&year	=	col6;
aces_2012_props3162_&year	=	col6;
aces_2012_props3169_&year	=	col6;
aces_2012_props3211_&year	=	col7;
aces_2012_props3212_&year	=	col7;
aces_2012_props3219_&year	=	col7;
aces_2012_props3221_&year	=	col8;
aces_2012_props3222_&year	=	col8;
aces_2012_props3231_&year	=	col9;
aces_2012_props3241_&year	=	col10;
aces_2012_props3251_&year	=	col11;
aces_2012_props3252_&year	=	col11;
aces_2012_props3253_&year	=	col12;
aces_2012_props3254_&year	=	col13;
aces_2012_props3255_&year	=	col14;
aces_2012_props3256_&year	=	col14;
aces_2012_props3259_&year	=	col14;
aces_2012_props3261_&year	=	col15;
aces_2012_props3262_&year	=	col15;
aces_2012_props3271_&year	=	col16;
aces_2012_props3272_&year	=	col16;
aces_2012_props3273_&year	=	col17;
aces_2012_props3274_&year	=	col17;
aces_2012_props3279_&year	=	col17;
aces_2012_props3311_&year	=	col18;
aces_2012_props3312_&year	=	col18;
aces_2012_props3313_&year	=	col19;
aces_2012_props3314_&year	=	col19;
aces_2012_props3315_&year	=	col20;
aces_2012_props3321_&year	=	col21;
aces_2012_props3322_&year	=	col21;
aces_2012_props3323_&year	=	col21;
aces_2012_props3324_&year	=	col21;
aces_2012_props3325_&year	=	col21;
aces_2012_props3326_&year	=	col21;
aces_2012_props3327_&year	=	col21;
aces_2012_props3328_&year	=	col21;
aces_2012_props3329_&year	=	col21;
aces_2012_props3331_&year	=	col22;
aces_2012_props3332_&year	=	col23;
aces_2012_props3333_&year	=	col24;
aces_2012_props3334_&year	=	col24;
aces_2012_props3335_&year	=	col23;
aces_2012_props3336_&year	=	col25;
aces_2012_props3339_&year	=	col23;
aces_2012_props3341_&year	=	col26;
aces_2012_props3342_&year	=	col27;
aces_2012_props3343_&year	=	col27;
aces_2012_props3344_&year	=	col28;
aces_2012_props3345_&year	=	col29;
aces_2012_props3346_&year	=	col30;
aces_2012_props3351_&year	=	col31;
aces_2012_props3352_&year	=	col31;
aces_2012_props3353_&year	=	col31;
aces_2012_props3359_&year	=	col31;
aces_2012_props3361_&year	=	col32;
aces_2012_props3362_&year	=	col32;
aces_2012_props3363_&year	=	col32;
aces_2012_props3364_&year	=	col33;
aces_2012_props3365_&year	=	col34;
aces_2012_props3366_&year	=	col34;
aces_2012_props3369_&year	=	col34;
aces_2012_props3371_&year	=	col35;
aces_2012_props3372_&year	=	col35;
aces_2012_props3379_&year	=	col35;
aces_2012_props3391_&year	=	col36;
aces_2012_props3399_&year	=	col37;

drop col:;
run;
%end;
%mend loop;
%loop;

/*Combining each industry's proportions for each year into one industry specific dataset */ 
%macro combine;
data work.big;
merge 
	%do i= 1958 %to &last;
	work.aces_2012_rme&i
	%end;
	;
run;
%mend combine;
%combine;

%macro keeper;
%do indy=1 %to 86;
data ras.aces_2012_propnaics&&NAICS_Indy&indy;
set work.big;
keep aces_2012_props&&NAICS_Indy&indy:;
run;
%end;
%mend keeper;
%keeper;

/*Putting the 2012 ACES structure proportions on a NAICS basis*/
%macro loop;
%do year= 1958 %to &last;
data work.aces_2012_rms&year;
set ras.aces_2012_rms&year;
aces_2012_props3111_&year	=	col1;
aces_2012_props3112_&year	=	col1;
aces_2012_props3113_&year	=	col1;
aces_2012_props3114_&year	=	col1;
aces_2012_props3115_&year	=	col1;
aces_2012_props3116_&year	=	col1;
aces_2012_props3117_&year	=	col1;
aces_2012_props3118_&year	=	col1;
aces_2012_props3119_&year	=	col1;
aces_2012_props3121_&year	=	col2;
aces_2012_props3122_&year	=	col3;
aces_2012_props3131_&year	=	col4;
aces_2012_props3132_&year	=	col4;
aces_2012_props3133_&year	=	col4;
aces_2012_props3141_&year	=	col4;
aces_2012_props3149_&year	=	col4;
aces_2012_props3151_&year	=	col5;
aces_2012_props3152_&year	=	col5;
aces_2012_props3159_&year	=	col5;
aces_2012_props3161_&year	=	col6;
aces_2012_props3162_&year	=	col6;
aces_2012_props3169_&year	=	col6;
aces_2012_props3211_&year	=	col7;
aces_2012_props3212_&year	=	col7;
aces_2012_props3219_&year	=	col7;
aces_2012_props3221_&year	=	col8;
aces_2012_props3222_&year	=	col8;
aces_2012_props3231_&year	=	col9;
aces_2012_props3241_&year	=	col10;
aces_2012_props3251_&year	=	col11;
aces_2012_props3252_&year	=	col11;
aces_2012_props3253_&year	=	col12;
aces_2012_props3254_&year	=	col13;
aces_2012_props3255_&year	=	col14;
aces_2012_props3256_&year	=	col14;
aces_2012_props3259_&year	=	col14;
aces_2012_props3261_&year	=	col15;
aces_2012_props3262_&year	=	col15;
aces_2012_props3271_&year	=	col16;
aces_2012_props3272_&year	=	col16;
aces_2012_props3273_&year	=	col17;
aces_2012_props3274_&year	=	col17;
aces_2012_props3279_&year	=	col17;
aces_2012_props3311_&year	=	col18;
aces_2012_props3312_&year	=	col18;
aces_2012_props3313_&year	=	col19;
aces_2012_props3314_&year	=	col19;
aces_2012_props3315_&year	=	col20;
aces_2012_props3321_&year	=	col21;
aces_2012_props3322_&year	=	col21;
aces_2012_props3323_&year	=	col21;
aces_2012_props3324_&year	=	col21;
aces_2012_props3325_&year	=	col21;
aces_2012_props3326_&year	=	col21;
aces_2012_props3327_&year	=	col21;
aces_2012_props3328_&year	=	col21;
aces_2012_props3329_&year	=	col21;
aces_2012_props3331_&year	=	col22;
aces_2012_props3332_&year	=	col23;
aces_2012_props3333_&year	=	col24;
aces_2012_props3334_&year	=	col24;
aces_2012_props3335_&year	=	col23;
aces_2012_props3336_&year	=	col25;
aces_2012_props3339_&year	=	col23;
aces_2012_props3341_&year	=	col26;
aces_2012_props3342_&year	=	col27;
aces_2012_props3343_&year	=	col27;
aces_2012_props3344_&year	=	col28;
aces_2012_props3345_&year	=	col29;
aces_2012_props3346_&year	=	col30;
aces_2012_props3351_&year	=	col31;
aces_2012_props3352_&year	=	col31;
aces_2012_props3353_&year	=	col31;
aces_2012_props3359_&year	=	col31;
aces_2012_props3361_&year	=	col32;
aces_2012_props3362_&year	=	col32;
aces_2012_props3363_&year	=	col32;
aces_2012_props3364_&year	=	col33;
aces_2012_props3365_&year	=	col34;
aces_2012_props3366_&year	=	col34;
aces_2012_props3369_&year	=	col34;
aces_2012_props3371_&year	=	col35;
aces_2012_props3372_&year	=	col35;
aces_2012_props3379_&year	=	col35;
aces_2012_props3391_&year	=	col36;
aces_2012_props3399_&year	=	col37;

drop col:;
run;
%end;
%mend loop;
%loop;

/*Combining each industry's proportions for each year into one industry specific dataset */ 
%macro combine;
data work.big_struct;
merge 
	%do i= 1958 %to &last;
	work.aces_2012_rms&i
	%end;
	;
run;
%mend combine;
%combine;

%macro keeper;
%do indy=1 %to 86;
data ras.propnaicstr2012&&NAICS_Indy&indy;
set work.big_struct;
keep aces_2012_props&&NAICS_Indy&indy:;
run;
%end;
%mend keeper;
%keeper;


/*Putting the CFT industry proportions on a NAICS basis*/
%macro loop;
%do year= 1958 %to &last;
data work.cft_rme&year;
set ras.cft_rme&year;
cft_props3111_&year	=	col1	;
cft_props3112_&year	=	col1	;
cft_props3113_&year	=	col1	;
cft_props3114_&year	=	col1	;
cft_props3115_&year	=	col1	;
cft_props3116_&year	=	col1	;
cft_props3117_&year	=	col1	;
cft_props3118_&year	=	col1	;
cft_props3119_&year	=	col1	;
cft_props3121_&year	=	col2	;
cft_props3122_&year	=	col3	;
cft_props3131_&year	=	col4	;
cft_props3132_&year	=	col4	;
cft_props3133_&year	=	col4	;
cft_props3141_&year	=	col5	;
cft_props3149_&year	=	col5	;
cft_props3151_&year	=	col6	;
cft_props3152_&year	=	col6	;
cft_props3159_&year	=	col6	;
cft_props3161_&year	=	col7	;
cft_props3162_&year	=	col7	;
cft_props3169_&year	=	col7	;
cft_props3211_&year	=	col8	;
cft_props3212_&year	=	col8	;
cft_props3219_&year	=	col8	;
cft_props3221_&year	=	col9	;
cft_props3222_&year	=	col10	;
cft_props3231_&year	=	col11	;
cft_props3241_&year	=	col12	;
cft_props3251_&year	=	col13	;
cft_props3252_&year	=	col14	;
cft_props3253_&year	=	col15	;
cft_props3254_&year	=	col16	;
cft_props3255_&year	=	col17	;
cft_props3256_&year	=	col18	;
cft_props3259_&year	=	col19	;
cft_props3261_&year	=	col20	;
cft_props3262_&year	=	col20	;
cft_props3271_&year	=	col21	;
cft_props3272_&year	=	col21	;
cft_props3273_&year	=	col21	;
cft_props3274_&year	=	col21	;
cft_props3279_&year	=	col21	;
cft_props3311_&year	=	col22	;
cft_props3312_&year	=	col22	;
cft_props3313_&year	=	col23	;
cft_props3314_&year	=	col23	;
cft_props3315_&year	=	col24	;
cft_props3321_&year	=	col25	;
cft_props3322_&year	=	col26	;
cft_props3323_&year	=	col27	;
cft_props3324_&year	=	col28	;
cft_props3325_&year	=	col30	;
cft_props3326_&year	=	col30	;
cft_props3327_&year	=	col30	;
cft_props3328_&year	=	col30	;
cft_props3329_&year	=	col29	;
cft_props3331_&year	=	col31	;
cft_props3332_&year	=	col32	;
cft_props3333_&year	=	col33	;
cft_props3334_&year	=	col34	;
cft_props3335_&year	=	col35	;
cft_props3336_&year	=	col36	;
cft_props3339_&year	=	col37	;
cft_props3341_&year	=	col38	;
cft_props3342_&year	=	col39	;
cft_props3343_&year	=	col39	;
cft_props3344_&year	=	col40	;
cft_props3345_&year	=	col41	;
cft_props3346_&year	=	col42	;
cft_props3351_&year	=	col43	;
cft_props3352_&year	=	col44	;
cft_props3353_&year	=	col45	;
cft_props3359_&year	=	col46	;
cft_props3361_&year	=	col47	;
cft_props3362_&year	=	col48	;
cft_props3363_&year	=	col48	;
cft_props3364_&year	=	col49	;
cft_props3365_&year	=	col50	;
cft_props3366_&year	=	col50	;
cft_props3369_&year	=	col50	;
cft_props3371_&year	=	col51	;
cft_props3372_&year	=	col51	;
cft_props3379_&year	=	col51	;
cft_props3391_&year	=	col52 	;
cft_props3399_&year	=	col53	;

drop col:;
run;
%end;
%mend loop;
%loop;


/*Combining each industry's proportions for each year into one industry specific dataset */ 
%macro combine;
data work.cft_big;
merge 
	%do i= 1958 %to &last;
	work.cft_rme&i
	%end;
	;
run;
%mend combine;
%combine;

%macro keeper;
%do indy=1 %to 86;
data ras.cft_propnaics&&NAICS_Indy&indy;
set work.cft_big;
keep cft_props&&NAICS_Indy&indy:;
run;
%end;
%mend keeper;
%keeper;

/*Combining the CFT and ACES equipment asset proportions. CFT will be used from 1958-1997. 1998-2007 will be interpolated
  with 1997 CFT and 2008 ACES. 2008 will use 2008 ACES. 2009-2011 will be interpolated with 2008 ACES and 2012 ACES. 
  For 2012-forward, the 2012 ACES will be used*/
%macro all;
%do indy=1 %to 86;

data work.propnaics&&NAICS_Indy&indy;
merge ras.cft_propnaics&&NAICS_Indy&indy ras.aces_2008_propnaics&&NAICS_Indy&indy ras.aces_2012_propnaics&&NAICS_Indy&indy;
run;

data ras.propnaics&&NAICS_Indy&indy;
set work.propnaics&&NAICS_Indy&indy;
	/*creating an interpolation factor from ACES for 1997-2008*/
	array interpolation1 {11}  t1-t11 (1 2 3 4 5 6 7 8 9 10 11);
	array years1 {11} interp1998-interp2008;
		do i=1 to 11;
			 years1 {i}= interpolation1 {i}/11;
		end; 
	/*creating an interpolation factor from ACES for 2009-2012*/
	array interpolation2 {4}  t1-t4 (1 2 3 4 );
	array years2 {4} interp2009-interp2012;
		do i=1 to 4;
			 years2 {i}= interpolation2 {i}/4;
		end; 

	/*creating proportions for 1998-2007*/
	%macro year;
	%do year=1998 %to 2007;
	props_&year=interp&year*aces_2008_props&&NAICS_Indy&indy.._&year+(1-interp&year)*cft_props&&NAICS_Indy&indy.._&year;
	%end;
	%mend year;
	%year;
	/*creating proportions for 2009-2011*/
	%macro year;
	%do year=2009 %to 2011;
	props_&year=interp&year*aces_2012_props&&NAICS_Indy&indy.._&year+(1-interp&year)*aces_2008_props&&NAICS_Indy&indy.._&year;
	%end;
	%mend year;
	%year;

	%macro cft;
	%do year=1958 %to 1997;
	propnaics_&year=cft_props&&NAICS_Indy&indy.._&year;
	%end;
	%mend cft;
	%cft;
	%macro again;
	%do year=1998 %to 2007;
	propnaics_&year=props_&year;
	%end;
	%mend again;
	%again;
	
	propnaics_2008=aces_2008_props&&NAICS_Indy&indy.._2008;

	%macro aces;
	%do year=2009 %to 2011;
	propnaics_&year=props_&year;
	%end;
	%mend aces;
	%aces;
	%macro aces;
	%do year=2012 %to &last;
	propnaics_&year=aces_2012_props&&NAICS_Indy&indy.._&year;
	%end;
	%mend aces;
	%aces;
	keep propnaics: ;
run;

%end;
%mend all;
%all;

/*Putting the 2008 ACES structure proportions on a NAICS basis*/
%macro loop;
%do year= 1958 %to &last;
data work.aces_2008_rms&year;
set ras.aces_2008_rms&year;
aces_2008_props3111_&year	=	col1;
aces_2008_props3112_&year	=	col1;
aces_2008_props3113_&year	=	col1;
aces_2008_props3114_&year	=	col1;
aces_2008_props3115_&year	=	col1;
aces_2008_props3116_&year	=	col1;
aces_2008_props3117_&year	=	col1;
aces_2008_props3118_&year	=	col1;
aces_2008_props3119_&year	=	col1;
aces_2008_props3121_&year	=	col2;
aces_2008_props3122_&year	=	col3;
aces_2008_props3131_&year	=	col4;
aces_2008_props3132_&year	=	col4;
aces_2008_props3133_&year	=	col4;
aces_2008_props3141_&year	=	col4;
aces_2008_props3149_&year	=	col4;
aces_2008_props3151_&year	=	col5;
aces_2008_props3152_&year	=	col5;
aces_2008_props3159_&year	=	col5;
aces_2008_props3161_&year	=	col6;
aces_2008_props3162_&year	=	col6;
aces_2008_props3169_&year	=	col6;
aces_2008_props3211_&year	=	col7;
aces_2008_props3212_&year	=	col7;
aces_2008_props3219_&year	=	col7;
aces_2008_props3221_&year	=	col8;
aces_2008_props3222_&year	=	col8;
aces_2008_props3231_&year	=	col9;
aces_2008_props3241_&year	=	col10;
aces_2008_props3251_&year	=	col11;
aces_2008_props3252_&year	=	col11;
aces_2008_props3253_&year	=	col12;
aces_2008_props3254_&year	=	col13;
aces_2008_props3255_&year	=	col14;
aces_2008_props3256_&year	=	col14;
aces_2008_props3259_&year	=	col14;
aces_2008_props3261_&year	=	col15;
aces_2008_props3262_&year	=	col15;
aces_2008_props3271_&year	=	col16;
aces_2008_props3272_&year	=	col16;
aces_2008_props3273_&year	=	col17;
aces_2008_props3274_&year	=	col17;
aces_2008_props3279_&year	=	col17;
aces_2008_props3311_&year	=	col18;
aces_2008_props3312_&year	=	col18;
aces_2008_props3313_&year	=	col19;
aces_2008_props3314_&year	=	col19;
aces_2008_props3315_&year	=	col20;
aces_2008_props3321_&year	=	col21;
aces_2008_props3322_&year	=	col21;
aces_2008_props3323_&year	=	col21;
aces_2008_props3324_&year	=	col21;
aces_2008_props3325_&year	=	col21;
aces_2008_props3326_&year	=	col21;
aces_2008_props3327_&year	=	col21;
aces_2008_props3328_&year	=	col21;
aces_2008_props3329_&year	=	col21;
aces_2008_props3331_&year	=	col22;
aces_2008_props3332_&year	=	col23;
aces_2008_props3333_&year	=	col24;
aces_2008_props3334_&year	=	col24;
aces_2008_props3335_&year	=	col23;
aces_2008_props3336_&year	=	col25;
aces_2008_props3339_&year	=	col23;
aces_2008_props3341_&year	=	col26;
aces_2008_props3342_&year	=	col27;
aces_2008_props3343_&year	=	col27;
aces_2008_props3344_&year	=	col28;
aces_2008_props3345_&year	=	col29;
aces_2008_props3346_&year	=	col30;
aces_2008_props3351_&year	=	col31;
aces_2008_props3352_&year	=	col31;
aces_2008_props3353_&year	=	col31;
aces_2008_props3359_&year	=	col31;
aces_2008_props3361_&year	=	col32;
aces_2008_props3362_&year	=	col32;
aces_2008_props3363_&year	=	col32;
aces_2008_props3364_&year	=	col33;
aces_2008_props3365_&year	=	col34;
aces_2008_props3366_&year	=	col34;
aces_2008_props3369_&year	=	col34;
aces_2008_props3371_&year	=	col35;
aces_2008_props3372_&year	=	col35;
aces_2008_props3379_&year	=	col35;
aces_2008_props3391_&year	=	col36;
aces_2008_props3399_&year	=	col37;

drop col:;
run;
%end;
%mend loop;
%loop;

/*Combining each industry's proportions for each year into one industry specific dataset */ 
%macro combine;
data work.big;
merge 
	%do i= 1958 %to &last;
	work.aces_2008_rms&i
	%end;
	;
run;
%mend combine;
%combine;

%macro keeper;
%do indy=1 %to 86;
data ras.aces_2008_propnaicstr&&NAICS_Indy&indy;
set work.big;
keep aces_2008_props&&NAICS_Indy&indy:;
run;
%end;
%mend keeper;
%keeper;

/*Putting the 2012 ACES structure proportions on a NAICS basis*/
%macro loop;
%do year= 1958 %to &last;
data work.aces_2012_rms&year;
set ras.aces_2012_rms&year;
aces_2012_props3111_&year	=	col1;
aces_2012_props3112_&year	=	col1;
aces_2012_props3113_&year	=	col1;
aces_2012_props3114_&year	=	col1;
aces_2012_props3115_&year	=	col1;
aces_2012_props3116_&year	=	col1;
aces_2012_props3117_&year	=	col1;
aces_2012_props3118_&year	=	col1;
aces_2012_props3119_&year	=	col1;
aces_2012_props3121_&year	=	col2;
aces_2012_props3122_&year	=	col3;
aces_2012_props3131_&year	=	col4;
aces_2012_props3132_&year	=	col4;
aces_2012_props3133_&year	=	col4;
aces_2012_props3141_&year	=	col4;
aces_2012_props3149_&year	=	col4;
aces_2012_props3151_&year	=	col5;
aces_2012_props3152_&year	=	col5;
aces_2012_props3159_&year	=	col5;
aces_2012_props3161_&year	=	col6;
aces_2012_props3162_&year	=	col6;
aces_2012_props3169_&year	=	col6;
aces_2012_props3211_&year	=	col7;
aces_2012_props3212_&year	=	col7;
aces_2012_props3219_&year	=	col7;
aces_2012_props3221_&year	=	col8;
aces_2012_props3222_&year	=	col8;
aces_2012_props3231_&year	=	col9;
aces_2012_props3241_&year	=	col10;
aces_2012_props3251_&year	=	col11;
aces_2012_props3252_&year	=	col11;
aces_2012_props3253_&year	=	col12;
aces_2012_props3254_&year	=	col13;
aces_2012_props3255_&year	=	col14;
aces_2012_props3256_&year	=	col14;
aces_2012_props3259_&year	=	col14;
aces_2012_props3261_&year	=	col15;
aces_2012_props3262_&year	=	col15;
aces_2012_props3271_&year	=	col16;
aces_2012_props3272_&year	=	col16;
aces_2012_props3273_&year	=	col17;
aces_2012_props3274_&year	=	col17;
aces_2012_props3279_&year	=	col17;
aces_2012_props3311_&year	=	col18;
aces_2012_props3312_&year	=	col18;
aces_2012_props3313_&year	=	col19;
aces_2012_props3314_&year	=	col19;
aces_2012_props3315_&year	=	col20;
aces_2012_props3321_&year	=	col21;
aces_2012_props3322_&year	=	col21;
aces_2012_props3323_&year	=	col21;
aces_2012_props3324_&year	=	col21;
aces_2012_props3325_&year	=	col21;
aces_2012_props3326_&year	=	col21;
aces_2012_props3327_&year	=	col21;
aces_2012_props3328_&year	=	col21;
aces_2012_props3329_&year	=	col21;
aces_2012_props3331_&year	=	col22;
aces_2012_props3332_&year	=	col23;
aces_2012_props3333_&year	=	col24;
aces_2012_props3334_&year	=	col24;
aces_2012_props3335_&year	=	col23;
aces_2012_props3336_&year	=	col25;
aces_2012_props3339_&year	=	col23;
aces_2012_props3341_&year	=	col26;
aces_2012_props3342_&year	=	col27;
aces_2012_props3343_&year	=	col27;
aces_2012_props3344_&year	=	col28;
aces_2012_props3345_&year	=	col29;
aces_2012_props3346_&year	=	col30;
aces_2012_props3351_&year	=	col31;
aces_2012_props3352_&year	=	col31;
aces_2012_props3353_&year	=	col31;
aces_2012_props3359_&year	=	col31;
aces_2012_props3361_&year	=	col32;
aces_2012_props3362_&year	=	col32;
aces_2012_props3363_&year	=	col32;
aces_2012_props3364_&year	=	col33;
aces_2012_props3365_&year	=	col34;
aces_2012_props3366_&year	=	col34;
aces_2012_props3369_&year	=	col34;
aces_2012_props3371_&year	=	col35;
aces_2012_props3372_&year	=	col35;
aces_2012_props3379_&year	=	col35;
aces_2012_props3391_&year	=	col36;
aces_2012_props3399_&year	=	col37;

drop col:;
run;
%end;
%mend loop;
%loop;

/*Combining each industry's proportions for each year into one industry specific dataset */ 
%macro combine;
data work.big;
merge 
	%do i= 1958 %to &last;
	work.aces_2012_rms&i
	%end;
	;
run;
%mend combine;
%combine;

%macro keeper;
%do indy=1 %to 86;
data ras.aces_2012_propnaicstr&&NAICS_Indy&indy;
set work.big;
keep aces_2012_props&&NAICS_Indy&indy:;
run;
%end;
%mend keeper;
%keeper;

/*Combining ACES structure asset proportions. The 2008 ACES proportions will be used for 1901-2008. 2009-2011 will be 
  interpolated with 2008 ACES and 2012 ACES. For 2012-forward, the 2012 ACES will be used*/
%macro all;
%do indy=1 %to 86;

data work.propnaicstr&&NAICS_Indy&indy;
merge  ras.aces_2008_propnaicstr&&NAICS_Indy&indy ras.aces_2012_propnaicstr&&NAICS_Indy&indy;
run;

data ras.propnaicstr&&NAICS_Indy&indy;
set work.propnaicstr&&NAICS_Indy&indy;
	/*creating an interpolation factor from ACES for 2009-2012*/
	array interpolation2 {4}  t1-t4 (1 2 3 4 );
	array years2 {4} interp2009-interp2012;
		do i=1 to 4;
			 years2 {i}= interpolation2 {i}/4;
		end; 

	/*creating proportions for 2009-2011*/
	%macro year;
	%do year=2009 %to 2011;
	props_&year=interp&year*aces_2012_props&&NAICS_Indy&indy.._&year+(1-interp&year)*aces_2008_props&&NAICS_Indy&indy.._&year;
	%end;
	%mend year;
	%year;

	%macro cft;
	%do year=1958 %to 2008;
	propnaicstr_&year=aces_2008_props&&NAICS_Indy&indy.._&year;
	%end;
	%mend cft;
	%cft;
	
	%macro aces;
	%do year=2009 %to 2011;
	propnaicstr_&year=props_&year;
	%end;
	%mend aces;
	%aces;

	%macro aces;
	%do year=2012 %to &last;
	propnaicstr_&year=aces_2012_props&&NAICS_Indy&indy.._&year;
	%end;
	%mend aces;
	%aces;
	keep propnaicstr: ;
run;

%end;
%mend all;
%all;


/*****************Adjusting nominal ASM industry investment for special tools for 1972-forward*****************/

data work.naicscapexp;
set capital.naicscapexp;
drop structures total;
run;
proc sort data=work.naicscapexp;
by year;
run;
proc transpose data=work.naicscapexp out=work.capexp_t (drop = _label_);
by year;
var equipment;
id naics;
run;
/*calculating 3361, 3362, 3363 shares of total investment between the 3 industries*/
data work.capexp_t;
set work.capexp_t;
total_auto=_3361+_3362+_3363;
share_3361=_3361/total_auto;
share_3362=_3362/total_auto;
share_3363=_3363/total_auto;
run;

data work.nomspt ;
set sptools.special_tools (where =(year>1957));
drop defspt realspt;
run;

data work.capexp;
merge work.capexp_t work.nomspt;
by year;
run;
/*removing each industry's share of special tools for 1972-forward*/
data work.capexp2;
set work.capexp;
if year > 1971 then _3361_new=_3361-share_3361*nomspt;
else _3361_new=_3361;
if year > 1971 then _3362_new=_3362-share_3362*nomspt;
else _3362_new=_3362;
if year > 1971 then _3363_new=_3363-share_3363*nomspt;
else _3363_new=_3363;
_3361=_3361_new;
_3362=_3362_new;
_3363=_3363_new;
drop _3361_new _3362_new _3363_new total_auto share_: nomspt;
run;

proc transpose data=work.capexp2 out=work.capex_adjusted_equip (drop=_label_);
by year;
var _:;
run;
data work.capex_adjusted_equip2 ;
set work.capex_adjusted_equip;
if _name_="_NAME_" then delete;
naics=substr(_name_,2);
/*converting naics equipment values to numeric*/
equipment2=equipment*1;
drop _name_ equipment;
run;
proc sort data=work.capex_adjusted_equip2;
by naics year;
run;
/*Putting the adjusted equipment values back into the original capexp dataset*/
data work.Capexp_Adjusted ;
merge capital.naicscapexp work.capex_adjusted_equip2;
by naics year;
drop equipment;
run;

/*Putting all BEA software ratios into one dataset in the order of corresponding NAICS industries*/
data work.all_software (rename=(col1=software_ratio));
set 
	/*NAICS 3111-3119*/
	invest.softrat_all_i20 (firstobs=58)
    invest.softrat_all_i20 (firstobs=58)
	invest.softrat_all_i20 (firstobs=58)
    invest.softrat_all_i20 (firstobs=58)
	invest.softrat_all_i20 (firstobs=58)
    invest.softrat_all_i20 (firstobs=58)
	invest.softrat_all_i20 (firstobs=58)
    invest.softrat_all_i20 (firstobs=58)
	invest.softrat_all_i20 (firstobs=58)
    /*NAICS 3121-3122*/
    invest.softrat_all_i20 (firstobs=58)
    invest.softrat_all_i20 (firstobs=58)
    /*NAICS 3131-3133*/
	invest.softrat_all_i22 (firstobs=58)
	invest.softrat_all_i22 (firstobs=58)
	invest.softrat_all_i22 (firstobs=58)
    /*NAICS 3141 3149*/
	invest.softrat_all_i22 (firstobs=58)
	invest.softrat_all_i22 (firstobs=58)
    /*NAICS 3151,2,9*/
	invest.softrat_all_i23 (firstobs=58)
	invest.softrat_all_i23 (firstobs=58)
	invest.softrat_all_i23 (firstobs=58)
	/*NAICS 3161,2,9*/
	invest.softrat_all_i23 (firstobs=58)
	invest.softrat_all_i23 (firstobs=58)
	invest.softrat_all_i23 (firstobs=58)
	/*NAICS 3211,2,9*/
	invest.softrat_all_i8 (firstobs=58)
	invest.softrat_all_i8 (firstobs=58)
	invest.softrat_all_i8 (firstobs=58)
	/*NAICS 3221,2*/
	invest.softrat_all_i24 (firstobs=58)
	invest.softrat_all_i24 (firstobs=58)
	/*NAICS 3231*/
	invest.softrat_all_i25 (firstobs=58)
	/*NAICS 3241*/
	invest.softrat_all_i26 (firstobs=58)
	/*NAICS 3251-6,9*/
	invest.softrat_all_i27 (firstobs=58)
	invest.softrat_all_i27 (firstobs=58)
	invest.softrat_all_i27 (firstobs=58)
	invest.softrat_all_i27 (firstobs=58)
	invest.softrat_all_i27 (firstobs=58)
	invest.softrat_all_i27 (firstobs=58)
	invest.softrat_all_i27 (firstobs=58)
	/*NAICS 3261,2*/
	invest.softrat_all_i28 (firstobs=58)
	invest.softrat_all_i28 (firstobs=58)
	/*NAICS 3271-4,9*/
	invest.softrat_all_i9 (firstobs=58)
	invest.softrat_all_i9 (firstobs=58)
	invest.softrat_all_i9 (firstobs=58)
	invest.softrat_all_i9 (firstobs=58)
	invest.softrat_all_i9 (firstobs=58)
	/*NAICS 3311-5*/
	invest.softrat_all_i10 (firstobs=58)
	invest.softrat_all_i10 (firstobs=58)
	invest.softrat_all_i10 (firstobs=58)
	invest.softrat_all_i10 (firstobs=58)
	invest.softrat_all_i10 (firstobs=58)
	/*NAICS 3321-9*/
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	invest.softrat_all_i11 (firstobs=58)
	/*NAICS 3331-6,9*/
	invest.softrat_all_i12 (firstobs=58)
	invest.softrat_all_i12 (firstobs=58)
	invest.softrat_all_i12 (firstobs=58)
	invest.softrat_all_i12 (firstobs=58)
	invest.softrat_all_i12 (firstobs=58)
	invest.softrat_all_i12 (firstobs=58)
	invest.softrat_all_i12 (firstobs=58)
	/*NAICS 3341-6*/
	invest.softrat_all_i13 (firstobs=58)
	invest.softrat_all_i13 (firstobs=58)
	invest.softrat_all_i13 (firstobs=58)
	invest.softrat_all_i13 (firstobs=58)
	invest.softrat_all_i13 (firstobs=58)
	invest.softrat_all_i13 (firstobs=58)
    /*NAICS 3351,2,3,9*/
	invest.softrat_all_i14 (firstobs=58)
	invest.softrat_all_i14 (firstobs=58)
	invest.softrat_all_i14 (firstobs=58)
	invest.softrat_all_i14 (firstobs=58)
	/*NAICS 3361-3*/
	invest.softrat_all_i15 (firstobs=58)
	invest.softrat_all_i15 (firstobs=58)
	invest.softrat_all_i15 (firstobs=58)
	/*NAICS 3364-9*/
	invest.softrat_all_i16 (firstobs=58)
	invest.softrat_all_i16 (firstobs=58)
	invest.softrat_all_i16 (firstobs=58)
	invest.softrat_all_i16 (firstobs=58)
    /*NAICS 3371,2,9*/
	invest.softrat_all_i17 (firstobs=58)
	invest.softrat_all_i17 (firstobs=58)
	invest.softrat_all_i17 (firstobs=58)
	/*NAICS 3391,9*/
	invest.softrat_all_i18 (firstobs=58)
	invest.softrat_all_i18 (firstobs=58);
run;

/*Applying the software ratio to special tools-adjusted equipment investment*/
data work.capexp_adjusted;
merge work.capexp_adjusted work.all_software;
equipment=equipment2 + equipment2*SoftRat_All;
drop equipment2;
run;

/*breaking out nominal asm investment with adjusted equipment into industry specific datasets*/
%macro loop;
%do indy=1 %to 86;
data invest.capex&&NAICS_Indy&indy;
set work.capexp_adjusted (where=(naics="&&NAICS_Indy&indy"));
drop SoftRat_All;
run;
%end;
%mend loop;
%loop;

/*Repeating the same process as above only on the 2002-forward ASM data. In this data, special tools is removed from the
asset all_other_equipment*/
data work.newcapexp;
set capital.newcapexp;
drop structures total;
run;
proc sort data=work.newcapexp;
by year;
run;
proc transpose data=work.newcapexp out=work.newcapexp_t (drop = _label_);
by year;
var all_other_equipment;
id naics;
run;
/*calculating 3361, 3362, 3363 shares of total investment between the 3 industries*/
data work.newcapexp_t;
set work.newcapexp_t;
total_auto=_3361+_3362+_3363;
share_3361=_3361/total_auto;
share_3362=_3362/total_auto;
share_3363=_3363/total_auto;
run;

data work.nomspt ;
set sptools.special_tools (where =(year>2001));
drop defspt realspt;
run;

data work.newcapexp;
merge work.newcapexp_t work.nomspt;
by year;
run;
/*removing each industry's share of special tools for 1972-forward*/
data work.newcapexp2;
set work.newcapexp;
if year > 1971 then _3361_new=_3361-share_3361*nomspt;
else _3361_new=_3361;
if year > 1971 then _3362_new=_3362-share_3362*nomspt;
else _3362_new=_3362;
if year > 1971 then _3363_new=_3363-share_3363*nomspt;
else _3363_new=_3363;
_3361=_3361_new;
_3362=_3362_new;
_3363=_3363_new;
drop _3361_new _3362_new _3363_new total_auto share_: nomspt _name_;
run;

proc transpose data=work.newcapexp2 out=work.newcapex_adjusted_equip ;
by year;
run;

data work.newcapex_adjusted_equip2 ;
set work.newcapex_adjusted_equip;
naics=substr(_name_,2);
/*converting naics industries and equipment values to numberic*/
all_other_equipment2=col1;
drop _name_ col1;
run;
proc sort data=work.newcapex_adjusted_equip2;
by naics year;
run;
/*Putting the adjusted equipment values back into the original capexp dataset*/
data work.NewCapexp_Adjusted ;
merge capital.newcapexp work.newcapex_adjusted_equip2;
by naics year;
drop all_other_equipment;
run;


/*Putting all BEA software ratios into one dataset in the order of corresponding NAICS industries*/
data work.all_software2002 (rename=(col1=software_ratio));
set 
	/*NAICS 3111-3119*/
	invest.softrat_all_i20 (firstobs=102)
    invest.softrat_all_i20 (firstobs=102)
	invest.softrat_all_i20 (firstobs=102)
    invest.softrat_all_i20 (firstobs=102)
	invest.softrat_all_i20 (firstobs=102)
    invest.softrat_all_i20 (firstobs=102)
	invest.softrat_all_i20 (firstobs=102)
    invest.softrat_all_i20 (firstobs=102)
	invest.softrat_all_i20 (firstobs=102)
    /*NAICS 3121-3122*/
    invest.softrat_all_i20 (firstobs=102)
    invest.softrat_all_i20 (firstobs=102)
    /*NAICS 3131-3133*/
	invest.softrat_all_i22 (firstobs=102)
	invest.softrat_all_i22 (firstobs=102)
	invest.softrat_all_i22 (firstobs=102)
    /*NAICS 3141 3149*/
	invest.softrat_all_i22 (firstobs=102)
	invest.softrat_all_i22 (firstobs=102)
    /*NAICS 3151,2,9*/
	invest.softrat_all_i23 (firstobs=102)
	invest.softrat_all_i23 (firstobs=102)
	invest.softrat_all_i23 (firstobs=102)
	/*NAICS 3161,2,9*/
	invest.softrat_all_i23 (firstobs=102)
	invest.softrat_all_i23 (firstobs=102)
	invest.softrat_all_i23 (firstobs=102)
	/*NAICS 3211,2,9*/
	invest.softrat_all_i8 (firstobs=102)
	invest.softrat_all_i8 (firstobs=102)
	invest.softrat_all_i8 (firstobs=102)
	/*NAICS 3221,2*/
	invest.softrat_all_i24 (firstobs=102)
	invest.softrat_all_i24 (firstobs=102)
	/*NAICS 3231*/
	invest.softrat_all_i25 (firstobs=102)
	/*NAICS 3241*/
	invest.softrat_all_i26 (firstobs=102)
	/*NAICS 3251-6,9*/
	invest.softrat_all_i27 (firstobs=102)
	invest.softrat_all_i27 (firstobs=102)
	invest.softrat_all_i27 (firstobs=102)
	invest.softrat_all_i27 (firstobs=102)
	invest.softrat_all_i27 (firstobs=102)
	invest.softrat_all_i27 (firstobs=102)
	invest.softrat_all_i27 (firstobs=102)
	/*NAICS 3261,2*/
	invest.softrat_all_i28 (firstobs=102)
	invest.softrat_all_i28 (firstobs=102)
	/*NAICS 3271-4,9*/
	invest.softrat_all_i9 (firstobs=102)
	invest.softrat_all_i9 (firstobs=102)
	invest.softrat_all_i9 (firstobs=102)
	invest.softrat_all_i9 (firstobs=102)
	invest.softrat_all_i9 (firstobs=102)
	/*NAICS 3311-5*/
	invest.softrat_all_i10 (firstobs=102)
	invest.softrat_all_i10 (firstobs=102)
	invest.softrat_all_i10 (firstobs=102)
	invest.softrat_all_i10 (firstobs=102)
	invest.softrat_all_i10 (firstobs=102)
	/*NAICS 3321-9*/
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	invest.softrat_all_i11 (firstobs=102)
	/*NAICS 3331-6,9*/
	invest.softrat_all_i12 (firstobs=102)
	invest.softrat_all_i12 (firstobs=102)
	invest.softrat_all_i12 (firstobs=102)
	invest.softrat_all_i12 (firstobs=102)
	invest.softrat_all_i12 (firstobs=102)
	invest.softrat_all_i12 (firstobs=102)
	invest.softrat_all_i12 (firstobs=102)
	/*NAICS 3341-6*/
	invest.softrat_all_i13 (firstobs=102)
	invest.softrat_all_i13 (firstobs=102)
	invest.softrat_all_i13 (firstobs=102)
	invest.softrat_all_i13 (firstobs=102)
	invest.softrat_all_i13 (firstobs=102)
	invest.softrat_all_i13 (firstobs=102)
    /*NAICS 3351,2,3,9*/
	invest.softrat_all_i14 (firstobs=102)
	invest.softrat_all_i14 (firstobs=102)
	invest.softrat_all_i14 (firstobs=102)
	invest.softrat_all_i14 (firstobs=102)
	/*NAICS 3361-3*/
	invest.softrat_all_i15 (firstobs=102)
	invest.softrat_all_i15 (firstobs=102)
	invest.softrat_all_i15 (firstobs=102)
	/*NAICS 3364-9*/
	invest.softrat_all_i16 (firstobs=102)
	invest.softrat_all_i16 (firstobs=102)
	invest.softrat_all_i16 (firstobs=102)
	invest.softrat_all_i16 (firstobs=102)
    /*NAICS 3371,2,9*/
	invest.softrat_all_i17 (firstobs=102)
	invest.softrat_all_i17 (firstobs=102)
	invest.softrat_all_i17 (firstobs=102)
	/*NAICS 3391,9*/
	invest.softrat_all_i18 (firstobs=102)
	invest.softrat_all_i18 (firstobs=102);
run;

/*Applying the software ratio to special tools-adjusted equipment investment*/
data work.NewCapexp_Adjusted;
merge work.NewCapexp_Adjusted work.all_software2002;
all_other_equipment=all_other_equipment2 + all_other_equipment2*SoftRat_All;
drop all_other_equipment2;
run;

/*breaking out nominal asm investment with adjusted equipment into industry specific datasets*/
%macro loop;
%do indy=1 %to 86;
data capital.newcapex&&NAICS_Indy&indy;
set work.NewCapexp_Adjusted (where=(naics="&&NAICS_Indy&indy"));
drop SoftRat_All;
run;
%end;
%mend loop;
%loop;

/***applying asset proportions to nominal investment to create industry specific investment in 24 equipment assets***/
%macro loop;
%do indy=1 %to 86;
	proc transpose data=ras.propnaics&&NAICS_Indy&indy out=work.propnaics&&NAICS_Indy&indy ;
	run;

	data work.capexn1958_2001&&NAICS_Indy&indy;
	merge work.propnaics&&NAICS_Indy&indy (obs=44) invest.capex&&NAICS_Indy&indy (obs=44);
	array asset {24} col1-col24;
	array investment {24} capexp1-capexp24;
		do i=1 to 24;
		investment {i} = asset {i} * equipment;
		end;
	keep capexp: ;
	run;

	data work.newcapexn&&NAICS_Indy&indy;
	merge capital.newcapex&&NAICS_Indy&indy work.propnaics&&NAICS_Indy&indy (firstobs=45);
	capexp1=computers*col1;
	array asset1 {10} col2-col11;
		array investment1 {10} capexp2-capexp11;
			do i=1 to 10;
			investment1 {i} = asset1 {i} * all_other_equipment;
			end;
	capexp12=vehicles*col12;
	capexp13=vehicles*col13;
	array asset2 {11} col14-col24;
		array investment2 {11} capexp14-capexp24;
			do i=1 to 11;
			investment2 {i} = asset2 {i} * all_other_equipment;
			end;
	keep capexp:;
	run;

	data capital.capexn&&NAICS_Indy&indy;
	set work.capexn1958_2001&&NAICS_Indy&indy work.newcapexn&&NAICS_Indy&indy;
	run;
%end;
%mend loop;
%loop;

/*************** Applying detailed ACES proportions to ASM structure investment******************/

%macro loop;
%do indy=1 %to 86;
/*Holding the 1958 ACES structure proportions constant back to 1890*/
data work.propnaicstr&&NAICS_Indy&indy;
set ras.propnaicstr&&NAICS_Indy&indy;
	array years {68} propnaicstr_1890-propnaicstr_1957;
	do i=1 to 68;
	years {i} = propnaicstr_1958;
	end;
drop i;
run;

proc transpose data=work.propnaicstr&&NAICS_Indy&indy out=work.propnaicstr&&NAICS_Indy&indy ;
	run;
proc sort data=work.propnaicstr&&NAICS_Indy&indy;
by _name_;
run;

/*Linking the historical 1890-1958 structures investment to ASM structure investment*/
proc sort data=capital.naicspre1958structures;
by naics;
run;

proc transpose data=capital.naicspre1958structures out=work.structures_pre1958 (drop=_label_);
var structures;
by naics;
id year;
run;

data work.asm_structures1958;
set capital.naicscapexp (where=(year=1958));
keep naics year structures;
run;
proc sort data=work.asm_structures1958;
by naics;
run;

proc transpose data=work.asm_structures1958 out=work.asm_structures1958_2 (drop=_label_);
var structures;
by naics;
id year;
run;

/*Putting historical and ASM 1958 values together to create a link ratio, then applying the ratio back to 1890*/
data work.historical_Structures;
merge work.asm_structures1958 work.structures_pre1958;
by naics;
ASM_link=structures/_1958;
array years {68} linked_1890-linked_1957;
array original {68} _1890-_1957;
 do i=1 to 68;
 years {i}= original {i} * asm_link;
 end;
keep naics linked:;
run;

proc transpose data=work.historical_structures out=work.historical_structures2 (rename=(col1=structures));
by naics;
run;

/*Applying ACES structure proportions for 10 assets to nominal investment*/
	data work.capexnstr1890_1957&&NAICS_Indy&indy;
	merge work.propnaicstr&&NAICS_Indy&indy (obs=68) work.historical_structures2 (where=(naics="&&NAICS_Indy&indy"));
	if year=1958 then delete;
	array asset {10} col1-col10;
	array investment {10} capexpstr1-capexpstr10;
		do i=1 to 10;
		investment {i} = asset {i} * Structures;
		end;
	keep capexp: _name_;
	run;

	data work.capexnstr1958_2001&&NAICS_Indy&indy;
	merge work.propnaicstr&&NAICS_Indy&indy (firstobs=69 obs=112) invest.capex&&NAICS_Indy&indy (obs=44);
	array asset {10} col1-col10;
	array investment {10} capexpstr1-capexpstr10;
		do i=1 to 10;
		investment {i} = asset {i} * Structures;
		end;
	keep capexp: _name_;
	run;

	data work.newcapexnstr&&NAICS_Indy&indy;
	merge capital.newcapex&&NAICS_Indy&indy work.propnaicstr&&NAICS_Indy&indy (firstobs=113);
	capexp1=computers*col1;
	array asset {10} col1-col10;
	array investment {10} capexpstr1-capexpstr10;
		do i=1 to 10;
		investment {i} = asset {i} * Structures;
		end;
	keep capexpstr: _name_;
	run;
/*merging historical investment with 1958-forward and deleting years 1890-1900 */
	data work.capexnstr&&NAICS_Indy&indy;
	set work.capexnstr1890_1957&&NAICS_Indy&indy work.capexnstr1958_2001&&NAICS_Indy&indy work.newcapexnstr&&NAICS_Indy&indy;
	%macro remove;
		%do year=1890 %to 1900;
		if _name_="linked_&year" then delete;
		%end;
	%mend remove;
	%remove;
	year=substr(_name_,8);
	drop _name_;
	run;
%end;
%mend loop;
%loop;

 proc copy in= work
			out= capital;
			select  capexnstr3111	capexnstr3112	capexnstr3113	capexnstr3114	capexnstr3115	capexnstr3116	
			capexnstr3117	capexnstr3118	capexnstr3119	capexnstr3121	capexnstr3122	capexnstr3131	capexnstr3132	
			capexnstr3133	capexnstr3141	capexnstr3149	capexnstr3151	capexnstr3152	capexnstr3159	capexnstr3161	
			capexnstr3162	capexnstr3169	capexnstr3211	capexnstr3212	capexnstr3219	capexnstr3221	capexnstr3222	
			capexnstr3231	capexnstr3241	capexnstr3251	capexnstr3252	capexnstr3253	capexnstr3254	capexnstr3255	
			capexnstr3256	capexnstr3259	capexnstr3261	capexnstr3262	capexnstr3271	capexnstr3272	capexnstr3273	
			capexnstr3274	capexnstr3279	capexnstr3311	capexnstr3312	capexnstr3313	capexnstr3314	capexnstr3315	
			capexnstr3321	capexnstr3322	capexnstr3323	capexnstr3324	capexnstr3325	capexnstr3326	capexnstr3327	
			capexnstr3328	capexnstr3329	capexnstr3331	capexnstr3332	capexnstr3333	capexnstr3334	capexnstr3335	
			capexnstr3336	capexnstr3339	capexnstr3341	capexnstr3342	capexnstr3343	capexnstr3344	capexnstr3345	
			capexnstr3346	capexnstr3351	capexnstr3352	capexnstr3353	capexnstr3359	capexnstr3361	capexnstr3362	
			capexnstr3363	capexnstr3364	capexnstr3365	capexnstr3366	capexnstr3369	capexnstr3371	capexnstr3372	
			capexnstr3379	capexnstr3391	capexnstr3399;
run;
