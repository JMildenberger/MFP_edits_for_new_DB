/* All Domestic Deflators to IO Level - for Price of Services & Price of Materials
   Created by: Jennifer Kim
   Last modified: January 29, 2018 */		

/* This program aggregates All Domestic Deflators to the IO Level for Price of Services and Price of Materials.
   The verified historical file 1987-2012 is locked down. For 2012-&lastyr, we will TQ aggregate, chain-link, then 
   attach to the historical file. Finally, we will rebase to 1987=100. */

libname IP 'Q:\MFP\SAS Libraries\Manufacturing\IP';

/*Creates macro variable from textfile*/
data _null_;
      length dataset $29;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input dataset firstyr lastyr baseperiod;
      call symput('lastyr', trim(left(put(lastyr, 4.))));
run;

/* Read in Excel input files from R: drive */
proc import out=work.IO_Deflators_hist
			datafile="R:\MFP Datasets\Manufacturing\IP\Inputs\All Deflators IO Level (1987-2012).xlsx"
			dbms=excel replace;
			sheet=IO_Deflators_hist;
run;

proc import out=work.Deflators
			datafile="R:\MFP Datasets\Manufacturing\IP\Inputs\All Deflator Commodities.xlsx"
			dbms=excel replace;
			sheet=Deflators;
run;

proc import out=work.Revenues
			datafile="R:\MFP Datasets\Manufacturing\IP\Inputs\All Revenue Commodities.xlsx"
			dbms=excel replace;
			sheet=Revenues;
run;

/* Flatten 2012-&lastyr file */
%macro flatten;
Proc sql;
      Create table deflators2 as
      %do year = 2012 %to %eval(&lastyr.-1);
      Select IO, NAICS, &year as Year, y&year as Value from work.deflators union all
      %end;
      Select IO, NAICS, &year as Year, y&year as Value from work.deflators;

	  Create table revenues2 as
      %do year = 2012 %to %eval(&lastyr.-1);
      Select IO, NAICS, &year as Year, y&year as Value from work.revenues union all
      %end;
      Select IO, NAICS, &year as Year, y&year as Value from work.revenues;
quit;
%mend flatten;
%flatten;

/* Flatten 1987-2012 historical file */
%macro flatten2;
Proc sql;
      Create table IO_deflators_hist2 as
      %do year = 1987 %to (2012-1);
      Select IO, &year as Year, y&year as Value from work.IO_deflators_hist union all
      %end;
      Select IO, &year as Year, y&year as Value from work.IO_deflators_hist;
quit;
%mend flatten2;
%flatten2;

/* All Deflator Commodities: Take difference in logs. */
proc sql;
	create table	work.deflogdif as
	select			a.IO, a.NAICS, a.Year, log(a.Value/b.Value) as deflogdif
	from			work.deflators2 a 
	left join 		work.deflators2 b
	on				a.NAICS=b.NAICS and a.IO=b.IO and a.Year-1=b.Year;
quit;

/* All Revenue Commodities: Find average shares for NAICS revenues within each IO Code */
proc sql;
	create table	work.revenues3 as
	select			IO, NAICS, Year, sum(Value) as TotRev, (Value/calculated TotRev) as Rev_share
	from			work.revenues2
	group by		IO, Year;
quit;

proc sql;
	create table	work.revenues4 as
	select			a.IO, a.NAICS, a.Year, (a.Rev_share + b.Rev_share)/2 as avg_share
	from			work.revenues3 a
	left join		work.revenues3 b
	on				a.NAICS=b.NAICS and a.IO=b.IO and a.Year-1=b.Year;
quit;

/* Multiply avg revenue share by deflatorlogdif, sum by IO code, then exponentiate */
proc sql;
	create table	work.IO_deflators as
	select			a.IO, a.NAICS, a.Year, (a.avg_share*b.deflogdif) as value
	from			work.revenues4 a, work.deflogdif b
	where			a.NAICS=b.NAICS and a.IO=b.IO and a.Year=b.Year;
quit;

proc sql;
	create table	work.IO_deflators2 as
	select			IO, Year, sum(value) as IO_value, exp(calculated IO_value) as value
	from			work.IO_deflators
	group by		IO, Year;
quit;

/* Chain-linking 2012-&lastyr IO deflators */
%macro chain;
Proc sql;
Create table 	work.IO_deflators3 as
Select 			a.IO, a.Year,
				case when a.year=2012 then 100
				%do i = 2013 %to &lastyr.;
					when a.Year=&i then
					%do b = &i %to 2013 %by -1;
						_&b..Value*
					%end;
					100
				%end;
				end as Value
from 			work.IO_deflators2 a
				%do c = 2013 %to &lastyr.;
					left join work.IO_deflators2 _&c on (a.IO=_&c..IO) and _&c..year=&c
				%end;
order by 		IO, Year;
quit;
%mend chain;
%chain;

/* Rebase historical 1987-2012 file to 2012=100 */
proc sql;
	create table	work.IO_deflators_hist3 as
	select			a.IO, a.Year, (a.value/b.value)*100 as value
	from			work.IO_deflators_hist2 a
	inner join		work.IO_deflators_hist2 b
	on				a.IO=b.IO and b.Year=2012;
quit;

/* Link historical 1987-2012 IO file to new 2012-&lastyr IO file. */ 
proc sql;
	create table	work.IO_deflators4 as
	select			* from IO_deflators_hist3 a
	union			
	select			* from IO_deflators3 b;
quit;

/* Rebase to 1987=100 */
proc sql;
	create table	work.IO_deflators_all as
	select			a.IO, a.Year, (a.value/b.value)*100 as Value
	from			work.IO_deflators4 a
	inner join		work.IO_deflators4 b
	on				a.IO=b.IO and b.Year=1987;
quit;

/* Export to IP SAS library */
data IP.IO_deflators_all;
	set work.IO_deflators_all;
run;

/* Export to Excel for analysis & verification */
proc export data=work.IO_deflators_all
			outfile="Q:\MFP\Manufacturing\IP\IP Output\IO_deflators_all.xlsx"
			dbms=xlsx replace;
			sheet="IO_deflators_all";
run;
