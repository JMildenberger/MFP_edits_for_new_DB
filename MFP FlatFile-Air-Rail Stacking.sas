

/*MFP Manufacturing-Airlines-Railroads Stacking*/

/*DESCRIPTION: 	This program creates the final MFP flat file combines the manufacturing flat file with the Airlines flat file and 
				Railroad flat file.*/


/*MACROS AND LIBRARIES*/
	%let FFM = FlatFileManf;
	%let Air = airline_ips_variables;
	%let Rail = railroad_ips_variable;
	libname MFPSAS "Q:\MFP\SAS Libraries\Manufacturing\MFP";
	libname CapAir "Q:\MFP\SAS Libraries\NAICS 481\MFP";
	libname CapRail "Q:\MFP\SAS Libraries\NAICS 482111\MFP";

/*DATA IMPORT*/
	proc copy in=MFPSAS out=work;
		select &FFM;
	quit;
	proc copy in=CapAir out=work;
		select &Air;
	run;
	proc copy in=CapRail out=work;
		select &Rail;
	run;

	data work.airline_ips_variables;
	set work.airline_ips_variables (rename=(IndustryCodeID=IndustryCodeID2)); 
	if Vtype(IndustryCodeID2)="N" then IndustryCodeID=put(IndustryCodeID2,6.);
	Else IndustryCodeID=IndustryCodeID2;
	drop IndustryCodeID2;
	run;
	data work.Railroad_ips_variable;
	set work.Railroad_ips_variable (rename=(IndustryCodeID=IndustryCodeID2)); 
	if Vtype(IndustryCodeID2)="N" then IndustryCodeID=put(IndustryCodeID2,6.);
	Else IndustryCodeID=IndustryCodeID2;
	drop IndustryCodeID2;
	run;

	data work.&FFM;
		retain IndustryCodeID IndustryID DataSeriesCodeID DataSeriesID Year Value YearID DataArrayID;
		set work.&FFM;
			run;

	data work.&Air;
		retain NAICS Industry Variable DataSeriesID YEAR VALUE YearID DataArrayID;
		set work.&Air;
	run;

	data work.&Rail;
		retain NAICS Industry Variable DataSeriesID YEAR VALUE YearID DataArrayID;
		set work.&Rail;
	run;

	data work.FlatFile MFPSAS.FlatFile;
	length IndustryCodeID $6.;
		set work.&FFM work.&Air work.&Rail;
	IndustrycodeID=left(industrycodeid);
	drop year1 value1;
	run;

Proc Export data=mfpsas.flatfile
Outfile = "J:\SAS Testing\MFP Re-write\Output Data\FlatFileFinal.xlsx" Replace;
Sheet = Data;
run;

proc datasets library=work kill noprint;
run;
quit;