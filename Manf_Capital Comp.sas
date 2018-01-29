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

/*Connects to IPS2 database*/
LIBNAME SQL ODBC DSN=IPSTestDB schema=sas;

/*Creating a macro variable for the update year*/
 data _null_;
      length dataset $29;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input dataset firstyr lastyr baseperiod;
      call symput('dataset',trim(dataset));
      call symput('last', trim(left(put(lastyr, 4.))));
run;
%put &dataset;
%put &last;

 /*Creating macro variables for the names of NAICS Industries*/
data _null_;
set capital.indys nobs=x;
      call symputx ("NAICS_Indy"!!left(_n_),NAICS);
 run;

 /*getting the latest values from IPS
   Valprod = T30
   Lcomp   = L02
   ImprDef = T05*/
data work.ips_data;
set &dataset (where=(dataseriesid="T30" or dataseriesid="L02" or
                      dataseriesid="T05"));
NAICS=Industry;
keep year value dataseriesid industryid industry naics;
run;

/*Creating a Valprod Dataset*/
proc sql;
 	create table work.Valprod as
	select a.naics, b.naics, b.year, b.value, b.dataseriesid
	from capital.indys a
	inner join work.ips_data b
	on a.naics=b.naics
	where b.dataseriesid="T30";
quit;
/*Creating a Lcomp Dataset*/
proc sql;
 	create table work.Lcomp as
	select a.naics, b.naics, b.year, b.value, b.dataseriesid
	from capital.indys a
	inner join work.ips_data b
	on a.naics=b.naics
	where b.dataseriesid="L02";
quit;
/*Creating a ImprDef Dataset*/
proc sql;
 	create table work.ImprDef as
	select a.naics, b.naics, b.year, b.value, b.dataseriesid
	from capital.indys a
	inner join work.ips_data b
	on a.naics=b.naics
	where b.dataseriesid="T05";
quit;

proc sort data=work.valprod;
by naics year;
run;
proc transpose data=work.valprod out=final.ValProd (drop=_name_ _label_) prefix=Valprod_;
by naics;
id year;
var value;
run;
proc sort data=work.Lcomp;
by naics year;
run;
proc transpose data=work.Lcomp out=Final.Lcomp (drop=_name_ _label_)prefix=Lcomp_;
by naics;
id year;
var value;
run;

proc sort data=work.imprdef;
by naics year;
run;
proc transpose data=work.imprdef out=work.imprdef2 (drop=_name_ _label_);
by naics;
id year;
var value;
run;
/*Rebasing Imprdef to 1997*/
data deflator.ImpLPI4D;
set work.imprdef2;
%macro rebase;
%do year=1987 %to &last;
ImprDef_&year=_&year/_1997*100;
%end;
%mend rebase;
%rebase;
keep naics ImprDef_:;
run;

/*Making sure the NAICS variable from IP is text*/
data work.ipcomp (rename=(naics=naics2));
set ip.ipcomp;
run;
data work.ipcomp;
retain naics;
set work.ipcomp;
if Vtype(naics2)="N" then NAICS=put(naics2,4.);
Else NAICS=NAICS2;
%macro loop;
%do year=1987 %to &last;
IPComp_&year=y&year;
%end;
%mend loop;
%loop;
drop naics2 y:;
run;

/*Calculating CapComp*/
data comp.capcom;
merge final.valprod final.lcomp work.ipcomp;
by naics;
%macro loop;
%do year=1987 %to &last;
CapComp_&year=Valprod_&year - Lcomp_&year - IPComp_&year;
if CapComp_&year <0 then CapComp_&year = 1;
%end;
%mend loop;
%loop;
keep naics capcomp:;
run;

data comp.negative_capcomp;
set comp.capcom;
%macro loop;
%do year=1987 %to &last;
if CapComp_&year =1 then Count_&year = 1;
%end;
%mend loop;
%loop;
Sum_of_Negative_CapComps= sum(of count_:);
keep Sum_of_Negative_CapComps;
run;
/*For use in the MFP SAS program*/
data comp.capcomp;
set comp.capcom;
%macro loop;
%do year=1987 %to &last;
y&year =CapComp_&year;
%end;
%mend loop;
%loop;
keep naics y:;
run;
/*Transposing CapComp so that year are rows. This is for rental prices in step 10*/
proc transpose data=comp.capcom out=work.capcom2 prefix=CapComp_;
id naics;
run;
data comp.capcom2;
set work.capcom2;
Year=substr(_name_,9)*1;
drop _name_;
run;
