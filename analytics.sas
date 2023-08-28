/* https://www.codeconvert.ai/python-to-sas-converter */


/* read a excel file */
PROC IMPORT DATAFILE="/home/u61494208/sasuser.v94/train.csv" 
OUT=WORK.data DBMS=CSV REPLACE; 	GETNAMES=YES;
run;

proc print data=data(obs=10);
run;

/* Perform basic summary statistics */
proc means data=data;
  var Pclass;
run;

/* Frequency Distribution of Education */
proc freq data=data;
  tables Pclass;
run;

/* Crosstabulation: Education vs. Income */
proc freq data=data;
  tables Pclass * Sex / nocol nopercent norow nocol;
run;

/* Check for Missing Values */
proc freq data=data;
  tables Age / missing out=missing_freq;
run;

proc print data=missing_freq;
run;

proc sort data=missing_freq;
  by descending COUNT;
run;

proc print data=missing_freq;
run;



/* Impute Missing Values (assuming mean imputation for age and income) */
proc stdize data=data out=data1 reponly missing= 24 method=mean;
  var age;
run;

proc print data=data1;
run;

proc print data=missing_freq(obs=2);
run;


/* Convert String to Numeric */
data mydata_numeric;
  set data;
  age_numeric = input(Age,best32.); /* Use ?? to handle invalid conversions */
/*   drop age_str; */
run;


proc print data=data1(obs=2);
run;


/* Binning (Age) */
proc format;
	value age_group
    low -< 30 = 'Young'
    30 -< 50 = 'Adult'
    50 - high = 'Senior';
run;
data binned_data;
  set data1;
  age_group = put(Age, age_group.);
run;
proc print data=binned_data(obs=2);
run;

/* Create a New Dataset with Column Dropped */
data newdata;
  set binned_data(drop=Age);
run;
proc print data=newdata(obs=2);
run;

/* Create a New Dataset with Column Dropped */
data newdata1;
  set newdata(drop=Cabin);
run;
proc print data=newdata1(obs=2);
run;

/*create new dataset, checking missing values*/ 
data final;
    set newdata1;
    missing_position = missing(age_group);
run;

/*view new dataset*/
proc print data=final;


/*count missing values for each numeric variable*/
proc means data=final
    NMISS;
run;

proc print data=final(obs=2);
run;


/*create frequency table for multiple variable, both sorted by frequency*/
proc freq data=final order=freq;
	tables Survived	Pclass	Sex	SibSp	Parch	Ticket Embarked age_group;
run;

/* Create a New Dataset with Column Dropped */
data final;
  set final(drop=Ticket);
run;
/* Create a New Dataset with Column Dropped */
data final;
  set final(drop= missing_position);
run;
/* Create a New Dataset with Column Dropped */
data final;
  set final(drop= PassengerId);
run;
/* Create a New Dataset with Column Dropped */
data final;
  set final(drop= Name);
run;

/* One-Hot Encoding (Gender) */
proc sql;
  create table encoded_data as
  select *,
         case when age_group = 'Young' then 1 else 0 end as Young,
         case when age_group = 'Adult' then 1 else 0 end as Adult,
         case when age_group = 'Senior' then 1 else 0 end as Senior
  from final;
quit;

/* Create a New Dataset with Column Dropped */
data encoded_data;
  set encoded_data(drop= age_group);
run;

/* One-Hot Encoding (Gender) */
proc sql;
  create table encoded_data as
  select *,
         case when Sex = 'male' then 1 else 0 end as male,
         case when Sex = 'female' then 1 else 0 end as female
  from encoded_data;
quit;

/*create frequency table for multiple variable, both sorted by frequency*/
proc freq data=encoded_data order=freq;
	tables Embarked;
run;


/* One-Hot Encoding (Gender) */
proc sql;
  create table encoded_data as
  select *,
         case when Embarked = 'S' then 1 else 0 end as S,
         case when Embarked = 'C' then 1 else 0 end as C,
         case when Embarked = 'Q' then 1 else 0 end as Q
  from encoded_data;
quit;

/* Create a New Dataset with Column Dropped */
data encoded_data;
  set encoded_data(drop= Embarked);
run;

proc print data=encoded_data;
run;

data latest;
	set encoded_data;
run;


data latest;
  set latest(drop= Embarked);
run;
proc print data=latest;
run;

data latest;
  set latest(drop= Sex);
run;
proc print data=latest;
run;

/* for loop */
/* data values; */
/*    do i = 0 to 99; */
/*       value = i; */
/*       output; */
/*    end; */
/*    drop i; */
/* run; */

/*fit logistic regression model*/
proc logistic data=latest descending;
  model Survived = Pclass	SibSp	Parch	Fare	Young	Adult	Senior	male	female	S	C	Q;
run;

/* Split data into two datasets : 70%- training 30%- validation */
Proc Surveyselect data=latest out=split seed= 1234 samprate=.7 outall;
Run;

Data training validation;
Set split;
if selected = 1 then output training;
else output validation;
Run;

/* Logistic Model*/
ods graphics on;
Proc Logistic Data = training descending;
Model Survived = Pclass	SibSp	Parch	Fare	Young	Adult	Senior	male	female	S	C	Q / selection = stepwise slstay=0.15 slentry=0.15 stb;
score data=training out = Logit_Training fitstat outroc=troc;
score data=validation out = Logit_Validation fitstat outroc=vroc;
Run;

/*An entry significance level of 0.15, specified in the slentry=0.15 option, means a*/
/*variable must have a p-value < 0.15 in order to enter the model regression.*/
/*An exit significance level of 0.15, specified in the slstay=0.15 option, means */
/*a variable must have a p-value > 0.15 in order to leave the model*/

/* KS Statistics*/
Proc npar1way data=Logit_Validation edf;
class Survived;
var p_1;
run;

/* 4.1 | Building Logisitic Regression Model */
/* -------------------------------------------------------- */
PROC LOGISTIC DATA=training
		OUTMODEL=IMPORT_TRAIN_LRMODEL;
	MODEL Survived=
	Pclass	SibSp	Parch	Fare	Young	Adult	Senior	male	female	S	C	Q;
	OUTPUT OUT=IMPORT_TRAIN_LRMODEL_OUTPUT P=PRED_PROB;
RUN;


PROC LOGISTIC INMODEL = IMPORT_TRAIN_LRMODEL;
SCORE DATA = validation
OUT = IMPORT_PREDICTIONS;
QUIT;

PROC SQL;
	SELECT * FROM IMPORT_PREDICTIONS;
QUIT;

proc print data=IMPORT_PREDICTIONS;
run;

/* confusion matrix */

proc freq data=IMPORT_PREDICTIONS;
  tables F_Survived * I_Survived / list missing out=confusion_matrix;
run;



/* Print the Confusion Matrix */
proc print data=confusion_matrix;
  var F_Survived I_Survived count percent;
run;



/* Macro: */
/* Its like auto funtion used to perform repetative task. */
/*  */
/* Concepts and components of SAS macro programming. */
/* A macro variable is used to store a value in SAS. */
/* The value is always character. */
/*  */
/* Local, Global - similar to python. */
/*  */
/* various ways to create a macro variable. */
/* %LET macro-variable-name = value; */
/* %LET x = 5; */

/* Example:   & is used to call */
%macro test (input =, ivar=, output=);
proc means data = &input noprint;
var &ivar;
output out = &output mean= ;
run;
%mend;
/* How to call a macro - */
%test(input=sashelp.heart, ivar= height, output=test);

%let dt = &sysdate;
/* use to view what variable have */
%put &dt.;



/* use to perform operation when two variable called but used only for integers */
%eval(&x*&y);
/* for floating  */
%SYSEVALF(4.5+3.2);



