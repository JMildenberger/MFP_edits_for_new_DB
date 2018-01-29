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

/*Creating a macro variable for the update year*/
 data _null_;
      length dataset $29;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input dataset firstyr lastyr baseperiod;
      call symput('last', trim(left(put(lastyr, 4.))));
run;
 %put &last;

/*Creating column totals for each year*/
data work.aces_column_totals;
merge ras.aces_bime capital.allyears;
run;

%macro equip;
%do year=1958 %to &last;
data work.aces_equip_column_totals_&year;
set work.aces_column_totals (where=(years=&year));
drop years;
run;
%end;
%mend equip;
%equip;


/*truncating CDEY to be from 1958-forward*/
data work.cdey;
set ras.cdey;
drop _1947-_1957;
run;

%macro equip2;
%do year=1958 %to &last;
data work.equip_row_totals_&year;
set work.cdey;
if _&year= . then _&year=0;
keep _&year;
run;
%end;
%mend equip2;
%equip2;

/*********************************Equipment RAS to 2008 ACES 1958-forward********************/
%macro loop ;
%do year=1958 %to &last;
proc iml;
/*2008 Detailed ACES*/
use capital.aces_2008_equip;
read all into a;
/*ROW TOTALS*/
use work.equip_row_totals_&year;
read all into un;
/*COLUMN TOTALS*/
use work.aces_equip_column_totals_&year;
read all into v;

/* sum across columns  */
TOTCOL = V[,+];

/* sum across rows */
TREY = UN[+,];
TOTROW =t(trey);

/* totrow and totcol should be equal; if they are not - needs to be solved*/
equal = totcol-totrow;

/* creating adjustment factor to make totcol and totrow equal - as is necessary for ras procedure*/
adjfac = totrow/totcol;

/*element wise multiplication of adjument factor and BIME columns*/
Vn = V#adjfac;
TOTCOL2 = Vn[,+];
/* making sure element wise adjument created equal totrow and totcol - now totcol2*/ 
equal=totcol2 - totrow;


row_a=nrow(a);
col_a=ncol(a);
do i=1 to row_a;
do j=1 to col_a;
if a[i,j]= 0 then a[i,j]=0.0000000001;
end;
end;

count = 1;
do while(count<=50);
count = count+1;
ud = a[,+];


/* ensuring no zero variables in U and V - RAS would not work*/
nu = NCOL(un);
nr = nrow(un);
do i = 1 to nr; 
do j = 1 to nu;
if un[i,j]=0 then un[i,j] = .0000000001; 
end;
end;
r = un/ud;
r2 = diag(r);
a1 = r2*a;
vd = a1[+,];



/* ensuring no zero variables in U and V - RAS would not work*/
nv=NCOL(vn);
rv = NROW(vn);
do i= 1 to rv;
do j= 1 to nv;
if vn[i,j] = 0 then vn[i,j] = .0000000001;
end;
end;
s = vn/vd;
s2= diag(s);
a = a1*s2;
/*print a;
print r;
print s;*/
end;

create work.ACES_2008_results_&year from a;
append from a;

quit;

/*making each ACES asset a column so that props can be calculated*/
proc transpose data=work.ACES_2008_results_&year out=work.aces_2008_&year._props (drop=_name_);
run;
%end;
%mend loop;
%loop;

/*Calculating props for 1958-2001 to match the ASM total equipment expenditures*/
%macro loop2;
%do year=1958 %to 2001;
data work.aces_2008_rme&year;
set work.aces_2008_&year._props;
total= sum (of col:);
array industries (24) col1-col24;
array assets_percent (24) asset_percent1-asset_percent24;
	do i=1 to 24;
	assets_percent {i} = industries {i} / total;
	end;
keep asset_percent:;
run;

proc transpose data=work.aces_2008_rme&year out=ras.aces_2008_rme&year (drop=_name_);
run;

%end; 
%mend loop2;
%loop2;

/*Calculating props for 2002-forward to match the ASM categories of computers, autos and all other
  equipment expenditures*/
%macro loop3;
%do year=2002 %to &last;
data work.aces_2008_&year._props;
set work.aces_2008_&year._props;
total_all= sum (of col:);
adjusted_total= total_all - col1 - col12 - col13;
autos_total=col12 + col13;

asset_percent1 = col1 / col1;

array assets2_11 (10)  col2-col11;
array asset_percent2_11 (10)  asset_percent2 - asset_percent11;
	do i=1 to 10;
	asset_percent2_11 {i} = assets2_11 {i} / adjusted_total;
	end;

asset_percent12= col12 / autos_total;
asset_percent13= col13 / autos_total;

array assets14_24 (11)  col14-col24;
array asset_percent14_24 (11)  asset_percent14 - asset_percent24;
	do i=1 to 11;
	asset_percent14_24 {i} = assets14_24 {i} / adjusted_total;
	end;

keep asset_percent:;
run;

/*transposing final props so that years are columns and assets are rows*/
proc transpose data=work.aces_2008_&year._props out=ras.aces_2008_rme&year (drop=_name_);
run;

%end;
%mend loop3;
%loop3;


/*Creating column totals for each year*/
data work.aces_struct_col_totals;
merge ras.aces_bims capital.allyears;
run;

%macro equip;
%do year=1958 %to &last;
data work.aces_struct_column_totals_&year;
set work.aces_struct_col_totals (where=(years=&year));
drop years;
run;
%end;
%mend equip;
%equip;


/*truncating CDSY to be from 1958-forward*/
data work.cdsy;
set ras.cdSy;
drop _1901-_1957;
run;

%macro equip2;
%do year=1958 %to &last;
data work.aces_struct_row_totals_&year;
set work.cdsy;
keep _&year;
run;
%end;
%mend equip2;
%equip2;

/*********************************Structures RAS to 2008 ACES 1958-forward********************/
%macro loop ;
%do year=1958 %to &last;
proc iml;

use capital.ACES_2008_Structures;
read all into a;
/*ROW TOTALS*/
use work.aces_struct_row_totals_&year;
read all into un;
/*COLUMN TOTALS*/
use work.aces_struct_column_totals_&year;
read all into v;

/* sum across columns  */
TOTCOL = V[,+];
/* sum across rows */
TREY = UN[+,];
TOTROW =t(trey);

/* totrow and totcol should be equal; if they are not - needs to be solved*/
equal = totcol-totrow;

/* creating adjustment factor to make totcol and totrow equal - as is necessary for ras procedure*/
adjfac = totrow/totcol;

/*element wise multiplication of adjument factor and BIME columns*/
Vn = V#adjfac;
TOTCOL2 = Vn[,+];
/* making sure element wise adjument created equal totrow and totcol - now totcol2*/ 
equal=totcol2 - totrow;


row_a=nrow(a);
col_a=ncol(a);
do i=1 to row_a;
do j=1 to col_a;
if a[i,j]= 0 then a[i,j]=0.0000000001;
end;
end;

count = 1;
do while(count<=50);
count = count+1;
ud = a[,+];


/* ensuring no zero variables in U and V - RAS would not work*/
nu = NCOL(un);
nr = nrow(un);
do i = 1 to nr; 
do j = 1 to nu;
if un[i,j]=0 then un[i,j] = .0000000001; 
end;
end;
r = un/ud;
r2 = diag(r);
a1 = r2*a;
vd = a1[+,];



/* ensuring no zero variables in U and V - RAS would not work*/
nv=NCOL(vn);
rv = NROW(vn);
do i= 1 to rv;
do j= 1 to nv;
if vn[i,j] = 0 then vn[i,j] = .0000000001;
end;
end;
s = vn/vd;
s2= diag(s);
a = a1*s2;
/*print a;
print r;
print s;*/
end;

create work.ACES_2008_struct_results_&year from a;
append from a;

quit;

/*making each ACES asset a column so that props can be calculated*/
proc transpose data=work.ACES_2008_struct_results_&year out=work.aces_2008_struct_&year._props (drop=_name_);
run;
%end;
%mend loop;
%loop;

/*Calculating props for 1958-forward to match the ASM total equipment expenditures*/
%macro loop2;
%do year=1958 %to &last;
data work.aces_2008_rms&year;
set work.aces_2008_struct_&year._props;
total= sum (of col:);
array industries (*) col1-col10;
array assets_percent (*) asset_percent1-asset_percent10;
	do i=1 to 10;
	assets_percent {i} = industries {i} / total;
	end;
keep asset_percent:;
run;

proc transpose data=work.aces_2008_rms&year out=ras.aces_2008_rms&year (drop=_name_);
run;

%end; 
%mend loop2;
%loop2;

/*********************************Equipment RAS to 2012 ACES 1958-forward********************/
%macro loop ;
%do year=1958 %to &last;
proc iml;
/*2012 Detailed ACES*/
use capital.aces_2012_equip;
read all into a;
/*ROW TOTALS*/
use work.equip_row_totals_&year;
read all into un;
/*COLUMN TOTALS*/
use work.aces_equip_column_totals_&year;
read all into v;

/* sum across columns  */
TOTCOL = V[,+];
/* sum across rows */
TREY = UN[+,];
TOTROW =t(trey);

/* totrow and totcol should be equal; if they are not - needs to be solved*/
equal = totcol-totrow;

/* creating adjustment factor to make totcol and totrow equal - as is necessary for ras procedure*/
adjfac = totrow/totcol;

/*element wise multiplication of adjument factor and BIME columns*/
Vn = V#adjfac;
TOTCOL2 = Vn[,+];
/* making sure element wise adjument created equal totrow and totcol - now totcol2*/ 
equal=totcol2 - totrow;


row_a=nrow(a);
col_a=ncol(a);
do i=1 to row_a;
do j=1 to col_a;
if a[i,j]= 0 then a[i,j]=0.0000000001;
end;
end;

count = 1;
do while(count<=50);
count = count+1;
ud = a[,+];


/* ensuring no zero variables in U and V - RAS would not work*/
nu = NCOL(un);
nr = nrow(un);
do i = 1 to nr; 
do j = 1 to nu;
if un[i,j]=0 then un[i,j] = .0000000001; 
end;
end;
r = un/ud;
r2 = diag(r);
a1 = r2*a;
vd = a1[+,];



/* ensuring no zero variables in U and V - RAS would not work*/
nv=NCOL(vn);
rv = NROW(vn);
do i= 1 to rv;
do j= 1 to nv;
if vn[i,j] = 0 then vn[i,j] = .0000000001;
end;
end;
s = vn/vd;
s2= diag(s);
a = a1*s2;
/*print a;
print r;
print s;*/
end;

create work.ACES_2012_results_&year from a;
append from a;

quit;

/*making each ACES asset a column so that props can be calculated*/
proc transpose data=work.ACES_2012_results_&year out=work.aces_2012_&year._props (drop=_name_);
run;
%end;
%mend loop;
%loop;

/*Calculating props for 1958-2001 to match the ASM total equipment expenditures*/
%macro loop2;
%do year=1958 %to 2001;
data work.aces_2012_rme&year;
set work.aces_2012_&year._props;
total= sum (of col:);
array industries (24) col1-col24;
array assets_percent (24) asset_percent1-asset_percent24;
	do i=1 to 24;
	assets_percent {i} = industries {i} / total;
	end;
keep asset_percent:;
run;

proc transpose data=work.aces_2012_rme&year out=ras.aces_2012_rme&year (drop=_name_);
run;

%end; 
%mend loop2;
%loop2;

/*Calculating props for 2002-forward to match the ASM categories of computers, autos and all other
  equipment expenditures*/
%macro loop3;
%do year=2002 %to &last;
data work.aces_2012_&year._props;
set work.aces_2012_&year._props;
total_all= sum (of col:);
adjusted_total= total_all - col1 - col12 - col13;
autos_total=col12 + col13;

asset_percent1 = col1 / col1;

array assets2_11 (10)  col2-col11;
array asset_percent2_11 (10)  asset_percent2 - asset_percent11;
	do i=1 to 10;
	asset_percent2_11 {i} = assets2_11 {i} / adjusted_total;
	end;

asset_percent12= col12 / autos_total;
asset_percent13= col13 / autos_total;

array assets14_24 (11)  col14-col24;
array asset_percent14_24 (11)  asset_percent14 - asset_percent24;
	do i=1 to 11;
	asset_percent14_24 {i} = assets14_24 {i} / adjusted_total;
	end;

keep asset_percent:;
run;

/*transposing final props so that years are columns and assets are rows*/
proc transpose data=work.aces_2012_&year._props out=ras.aces_2012_rme&year (drop=_name_);
run;

%end;
%mend loop3;
%loop3;


/*Creating column totals for each year*/
data work.aces_struct_col_totals;
merge ras.aces_bims capital.allyears;
run;

%macro equip;
%do year=1958 %to &last;
data work.aces_struct_column_totals_&year;
set work.aces_struct_col_totals (where=(years=&year));
drop years;
run;
%end;
%mend equip;
%equip;


/*truncating CDEY to be from 1958-forward*/
data work.cdsy;
set ras.cdSy;
drop _1901-_1957;
run;

%macro equip2;
%do year=1958 %to &last;
data work.aces_struct_row_totals_&year;
set work.cdsy;
keep _&year;
run;
%end;
%mend equip2;
%equip2;

/*********************************Structures RAS to 2012 ACES 1958-forward********************/
%macro loop ;
%do year=1958 %to &last;
proc iml;

use capital.ACES_2012_Structures;
read all into a;
/*ROW TOTALS*/
use work.aces_struct_row_totals_&year;
read all into un;
/*COLUMN TOTALS*/
use work.aces_struct_column_totals_&year;
read all into v;

/* sum across columns  */
TOTCOL = V[,+];
/* sum across rows */
TREY = UN[+,];
TOTROW =t(trey);

/* totrow and totcol should be equal; if they are not - needs to be solved*/
equal = totcol-totrow;

/* creating adjustment factor to make totcol and totrow equal - as is necessary for ras procedure*/
adjfac = totrow/totcol;

/*element wise multiplication of adjument factor and BIME columns*/
Vn = V#adjfac;
TOTCOL2 = Vn[,+];
/* making sure element wise adjument created equal totrow and totcol - now totcol2*/ 
equal=totcol2 - totrow;


row_a=nrow(a);
col_a=ncol(a);
do i=1 to row_a;
do j=1 to col_a;
if a[i,j]= 0 then a[i,j]=0.0000000001;
end;
end;

count = 1;
do while(count<=50);
count = count+1;
ud = a[,+];


/* ensuring no zero variables in U and V - RAS would not work*/
nu = NCOL(un);
nr = nrow(un);
do i = 1 to nr; 
do j = 1 to nu;
if un[i,j]=0 then un[i,j] = .0000000001; 
end;
end;
r = un/ud;
r2 = diag(r);
a1 = r2*a;
vd = a1[+,];



/* ensuring no zero variables in U and V - RAS would not work*/
nv=NCOL(vn);
rv = NROW(vn);
do i= 1 to rv;
do j= 1 to nv;
if vn[i,j] = 0 then vn[i,j] = .0000000001;
end;
end;
s = vn/vd;
s2= diag(s);
a = a1*s2;
/*print a;
print r;
print s;*/
end;

create work.ACES_2012_struct_results_&year from a;
append from a;

quit;

/*making each ACES asset a column so that props can be calculated*/
proc transpose data=work.ACES_2012_struct_results_&year out=work.aces_2012_struct_&year._props (drop=_name_);
run;
%end;
%mend loop;
%loop;

/*Calculating props for 1958-forward to match the ASM total equipment expenditures*/
%macro loop2;
%do year=1958 %to &last;
data work.aces_2012_rms&year;
set work.aces_2012_struct_&year._props;
total= sum (of col:);
array industries (*) col1-col10;
array assets_percent (*) asset_percent1-asset_percent10;
	do i=1 to 10;
	assets_percent {i} = industries {i} / total;
	end;
keep asset_percent:;
run;

proc transpose data=work.aces_2012_rms&year out=ras.aces_2012_rms&year (drop=_name_);
run;

%end; 
%mend loop2;
%loop2;

/*********************************Equipment RAS for ASM Assets 1958-forward********************/
/*Creating column totals for each year*/
data work.cft_column_totals;
merge ras.bime capital.allyears;
run;

%macro equip;
%do year=1958 %to &last;
data work.cft_equip_column_totals_&year;
set work.cft_column_totals (where=(years=&year));
drop years;
run;
%end;
%mend equip;
%equip;

/*RAS*/
%macro RAS ;
%do year=1958 %to &last;
proc iml;

use capital.equipimat;
read all into equipimat;

/*combining "photocopy and related quipemnt" and "office and account equipment" to match ACES "office equipment except
computers and peripherals total; combinging "ships and boats" and "railroad equipment" to match ACES "other transportation
equipement".*/
office_equip=equipimat[2,]+equipimat[6,];
other_transport=equipimat[17,]+equipimat[18,];
a=equipimat[1,]//office_equip//equipimat[4:5,]//equipimat[14,]//equipimat[13,]//equipimat[3,]//equipimat[7,]//
  equipimat[9:11,]//equipimat[15,]//equipimat[27,]//equipimat[16,]//other_transport//equipimat[8,]//equipimat[12,]//
  equipimat[24,]//equipimat[22,]//equipimat[19:21,]//equipimat[23,]//equipimat[25,];

row_a=nrow(a);
col_a=ncol(a);
do i=1 to row_a;
do j=1 to col_a;
if a[i,j]= 0 then a[i,j]=0.0000000001;
end;
end;

/*ROW TOTALS*/
use work.equip_row_totals_&year;
read all into un;
/*COLUMN TOTALS*/
use work.cft_equip_column_totals_&year;
read all into v;

/* sum across columns  */
TOTCOL = V[,+];
/* sum across rows */
TREY = UN[+,];
TOTROW =t(trey);

/* totrow and totcol should be equal; if they are not - needs to be solved*/
equal = totcol-totrow;

/* creating adjustment factor to make totcol and totrow equal - as is necessary for ras procedure*/
adjfac = totrow/totcol;

/*element wise multiplication of adjument factor and BIME columns*/
Vn = V#adjfac;
TOTCOL2 = Vn[,+];
/* making sure element wise adjument created equal totrow and totcol - now totcol2*/ 
equal=totcol2 - totrow;

count = 1;
do while(count<=50);
count = count+1;
ud = a[,+];

/* ensuring no zero variables in U and V - RAS would not work*/
nu = NCOL(un);
nr = nrow(un);
do i = 1 to nr; 
do j = 1 to nu;
if un[i,j]=0 then un[i,j] = .0000000001; 
end;
end;
r = un/ud;
r2 = diag(r);
a1 = r2*a;
vd = a1[+,];



/* ensuring no zero variables in U and V - RAS would not work*/
nv=NCOL(vn);
rv = NROW(vn);
do i= 1 to rv;
do j= 1 to nv;
if vn[i,j] = 0 then vn[i,j] = .0000000001;
end;
end;
s = vn/vd;
s2= diag(s);
a = a1*s2;
/*print a;
print r;
print s;*/
end;

create work.equip_results_&year from a;
append from a;

quit;

/*making each asset a column so that props can be calculated*/
proc transpose data=work.equip_results_&year out=work.equip_&year._props (drop=_name_);
run;
%end;
%mend ras;
%ras;

/*Calculating props for 1958-2001 to match the ASM total equipment expenditures*/
%macro loop2;
%do year=1958 %to 2001;
data work.equip&year;
set work.equip_&year._props;
total= sum (of col:);
array industries (24) col1-col24;
array assets_percent (24) asset_percent1-asset_percent24;
	do i=1 to 24;
	assets_percent {i} = industries {i} / total;
	end;
keep asset_percent:;
run;

proc transpose data=work.equip&year out=ras.cft_rme&year (drop=_name_);
run;

%end; 
%mend loop2;
%loop2;

/*Calculating props for 2002-forward to match the ASM total equipment expenditures*/
%macro loop3;
%do year=2002 %to &last;
data work.equip&year;
set work.equip_&year._props;
total_all= sum (of col:);
adjusted_total= total_all - col1 - col12 - col13;
autos_total=col12+col13;

asset_percent1=col1/col1;

array industries (10) col2-col11;
array assets_percent (10) asset_percent2-asset_percent11;
	do i=1 to 10;
	assets_percent {i} = industries {i} / adjusted_total;
	end;

asset_percent12=col12/autos_total;
asset_percent13=col13/autos_total;

array industries2 (11) col14-col24;
array assets_percent2 (11) asset_percent14-asset_percent24;
	do i=1 to 11;
	assets_percent2 {i} = industries2 {i} / adjusted_total;
	end;

keep asset_percent:;
run;

proc transpose data=work.equip&year out=ras.cft_rme&year (drop=_name_);
run;

%end; 
%mend loop3;
%loop3;
