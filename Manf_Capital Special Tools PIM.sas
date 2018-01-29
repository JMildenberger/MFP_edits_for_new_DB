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

/*Creating a macro variable for the update year*/
 data _null_;
      length updateid 3 firstyr 4 lastyr 4 baseperiod 3;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input updateid firstyr lastyr baseperiod;
      call symput('last', trim(left(put(lastyr, 4.))));
run;
 %put &last;

 
/**********Calculate real investment for special tools asset in NAICS &indy, 3362 and 3363 and run PIM******/

/*Merge nominal total equipment investment for each industry*/
%macro loop;
%do indy=3361 %to 3363;
data work.nom_invest_1958_2001_&indy;
set capital.naicscapexp (where=(NAICS="&indy")obs=44);
Equipment_&indy = Equipment;
drop equipment;
run;

data work.nom_invest_2002_forward_&indy;
set capital.newcapexp (where=(NAICS="&indy"));
equipment_&indy=all_other_equipment;
keep year equipment_&indy;

data work.nom_invest_&indy;
set work.nom_invest_1958_2001_&indy
    nom_invest_2002_forward_&indy;
run;
%end;
%mend loop;
%loop;

data work.sptools;
merge work.nom_invest_3361 work.nom_invest_3362 work.nom_invest_3363 sptools.special_tools (where=(year>1957));
by year;
/*create industy proportions of total equipment investment*/
prop3361= equipment_3361 / (equipment_3361 + equipment_3362 + equipment_3363);
prop3362= equipment_3362 / (equipment_3361 + equipment_3362 + equipment_3363);
prop3363= equipment_3363 / (equipment_3361 + equipment_3362 + equipment_3363);
/*nominal special tools investment for each industry*/
nom_sptools3361 = prop3361 * nomspt;
nom_sptools3362 = prop3362 * nomspt;
nom_sptools3363 = prop3363 * nomspt;
/*deflate special tools investment*/
real_sptools3361 = nom_sptools3361 /defspt;
real_sptools3362 = nom_sptools3362 /defspt;
real_sptools3363 = nom_sptools3363 /defspt;
run;

/**************Calculating stocks for special tools******************/
proc iml;
%macro try (indy = );
%do indy = 3361 %to 3363;
use work.sptools;
read all var {real_sptools&indy} into investment;
use work.sptools;
read all var {year} into year;

acol=ncol(investment);

life=3;


/*Reading in the efficiency decline matrix for equipment*/
USE lives.RNET_EQUIP;
READ ALL INTO RNET;
/*Removing the Age column so that the column number matches life*/
COL=NCOL(RNET);
RNET=RNET[,2:COL];
RNET=RNET[,life];
/*TRUNCATING RNET TO BE 2*SERVICE LIFE - 1*/
END_ROW=int(life*1.98);
RNET=RNET[1:END_ROW,];


/* FOLLOWING KRISTA THIS SETS UP MATRICES FOR THE MANIPULATION*/
IYR=NROW(investment);
ACOL=NCOL(investment); 
DEPR=J(IYR,ACOL,0);
EDEPR=J(IYR,ACOL,0);
STOCKS=J(IYR,ACOL);
AR=J(IYR,ACOL);
WEALTH=J(IYR,ACOL);
INIV=NROW(RNET);
INTAGE=NROW(RNET);

/*PRINT STOCKS iniv;*/

/* THIS IS WHERE RNET IS APPLIED TO THE INVESTMENT SERIES*/
STOCKS = investment;

DO I = 1 TO ACOL;
STOCKS[1,I] = investment[1,I];
END;

DO I=2 TO IYR;
	DO J=1 TO INIV;
	IF I>J THEN STOCKS[I,] = STOCKS[I,]+ investment[(I-J),]#RNET[J,];
	END;
END;
KRT = Year||  STOCKS;


create sptools.Sptools_Net_Stock&indy from KRT;
append from KRT;

/********************** Wealth Stocks *************************************/

/* Efficiency_Decline is the efficiency decline factor */
Efficiency_Decline = investment;
Efficiency_Decline[1,] = 0;
DO I = 2 TO IYR;
Efficiency_Decline[I,] = Efficiency_Decline[I,] - (STOCKS[I,] - STOCKS[(I-1),]);
END;

Efficiency_Decline2 = YEAR||Efficiency_Decline;


SURV=J((INTAGE+1),1);
SURV[1,1] = 1;
DO I = 1 TO INTAGE;
SURV[(I+1),] = RNET[I,1];
END;

/*This formula requires the discount rate. For now it is set to 0.04 but can be changed if necessary*/
XMORT = J(200, 1, 0);
XMARKT = J(362, 1, 0);
DO I = 1 TO (INTAGE +1);
DO J = 1 TO 362;
X = I - J;
XMORT[I,] = SURV[I,]*((1-0.04)**X);
IF X >= 0 THEN XMARKT[J,] = XMARKT[J,] + XMORT[I,];
END;
END;

X = XMARKT[1,1];
DO I = 1 TO INTAGE+1;
XMARKT[I,] = XMARKT[I,]/X;
END;

WEALTH = investment;
WEALTH[1,] = investment[1,];
DO I = 2 TO IYR;
	DO J = 1 TO INIV;
	X = I-J;
		IF X >=1 THEN WEALTH[I,] = WEALTH[I,] + investment[(I-J),]#XMARKT[(J+1),];
		END;
END;

RWT = WEALTH;
DPT = investment;
DPT[1,]=0;
DO I = 2 TO IYR;
DPT[I,]=DPT[I,]-(RWT[I,] - RWT[(I-1),]);
END;

DEPRECIATION = YEAR||DPT;
WEALTH_STOCK = YEAR||RWT;

create sptools.Sptools_Depreciation&indy from DEPRECIATION;
append from DEPRECIATION;
create sptools.Sptools_Wealth_Stock&indy from WEALTH_STOCK;
append from WEALTH_STOCK;

%end;

%mend try;
%try;
quit;
