/*Price of Services
  Created by: Mike Manley
  Modified by: Jennifer Kim
  Last modified: May 18, 2017 */

/*Necessary input files:  a.) Service Deflators
						  b.) All BEA IO Tables (1997, 2002, 2007 currently)
						  c.) Commodity Classification */

dm wpgm 'clear log' wpgm;
libname IP "Q:\MFP\SAS Libraries\Manufacturing\IP";
%let iopath=R:\MFP DataSets\Manufacturing\IP\Inputs\IO Tables\;

/* Creates macro variable from textfile*/
data _null_;
      length updateid 3 firstyr 4 lastyr 4 baseperiod 3;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input updateid firstyr lastyr baseperiod;
      call symput('lastyr', trim(left(put(lastyr, 4.))));
run;

/*Import IO Tables*/ 
proc import datafile="&iopath.1997 Use on 2012 Basis.xlsb"
			out=work.io97
			DBMS=excel
			REPLACE;
run;

proc import datafile="&iopath.2002 Use on 2012 Basis.xlsb"
			out=work.io02
			DBMS=excel
			REPLACE;
run;

proc import datafile="&iopath.2007 Use on 2012 Basis.xlsb"
			out=work.io07
			DBMS=excel
			REPLACE;
run;

proc import datafile="&iopath.Commodity Classification.xlsb"
			out=work.commclass
			DBMS=excel
			REPLACE;
run;

/* Stack the IO datasets. */
Proc Sql;
	Create table 	work.IO_All as
	Select 			IO, Naics, PRO, TC, WHS, RET, PUR, 1997 as Year   from work.IO97 (rename=(Pro97=PRO TC97=TC WHS97=WHS RET97=RET PUR97=PUR)) union all
	Select 			IO, Naics, PRO, TC, WHS, RET, PUR, 2002 as Year   from work.IO02 (rename=(Pro02=PRO TC02=TC WHS02=WHS RET02=RET PUR02=PUR)) union all
	Select 			IO, Naics, PRO, TC, WHS, RET, PUR, 2007 as Year   from work.IO07 (rename=(Pro07=PRO TC07=TC WHS07=WHS RET07=RET PUR07=PUR))
	order by		IO, Naics, Year;
quit;

/*	Merge Commclass and IO_All. */
Proc Sql;
	Create table	work.IO_All2 as 
	Select			a.IO, a.Naics, a.PRO, a.TC, a.WHS, a.RET, a.PUR, a.Year, b.classification 
	from 			work.IO_All a
	inner join		work.commclass b
	on				(a.IO=b.IO) and (a.Naics=b.Naics)
	where			b.classification in ('S')          
	order by		a.IO, a.Naics, a.Year;
quit;

/* Sum purchase values to the 4-digit level*/
proc sql;
	create table	work.SumIOValues as
	select			substr(NAICS, 1, 4) as NAICS4, Year, sum(PUR) as PURTotal
	from			work.IO_All2
	group by		NAICS4, Year
	order by		NAICS4, Year;
quit;

/*Calculate purchase value shares */
proc sql;
	create table	work.IOCensusYearShares as
	select			a.IO, a.NAICS, b.NAICS4, a.Year, a.PUR, b.PURTotal, a.PUR/b.PURTotal as Value
	from			work.IO_All2 a
	inner join		work.SumIOValues b
	on				(substr(NAICS, 1, 4)=b.NAICS4) and (a.Year=b.Year); 
quit;

/*Find Annual IO Values*/
/*Step 1: Create unique Naics - IO combinations with years from 1987-End Year (EY)*/
Proc Sql;
	Create table  	work.YearStructure_87EY as 
    Select          Distinct a.IO, a.Naics, b.Year
    from 	     	work.IOCensusYearShares a
	inner join		IP.IO_Deflators_All b  /* Read-in Domestic Deflators */
	on				(a.IO=b.IO);
quit;

/*Step 2: Merge Year Structure File onto the IO purchase value shares. */
proc sql;
	create table	work.IO_All_5yrs as
	select			a.IO, a.NAICS, a.Year, b.Value
	from			work.YearStructure_87EY a
	left join		work.IOCensusYearShares b
	on				(a.IO=b.IO) and (a.NAICS=b.NAICS) and (a.Year=b.Year);
quit;

/*Step 3: Add CensusPeriodID and CensusYear from the databse and hold 1997 import ratios constant back to 1987*/
libname SQL ODBC DSN=IPSTestDB  schema=sas;

/*Pull in the YearID map from IPS Database */
data work.Report_YearsCensusPeriod;
	set	sql.Report_YearsCensusPeriod;
	if CensusPeriodID>10 and CensusPeriodID<13;
run;

/*Add CensusPeriodID and CensusYear from the database for interpolation*/
Proc Sql;
	Create table  	work.AddYearNo_CensusPeriod as 
    Select          Distinct a.IO, a.Naics, a.Year, b.CensusPeriodID, b.CensusYear as YearNo, a.Value
    from 	     	work.IO_All_5yrs a
	left join		work.Report_YearsCensusPeriod b
	on				(a.Year=b.Year)
	order by		a.IO, a.Naics, b.Year;
quit;

/*Step 4: Extrapolate 1997 purchase value shares in the IO table back to 1987 and 2007 purchase value shares forward through EY*/
Proc Sql;
	Create table  	work.ExtrapolateShares as 
    Select          Distinct a.IO, a.Naics, a.Year, a.CensusPeriodID, a.YearNo, 
					case when a.Year<1997 then b.Value
						 when a.Year>2007 then c.Value
						 else a.Value
					end as Value
    from 	     	work.AddYearNo_CensusPeriod a
	left join		work.AddYearNo_CensusPeriod b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (b.Year=1997)
	left join		work.AddYearNo_CensusPeriod c
	on				(a.IO=c.IO) and (a.Naics=c.Naics) and (c.Year=2007)
	order by		a.IO, a.Naics, a.Year;
quit;

/*Step 5: Interpolate purchase value share benchmarks*/
Proc sql;
	Create table  	work.ShareDiff as 
    Select          a.IO, a.Naics, a.CensusPeriodID, (a.Value-b.Value)/5 as IncrementValue
    from 	     	work.ExtrapolateShares a
	inner join		work.ExtrapolateShares b
    on 				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.CensusPeriodID=b.CensusPeriodID) and (a.YearNo=6) and (b.YearNo=1)
	order by		a.IO, a.Naics, a.CensusPeriodID;

	Create table	work.ShareWorking as
	Select			a.IO, a.Naics, a.Year, a.CensusPeriodID, a.YearNo, a.Value, 
					case 	when b.IncrementValue is null then 0 
							else b.IncrementValue 
					end 	as IncrementValue
	from			work.ExtrapolateShares a
	left join 		work.ShareDiff b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.CensusPeriodID=b.CensusPeriodID) 
	order by		a.IO, a.Naics, a.Year;

	Create table	work.InterpolateShares as
	Select			a.IO, a.Naics, a.CensusPeriodID, a.Year, a.YearNo,(a.IncrementValue*(a.YearNo-1))+b.Value as Value
	from			work.ShareWorking a
	inner join		work.ShareWorking b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.CensusPeriodID=b.CensusPeriodID) and (b.YearNo=1)
	order by 		a.IO, a.Naics, a.Year;
quit;

/*Step 6: Combine Extrapolated and Interpolated IO Value Shares */
proc sql;
	create table	work.AnnualShares as
	select			distinct a.IO, a.NAICS, substr(a.NAICS, 1, 4) as NAICS4, a.Year,
					case 	when a.Value=. then b.Value
							else a.Value
					end		as Value
	from 			work.ExtrapolateShares a
	left join		work.InterpolateShares b
	on				(a.IO=b.IO) and (a.NAICS=b.NAICS) and (a.Year=b.Year) and (a.CensusPeriodID=b.CensusPeriodID)
	order by		a.IO, a.NAICS, a.Year;
quit;

/*Begin TQ Process */
/*Calculate annual average purchase value shares */
Proc Sql;
	Create table  	work.AverageAnnualShares as 
    Select          a.IO, a.NAICS, a.NAICS4, a.Year, (a.Value+b.Value)/2 as Value
    from 	     	work.AnnualShares a 
	left join 		work.AnnualShares b
    on 				(a.IO=b.IO) and (a.NAICS=b.NAICS) and (a.Year-1=b.Year)
	order by		a.IO, a.NAICS, a.Year;
quit;

/*Change in natural log of IO deflators */
proc sql;
	create table	work.LNChange as
	select			a.IO, a.Year, log(a.Value)-log(b.Value) as Value
	from			IP.io_deflators_all a
	left join		IP.io_deflators_all b
	on				(a.IO=b.IO) and (a.Year=b.Year+1);
quit;

/*Find the exponential value of the summed product of LNChange and Average Shares */
proc sql;
	create table	work.Expsum as
	select			a.NAICS4, a.Year, exp(sum(a.Value*b.Value)) as Value
	from			work.AverageAnnualShares a
	inner join		work.LNChange b
	on				(a.IO=b.IO) and (a.Year=b.Year)
	group by		a.NAICS4, a.Year
	order by		a.NAICS4, a.Year;
quit;

/*Chain link the exponential values */
%macro chain;
Proc sql;
Create table 	work.price_srv as
Select 			a.Naics4 as NAICS, a.Year,
				case when a.year=1987 then 100
				%do i = 1988 %to &lastyr.;
					when a.Year=&i then
					%do b = &i %to 1988 %by -1;
						_&b..Value*
					%end;
					100
				%end;
				end as Price_Srv
from 			work.ExpSum a
				%do c = 1988 %to &lastyr.;
					left join work.ExpSum _&c on (a.Naics4=_&c..Naics4) and _&c..year=&c
				%end;
order by 		a.Naics4, a.Year;
quit;
%mend chain;
%chain;

/* Export to IP SAS library */
data IP.price_srv;
	set work.price_srv;
run;

/* Export to Excel for analysis */
proc export	data=work.price_srv
			outfile="Q:\MFP\Manufacturing\IP\IP Output\Price_of_Services.xlsx"
			dbms=xlsx replace;
			sheet="Price_Srv";
run;
