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

 
/*Creating macro variables for the names of NAICS Industries*/
data _null_;
set capital.indys nobs=x;
      call symputx ("NAICS_Indy"!!left(_n_),NAICS);
 run;

/****************************** PIM for Equipment and Structure Assets**********************************/

/*Transposing real invesment so that years are rows and assets are columns*/
%macro loop;
%do indy=3111 %to 3399;
proc transpose data=capital.real_investment_&indy out=work.real_investment_&indy (drop=_name_) suffix = _&indy;
id aces_asset;
run;
%end;
%mend loop;
%loop;

%macro asset;
%do asset=1 %to 24;
data work.real_investment_asset&asset;
merge work.real_investment_3111 work.real_investment_3112 work.real_investment_3113 work.real_investment_3114 work.real_investment_3115 work.real_investment_3116 work.real_investment_3117 work.real_investment_3118 
work.real_investment_3119 work.real_investment_3121 work.real_investment_3122 work.real_investment_3131 work.real_investment_3132 work.real_investment_3133 work.real_investment_3141 work.real_investment_3149 
work.real_investment_3151 work.real_investment_3152 work.real_investment_3159 work.real_investment_3161 work.real_investment_3162 work.real_investment_3169 work.real_investment_3211 work.real_investment_3212 
work.real_investment_3219 work.real_investment_3221 work.real_investment_3222 work.real_investment_3231 work.real_investment_3241 work.real_investment_3251 work.real_investment_3252 work.real_investment_3253
work.real_investment_3254 work.real_investment_3255 work.real_investment_3256 work.real_investment_3259 work.real_investment_3261 work.real_investment_3262 work.real_investment_3271 work.real_investment_3272
work.real_investment_3273 work.real_investment_3274 work.real_investment_3279 work.real_investment_3311 work.real_investment_3312 work.real_investment_3313 work.real_investment_3314 work.real_investment_3315
work.real_investment_3321 work.real_investment_3322 work.real_investment_3323 work.real_investment_3324 work.real_investment_3325 work.real_investment_3326 work.real_investment_3327 work.real_investment_3328 
work.real_investment_3329 work.real_investment_3331 work.real_investment_3332 work.real_investment_3333 work.real_investment_3334 work.real_investment_3335 work.real_investment_3336 work.real_investment_3339 
work.real_investment_3341 work.real_investment_3342 work.real_investment_3343 work.real_investment_3344 work.real_investment_3345 work.real_investment_3346 work.real_investment_3351 work.real_investment_3352
work.real_investment_3353 work.real_investment_3359 work.real_investment_3361 work.real_investment_3362 work.real_investment_3363 work.real_investment_3364 work.real_investment_3365 work.real_investment_3366 
work.real_investment_3369 work.real_investment_3371 work.real_investment_3372 work.real_investment_3379 work.real_investment_3391 work.real_investment_3399;
keep _&asset._:;
run;
%end;
%mend asset;
%asset;

/*Net Stock, Depreciation and Wealth Stock calculations for equipment assets 1-8*/

proc iml;

use lives.lives_1_8;
read all into lives;

%macro try (asset = );
%do asset = 1 %to 8;
/*Reading in investment for assets 1 to 8*/
use work.real_investment_asset&asset;
read all into investment;

acol=ncol(investment);

life=lives[,&asset];


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


/* Deminsioning MATRICES FOR THE MANIPULATION*/
IYR=NROW(investment);
ACOL=NCOL(investment); 
DEPR=J(IYR,ACOL,0);
EDEPR=J(IYR,ACOL,0);
STOCKS=J(IYR,ACOL);
AR=J(IYR,ACOL);
WEALTH=J(IYR,ACOL);
INIV=NROW(RNET);
INTAGE=NROW(RNET);


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
KRT = STOCKS;


create work.Net_stock&asset from KRT;
append from KRT;

/********************** Wealth Stocks *************************************/

/* Efficiency_Decline factor */
Efficiency_Decline = investment;
Efficiency_Decline[1,] = 0;
DO I = 2 TO IYR;
Efficiency_Decline[I,] = Efficiency_Decline[I,] - (KRT[I,] - KRT[(I-1),]);
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

create work.DEPRECIATION&asset from DEPRECIATION;
append from dpt;
create work.WEALTH_STOCK&asset from WEALTH_STOCK;
append from rwt;

%end;
%mend try;
%try;
quit;

/*Net Stock, Depreciation and Wealth Stock calculations for equipment assets 12-24*/

proc iml;

use lives.lives_12_24;
read all into lives;

%macro try (asset = );
%do asset = 12 %to 24;
/*Reading in investment for assets 1 to 8*/
use work.real_investment_asset&asset;
read all into investment;

acol=ncol(investment);

life=lives[,&asset];


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


/* Deminsioning MATRICES FOR THE MANIPULATION*/
IYR=NROW(investment);
ACOL=NCOL(investment); 
DEPR=J(IYR,ACOL,0);
EDEPR=J(IYR,ACOL,0);
STOCKS=J(IYR,ACOL);
AR=J(IYR,ACOL);
WEALTH=J(IYR,ACOL);
INIV=NROW(RNET);
INTAGE=NROW(RNET);


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
KRT = STOCKS;


create work.Net_stock&asset from KRT;
append from KRT;

/********************** Wealth Stocks *************************************/

/* Efficiency_Decline factor */
Efficiency_Decline = investment;
Efficiency_Decline[1,] = 0;
DO I = 2 TO IYR;
Efficiency_Decline[I,] = Efficiency_Decline[I,] - (KRT[I,] - KRT[(I-1),]);
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

create work.DEPRECIATION&asset from DEPRECIATION;
append from dpt;
create work.WEALTH_STOCK&asset from WEALTH_STOCK;
append from rwt;

%end;
%mend try;
%try;
quit;

/*Calculating stocks for asset 9*/
proc iml;

use lives.lives_9;
read all into lives;

%macro try (indy = );
%do indy = 1 %to 86;
use work.real_investment_asset9;
read all into investment;
investment=investment[,&indy];
acol=ncol(investment);

life=lives[,&indy];


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
KRT = STOCKS;


create work.krt_indy&indy from KRT;
append from KRT;

/********************** Wealth Stocks *************************************/

/* Efficiency_Decline is the efficiency decline factor */
Efficiency_Decline = investment;
Efficiency_Decline[1,] = 0;
DO I = 2 TO IYR;
Efficiency_Decline[I,] = Efficiency_Decline[I,] - (KRT[I,] - KRT[(I-1),]);
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

create work.dpt_indy&indy from dpt;
append from dpt;
create work.rwt_indy&indy from rwt;
append from rwt;

%end;

%mend try;
%try;
quit;

/*putting all industries into one dataset*/
proc iml;
%macro concatenate (indy = );
%do indy= 1 %to 86;
use work.krt_indy&indy;
read all into krt&indy;
use work.dpt_indy&indy;
read all into dpt&indy;
use work.rwt_indy&indy;
read all into rwt&indy;
%end;
%mend concatenate;
%concatenate;

krt9=krt1	||krt2	||krt3	||krt4	||krt5	||krt6	||krt7	||krt8	||krt9	||krt10
	||krt11	||krt12	||krt13	||krt14	||krt15	||krt16	||krt17	||krt18	||krt19	||krt20
	||krt21	||krt22	||krt23	||krt24	||krt25	||krt26	||krt27	||krt28	||krt29	||krt30
	||krt31	||krt32	||krt33	||krt34	||krt35	||krt36	||krt37	||krt38	||krt39	||krt40
	||krt41	||krt42	||krt43	||krt44	||krt45	||krt46	||krt47	||krt48	||krt49	||krt50
	||krt51	||krt52	||krt53	||krt54	||krt55	||krt56	||krt57	||krt58	||krt59	||krt60
	||krt61 	||krt62	||krt63	||krt64	||krt65	||krt66	||krt67	||krt68	||krt69	||krt70
	||krt71	||krt72	||krt73	||krt74	||krt75	||krt76	||krt77	||krt78	||krt79	||krt80
	||krt81	||krt82	||krt83	||krt84	||krt85	||krt86	;	

dpt9=dpt1	||dpt2	||dpt3	||dpt4	||dpt5	||dpt6	||dpt7	||dpt8	||dpt9	||dpt10
	||dpt11	||dpt12	||dpt13	||dpt14	||dpt15	||dpt16	||dpt17	||dpt18	||dpt19	||dpt20
	||dpt21	||dpt22	||dpt23	||dpt24	||dpt25	||dpt26	||dpt27	||dpt28	||dpt29	||dpt30
	||dpt31	||dpt32	||dpt33	||dpt34	||dpt35	||dpt36	||dpt37	||dpt38	||dpt39	||dpt40
	||dpt41	||dpt42	||dpt43	||dpt44	||dpt45	||dpt46	||dpt47	||dpt48	||dpt49	||dpt50
	||dpt51	||dpt52	||dpt53	||dpt54	||dpt55	||dpt56	||dpt57	||dpt58	||dpt59	||dpt60
	||dpt61 	||dpt62	||dpt63	||dpt64	||dpt65	||dpt66	||dpt67	||dpt68	||dpt69	||dpt70
	||dpt71	||dpt72	||dpt73	||dpt74	||dpt75	||dpt76	||dpt77	||dpt78	||dpt79	||dpt80
	||dpt81	||dpt82	||dpt83	||dpt84	||dpt85	||dpt86	;

rwt9=rwt1	||rwt2	||rwt3	||rwt4	||rwt5	||rwt6	||rwt7	||rwt8	||rwt9	||rwt10
	||rwt11	||rwt12	||rwt13	||rwt14	||rwt15	||rwt16	||rwt17	||rwt18	||rwt19	||rwt20
	||rwt21	||rwt22	||rwt23	||rwt24	||rwt25	||rwt26	||rwt27	||rwt28	||rwt29	||rwt30
	||rwt31	||rwt32	||rwt33	||rwt34	||rwt35	||rwt36	||rwt37	||rwt38	||rwt39	||rwt40
	||rwt41	||rwt42	||rwt43	||rwt44	||rwt45	||rwt46	||rwt47	||rwt48	||rwt49	||rwt50
	||rwt51	||rwt52	||rwt53	||rwt54	||rwt55	||rwt56	||rwt57	||rwt58	||rwt59	||rwt60
	||rwt61 	||rwt62	||rwt63	||rwt64	||rwt65	||rwt66	||rwt67	||rwt68	||rwt69	||rwt70
	||rwt71	||rwt72	||rwt73	||rwt74	||rwt75	||rwt76	||rwt77	||rwt78	||rwt79	||rwt80
	||rwt81	||rwt82	||rwt83	||rwt84	||rwt85	||rwt86	;

create work.Net_Stock9 from krt9;
append from krt9;
create work.Depreciation9 from dpt9;
append from dpt9;
create work.Wealth_Stock9 from rwt9;
append from rwt9;

quit;

/*Calculating stocks for asset 10*/
proc iml;

use lives.lives_10;
read all into lives;

%macro try (indy = );
%do indy = 1 %to 86;
use work.real_investment_asset10;
read all into investment;
investment=investment[,&indy];
acol=ncol(investment);

life=lives[,&indy];


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
KRT = STOCKS;


create work.krt_indy&indy from KRT;
append from KRT;

/********************** Wealth Stocks *************************************/

/* Efficiency_Decline is the efficiency decline factor */
Efficiency_Decline = investment;
Efficiency_Decline[1,] = 0;
DO I = 2 TO IYR;
Efficiency_Decline[I,] = Efficiency_Decline[I,] - (KRT[I,] - KRT[(I-1),]);
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

create work.dpt_indy&indy from dpt;
append from dpt;
create work.rwt_indy&indy from rwt;
append from rwt;

%end;

%mend try;
%try;
quit; 

/*putting all industries into one dataset*/
proc iml;
%macro concatenate (indy = );
%do indy= 1 %to 86;
use work.krt_indy&indy;
read all into krt&indy;
use work.dpt_indy&indy;
read all into dpt&indy;
use work.rwt_indy&indy;
read all into rwt&indy;
%end;
%mend concatenate;
%concatenate;

krt10=krt1	||krt2	||krt3	||krt4	||krt5	||krt6	||krt7	||krt8	||krt9	||krt10
	||krt11	||krt12	||krt13	||krt14	||krt15	||krt16	||krt17	||krt18	||krt19	||krt20
	||krt21	||krt22	||krt23	||krt24	||krt25	||krt26	||krt27	||krt28	||krt29	||krt30
	||krt31	||krt32	||krt33	||krt34	||krt35	||krt36	||krt37	||krt38	||krt39	||krt40
	||krt41	||krt42	||krt43	||krt44	||krt45	||krt46	||krt47	||krt48	||krt49	||krt50
	||krt51	||krt52	||krt53	||krt54	||krt55	||krt56	||krt57	||krt58	||krt59	||krt60
	||krt61 	||krt62	||krt63	||krt64	||krt65	||krt66	||krt67	||krt68	||krt69	||krt70
	||krt71	||krt72	||krt73	||krt74	||krt75	||krt76	||krt77	||krt78	||krt79	||krt80
	||krt81	||krt82	||krt83	||krt84	||krt85	||krt86	;	

dpt10=dpt1	||dpt2	||dpt3	||dpt4	||dpt5	||dpt6	||dpt7	||dpt8	||dpt9	||dpt10
	||dpt11	||dpt12	||dpt13	||dpt14	||dpt15	||dpt16	||dpt17	||dpt18	||dpt19	||dpt20
	||dpt21	||dpt22	||dpt23	||dpt24	||dpt25	||dpt26	||dpt27	||dpt28	||dpt29	||dpt30
	||dpt31	||dpt32	||dpt33	||dpt34	||dpt35	||dpt36	||dpt37	||dpt38	||dpt39	||dpt40
	||dpt41	||dpt42	||dpt43	||dpt44	||dpt45	||dpt46	||dpt47	||dpt48	||dpt49	||dpt50
	||dpt51	||dpt52	||dpt53	||dpt54	||dpt55	||dpt56	||dpt57	||dpt58	||dpt59	||dpt60
	||dpt61 	||dpt62	||dpt63	||dpt64	||dpt65	||dpt66	||dpt67	||dpt68	||dpt69	||dpt70
	||dpt71	||dpt72	||dpt73	||dpt74	||dpt75	||dpt76	||dpt77	||dpt78	||dpt79	||dpt80
	||dpt81	||dpt82	||dpt83	||dpt84	||dpt85	||dpt86	;

rwt10=rwt1	||rwt2	||rwt3	||rwt4	||rwt5	||rwt6	||rwt7	||rwt8	||rwt9	||rwt10
	||rwt11	||rwt12	||rwt13	||rwt14	||rwt15	||rwt16	||rwt17	||rwt18	||rwt19	||rwt20
	||rwt21	||rwt22	||rwt23	||rwt24	||rwt25	||rwt26	||rwt27	||rwt28	||rwt29	||rwt30
	||rwt31	||rwt32	||rwt33	||rwt34	||rwt35	||rwt36	||rwt37	||rwt38	||rwt39	||rwt40
	||rwt41	||rwt42	||rwt43	||rwt44	||rwt45	||rwt46	||rwt47	||rwt48	||rwt49	||rwt50
	||rwt51	||rwt52	||rwt53	||rwt54	||rwt55	||rwt56	||rwt57	||rwt58	||rwt59	||rwt60
	||rwt61 	||rwt62	||rwt63	||rwt64	||rwt65	||rwt66	||rwt67	||rwt68	||rwt69	||rwt70
	||rwt71	||rwt72	||rwt73	||rwt74	||rwt75	||rwt76	||rwt77	||rwt78	||rwt79	||rwt80
	||rwt81	||rwt82	||rwt83	||rwt84	||rwt85	||rwt86	;

create work.Net_Stock10 from krt10;
append from krt10;
create work.Depreciation10 from dpt10;
append from dpt10;
create work.Wealth_Stock10 from rwt10;
append from rwt10;

quit;

/*Calculating stocks for asset 11*/
proc iml;

use lives.lives_11;
read all into lives;

%macro try (indy = );
%do indy = 1 %to 86;
use work.real_investment_asset11;
read all into investment;
investment=investment[,&indy];
acol=ncol(investment);

life=lives[,&indy];


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
KRT = STOCKS;


create work.krt_indy&indy from KRT;
append from KRT;

/********************** Wealth Stocks *************************************/

/* Efficiency_Decline is the efficiency decline factor */
Efficiency_Decline = investment;
Efficiency_Decline[1,] = 0;
DO I = 2 TO IYR;
Efficiency_Decline[I,] = Efficiency_Decline[I,] - (KRT[I,] - KRT[(I-1),]);
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

create work.dpt_indy&indy from dpt;
append from dpt;
create work.rwt_indy&indy from rwt;
append from rwt;

%end;

%mend try;
%try;
quit;

/*putting all industries into one dataset*/
proc iml;
%macro concatenate (indy = );
%do indy= 1 %to 86;
use work.krt_indy&indy;
read all into krt&indy;
use work.dpt_indy&indy;
read all into dpt&indy;
use work.rwt_indy&indy;
read all into rwt&indy;
%end;
%mend concatenate;
%concatenate;

krt11=krt1	||krt2	||krt3	||krt4	||krt5	||krt6	||krt7	||krt8	||krt9	||krt10
	||krt11	||krt12	||krt13	||krt14	||krt15	||krt16	||krt17	||krt18	||krt19	||krt20
	||krt21	||krt22	||krt23	||krt24	||krt25	||krt26	||krt27	||krt28	||krt29	||krt30
	||krt31	||krt32	||krt33	||krt34	||krt35	||krt36	||krt37	||krt38	||krt39	||krt40
	||krt41	||krt42	||krt43	||krt44	||krt45	||krt46	||krt47	||krt48	||krt49	||krt50
	||krt51	||krt52	||krt53	||krt54	||krt55	||krt56	||krt57	||krt58	||krt59	||krt60
	||krt61 	||krt62	||krt63	||krt64	||krt65	||krt66	||krt67	||krt68	||krt69	||krt70
	||krt71	||krt72	||krt73	||krt74	||krt75	||krt76	||krt77	||krt78	||krt79	||krt80
	||krt81	||krt82	||krt83	||krt84	||krt85	||krt86	;	

dpt11=dpt1	||dpt2	||dpt3	||dpt4	||dpt5	||dpt6	||dpt7	||dpt8	||dpt9	||dpt10
	||dpt11	||dpt12	||dpt13	||dpt14	||dpt15	||dpt16	||dpt17	||dpt18	||dpt19	||dpt20
	||dpt21	||dpt22	||dpt23	||dpt24	||dpt25	||dpt26	||dpt27	||dpt28	||dpt29	||dpt30
	||dpt31	||dpt32	||dpt33	||dpt34	||dpt35	||dpt36	||dpt37	||dpt38	||dpt39	||dpt40
	||dpt41	||dpt42	||dpt43	||dpt44	||dpt45	||dpt46	||dpt47	||dpt48	||dpt49	||dpt50
	||dpt51	||dpt52	||dpt53	||dpt54	||dpt55	||dpt56	||dpt57	||dpt58	||dpt59	||dpt60
	||dpt61 	||dpt62	||dpt63	||dpt64	||dpt65	||dpt66	||dpt67	||dpt68	||dpt69	||dpt70
	||dpt71	||dpt72	||dpt73	||dpt74	||dpt75	||dpt76	||dpt77	||dpt78	||dpt79	||dpt80
	||dpt81	||dpt82	||dpt83	||dpt84	||dpt85	||dpt86	;

rwt11=rwt1	||rwt2	||rwt3	||rwt4	||rwt5	||rwt6	||rwt7	||rwt8	||rwt9	||rwt10
	||rwt11	||rwt12	||rwt13	||rwt14	||rwt15	||rwt16	||rwt17	||rwt18	||rwt19	||rwt20
	||rwt21	||rwt22	||rwt23	||rwt24	||rwt25	||rwt26	||rwt27	||rwt28	||rwt29	||rwt30
	||rwt31	||rwt32	||rwt33	||rwt34	||rwt35	||rwt36	||rwt37	||rwt38	||rwt39	||rwt40
	||rwt41	||rwt42	||rwt43	||rwt44	||rwt45	||rwt46	||rwt47	||rwt48	||rwt49	||rwt50
	||rwt51	||rwt52	||rwt53	||rwt54	||rwt55	||rwt56	||rwt57	||rwt58	||rwt59	||rwt60
	||rwt61 	||rwt62	||rwt63	||rwt64	||rwt65	||rwt66	||rwt67	||rwt68	||rwt69	||rwt70
	||rwt71	||rwt72	||rwt73	||rwt74	||rwt75	||rwt76	||rwt77	||rwt78	||rwt79	||rwt80
	||rwt81	||rwt82	||rwt83	||rwt84	||rwt85	||rwt86	;

create work.Net_Stock11 from krt11;
append from krt11;
create work.Depreciation11 from dpt11;
append from dpt11;
create work.Wealth_Stock11 from rwt11;
append from rwt11;

quit;

 /*Renaming columns as NAICS industries*/
%macro names (indy =);
%do asset= 1 %to 24;

data work.depreciation&asset;
set work.depreciation&asset;
	%do indy=1 %to 86;
	Depreciation_&&NAICS_Indy&indy.._&asset = col&indy;
	%end;
drop col:;
run;

data work.Net_Stock&asset;
set work.Net_Stock&asset;
	%do indy=1 %to 86;
	Net_Stocks_&&NAICS_Indy&indy.._&asset = col&indy;
	%end;
drop col:;
run;

data work.Wealth_Stock&asset;
set work.Wealth_Stock&asset;
	%do indy=1 %to 86;
	Wealth_Stocks_&&NAICS_Indy&indy.._&asset = col&indy;
	%end;
drop col:;
run;

%end; 
%mend names;
%names;

/*Putting all net stock, depreciation and wealth stock datasets into one */
%macro combine;
data work.all_net_stock;
merge capital.allyears
	%do asset=1 %to 24;
	work.net_stock&asset
	%end;
	;
run;
data work.all_depreciation;
merge capital.allyears
	%do asset=1 %to 24;
	work.Depreciation&asset
	%end;
	;
run;
data work.all_wealth_stock;
merge capital.allyears
	%do asset=1 %to 24;
	work.wealth_stock&asset
	%end;
	;
run;

%mend combine;
%combine;

/*Creating industry specific dataset for net stock, depreciation and wealth stock*/
%macro create;
%do indy=1 %to 86;
data stock.Equipment_Net_Stock&&NAICS_Indy&indy;
set work.all_net_stock;
year=years;
keep year net_stocks_&&NAICS_Indy&indy: ;
run;

data stock.Equipment_depreciation&&NAICS_Indy&indy;
set work.all_depreciation;
year=years;
keep year depreciation_&&NAICS_Indy&indy: ;
run;

data stock.Equipment_Wealth_Stock&&NAICS_Indy&indy;
set work.all_wealth_stock;
year=years;
keep year wealth_stocks_&&NAICS_Indy&indy: ;
run;
%end;
%mend create;
%create;

/********************************************* Structure PIM **********************************************************/


/*Renaming columns in real structure investment*/
%macro industry;
%do indy=1 %to 86;
data work.real_investment_struct&&NAICS_Indy&indy;
set capital.real_investment_struct&&NAICS_Indy&indy;
	%macro name;
		%do asset=1 %to 10;
		real_investment&asset._&&NAICS_Indy&indy = real_investment&asset;
		%end;
	%mend name;
	%name;
run;
%end;
%mend industry;
%industry;

%macro asset;
%do asset=1 %to 10;
data work.real_investment_struct_asset&asset;
merge work.real_investment_struct3111 work.real_investment_struct3112 work.real_investment_struct3113 work.real_investment_struct3114 work.real_investment_struct3115 work.real_investment_struct3116 work.real_investment_struct3117 work.real_investment_struct3118 
work.real_investment_struct3119 work.real_investment_struct3121 work.real_investment_struct3122 work.real_investment_struct3131 work.real_investment_struct3132 work.real_investment_struct3133 work.real_investment_struct3141 work.real_investment_struct3149 
work.real_investment_struct3151 work.real_investment_struct3152 work.real_investment_struct3159 work.real_investment_struct3161 work.real_investment_struct3162 work.real_investment_struct3169 work.real_investment_struct3211 work.real_investment_struct3212 
work.real_investment_struct3219 work.real_investment_struct3221 work.real_investment_struct3222 work.real_investment_struct3231 work.real_investment_struct3241 work.real_investment_struct3251 work.real_investment_struct3252 work.real_investment_struct3253
work.real_investment_struct3254 work.real_investment_struct3255 work.real_investment_struct3256 work.real_investment_struct3259 work.real_investment_struct3261 work.real_investment_struct3262 work.real_investment_struct3271 work.real_investment_struct3272
work.real_investment_struct3273 work.real_investment_struct3274 work.real_investment_struct3279 work.real_investment_struct3311 work.real_investment_struct3312 work.real_investment_struct3313 work.real_investment_struct3314 work.real_investment_struct3315
work.real_investment_struct3321 work.real_investment_struct3322 work.real_investment_struct3323 work.real_investment_struct3324 work.real_investment_struct3325 work.real_investment_struct3326 work.real_investment_struct3327 work.real_investment_struct3328 
work.real_investment_struct3329 work.real_investment_struct3331 work.real_investment_struct3332 work.real_investment_struct3333 work.real_investment_struct3334 work.real_investment_struct3335 work.real_investment_struct3336 work.real_investment_struct3339 
work.real_investment_struct3341 work.real_investment_struct3342 work.real_investment_struct3343 work.real_investment_struct3344 work.real_investment_struct3345 work.real_investment_struct3346 work.real_investment_struct3351 work.real_investment_struct3352
work.real_investment_struct3353 work.real_investment_struct3359 work.real_investment_struct3361 work.real_investment_struct3362 work.real_investment_struct3363 work.real_investment_struct3364 work.real_investment_struct3365 work.real_investment_struct3366 
work.real_investment_struct3369 work.real_investment_struct3371 work.real_investment_struct3372 work.real_investment_struct3379 work.real_investment_struct3391 work.real_investment_struct3399;
keep real_investment&asset._:;
run;
%end;
%mend asset;
%asset;

/*Net Stock, Depreciation and Wealth Stock calculations for structure assets 1-10*/

proc iml;

use lives.structures;
read all into lives;

%macro try (asset = );
%do asset = 1 %to 10;
/*Reading in investment for assets 1 to 10*/
use work.real_investment_struct_asset&asset;
read all into investment;

acol=ncol(investment);

life=lives[,&asset];


/*Reading in the efficiency decline matrix for equipment*/
USE lives.RNET_Struct;
READ ALL INTO RNET;
/*Removing the Age column so that the column number matches life*/
COL=NCOL(RNET);
RNET=RNET[,2:COL];
RNET=RNET[,life];
/*TRUNCATING RNET TO BE 2*SERVICE LIFE - 1*/
END_ROW=int(life*1.98);
RNET=RNET[1:END_ROW,];

/* Deminsioning MATRICES FOR THE MANIPULATION*/
IYR=NROW(investment);
ACOL=NCOL(investment); 
DEPR=J(IYR,ACOL,0);
EDEPR=J(IYR,ACOL,0);
STOCKS=J(IYR,ACOL);
AR=J(IYR,ACOL);
WEALTH=J(IYR,ACOL);
INIV=NROW(RNET);
INTAGE=NROW(RNET);

/*Replacing missing data with zeroes*/
do i=1 to iyr;
do j=1 to acol;
	if investment[i,j] = . then investment[i,j]=0;
end;
end;

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
KRT = STOCKS;

create work.Net_stock_Struct&asset from KRT;
append from KRT;

/********************** Wealth Stocks *************************************/

/* Efficiency_Decline factor */
Efficiency_Decline = investment;
Efficiency_Decline[1,] = 0;
DO I = 2 TO IYR;
Efficiency_Decline[I,] = Efficiency_Decline[I,] - (KRT[I,] - KRT[(I-1),]);
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

create work.DEPRECIATION_Struct&asset from DEPRECIATION;
append from dpt;
create work.WEALTH_STOCK_Struct&asset from WEALTH_STOCK;
append from rwt;

%end;
%mend try;
%try;
quit;

/*Renaming columns as NAICS industries*/
%macro names (indy =);
%do asset= 1 %to 10;

data work.depreciation_struct&asset;
set work.depreciation_struct&asset;
	%do indy=1 %to 86;
	Struct_Depreciation_&&NAICS_Indy&indy.._&asset = col&indy;
	%end;
drop col:;
run;

data work.Net_Stock_struct&asset;
set work.Net_Stock_struct&asset;
	%do indy=1 %to 86;
	Struct_Net_Stocks_&&NAICS_Indy&indy.._&asset = col&indy;
	%end;
drop col:;
run;

data work.Wealth_Stock_struct&asset;
set work.Wealth_Stock_struct&asset;
	%do indy=1 %to 86;
	Struct_Wealth_Stocks_&&NAICS_Indy&indy.._&asset = col&indy;
	%end;
drop col:;
run;

%end; 
%mend names;
%names;

/*Putting all net stock, depreciation and wealth stock datasets into one */
%macro combine;
data work.all_net_stock_struct;
merge
	%do asset=1 %to 10;
	work.net_stock_struct&asset
	%end;
capital.structureyears
	;
year=years;
keep year struct_:;
run;
data work.all_depreciation_struct;
merge
	%do asset=1 %to 10;
	work.Depreciation_struct&asset
	%end;
capital.structureyears
	;
year=years;
keep year struct_:;
run;
data work.all_wealth_stock_struct;
merge
	%do asset=1 %to 10;
	work.wealth_stock_struct&asset
	%end;
capital.structureyears
	;
year=years;
keep year struct_:;
run;

%mend combine;
%combine;

/*Creating industry specific dataset for net stock, depreciation and wealth stock*/
%macro create;
%do indy=1 %to 86;
data stock.Structure_Net_Stock&&NAICS_Indy&indy;
set work.all_net_stock_struct;
keep Struct_net_stocks_&&NAICS_Indy&indy: year ;
run;

data stock.Structure_depreciation&&NAICS_Indy&indy;
set work.all_depreciation_struct;
keep Struct_depreciation_&&NAICS_Indy&indy: year;
run;

data stock.Structure_Wealth_Stock&&NAICS_Indy&indy;
set work.all_wealth_stock_struct;
keep Struct_wealth_stocks_&&NAICS_Indy&indy: year;
run;
%end;
%mend create;
%create;

/*** Applying the 2001 Manvel Ratio to the sum of the 2001 stocks of structures*******/
%macro combine;
data work.all_real_net_struct;
merge
	%do indy=1 %to 86;
	stock.structure_net_stock&&NAICS_Indy&indy
	%end;
	;
run;
data work.all_real_wealth_struct;
merge
	%do indy=1 %to 86;
	stock.structure_wealth_stock&&NAICS_Indy&Indy
	%end;
	;
run;

%mend combine;
%combine;

/*Applying the 2001 Manvel Ratio to the sum of the 2001 real wealth stocks of structures*/
data work.land_agg_real;
merge work.all_real_wealth_struct (firstobs=101 obs=101)work.all_real_net_struct (firstobs=101 obs=101);
%macro add;
%do indy=1 %to 86;
Sum_Wealth&indy= sum (of Struct_Wealth_stocks_&&NAICS_Indy&indy.._:);
land_agg&indy=(.2123/.7877)*sum_Wealth&indy;
Sum_net&indy= sum (of Struct_net_stocks_&&NAICS_Indy&indy.._:);
Land_Factor&indy= land_agg&indy/sum_net&indy;
%end;
%mend add;
%add;
keep land_factor:;
run;

proc sql noprint;
create table work.real_land as
select a.* , b.*
from work.all_real_net_struct as a, work.land_agg_real as b;
quit;
 

data stock.Real_Land_Stock;
set work.real_land;
%macro add;
%do indy=1 %to 86;
Sum_net&indy=sum (of Struct_net_stocks_&&NAICS_Indy&indy.._:);
real_land&&NAICS_Indy&indy=land_factor&indy * sum_net&indy;
%end;
%mend add;
%add;
keep real_land:;
run;
