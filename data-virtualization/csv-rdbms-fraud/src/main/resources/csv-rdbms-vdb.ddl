CREATE DATABASE csvrdbmsdb OPTIONS (ANNOTATION 'The CSV VDB'); 
USE DATABASE csvrdbmsdb;

CREATE FOREIGN DATA WRAPPER rest; CREATE FOREIGN DATA WRAPPER mysql;
CREATE FOREIGN DATA WRAPPER file;

CREATE SERVER "sampledb" FOREIGN DATA WRAPPER mysql;
CREATE SERVER "csvserver"
	FOREIGN DATA WRAPPER file
	OPTIONS(
		Encoding 'ISO-8859-1', "ExceptionIfFileNotFound" true
		--Encoding 'US-ASCII', "ExceptionIfFileNotFound" true
	);

CREATE SCHEMA featuresdb SERVER "sampledb";
CREATE SCHEMA csvdata SERVER "csvserver";
CREATE VIRTUAL SCHEMA csvrdbms;

SET SCHEMA featuresdb;
IMPORT FOREIGN SCHEMA public FROM SERVER sampledb INTO featuresdb OPTIONS(
	"importer.useFullSchemaName" 'false',
	"importer.tableTypes" 'TABLE,VIEW');


SET SCHEMA csvdata;
IMPORT FROM SERVER "csvserver" INTO csvdata;
           
CREATE VIEW Features (
        Id integer PRIMARY KEY,
        Time_ integer,
        V1 double,
        V2 double,
        V3 double,
        V4 double,
        V5 double,
        V6 double,
        V7 double,
        V8 double,
        V9 double,
        V10 double,
        V11 double,
        V12 double,
        V13 double,
        V14 double,
        V15 double,
        V16 double,
        V17 double,
        V18 double,
        V19 double,
        V20 double,
        V21 double,
        V22 double,
        V23 double,
        V24 double,
        V25 double,
        V26 double,
        V27 double,
        V28 double,
        Amount double,
        Class_ integer
	) AS  
		SELECT s.* 
		FROM (call getTextFiles('frauddata.csv')) AS f,
			TEXTTABLE(f.file COLUMNS 
				Id integer,
				Time_ integer,
				V1 double,
				V2 double,
				V3 double,
				V4 double,
				V5 double,
				V6 double,
				V7 double,
				V8 double,
				V9 double,
				V10 double,
				V11 double,
				V12 double,
				V13 double,
				V14 double,
				V15 double,
				V16 double,
				V17 double,
				V18 double,
				V19 double,
				V20 double,
				V21 double,
				V22 double,
				V23 double,
				V24 double,
				V25 double,
				V26 double,
				V27 double,
				V28 double,
				Amount double,
				Class_ integer
				HEADER
		) AS s;



SET SCHEMA csvrdbms;

CREATE VIEW CreditFraud(
	Id integer PRIMARY KEY,
	Time_ integer,
	V1 double,
	V2 double,
	V3 double,
	V4 double,
	V5 double,
	V6 double,
	V7 double,
	V8 double,
	V9 double,
	V10 double,
	V11 double,
	V12 double,
	V13 double,
	V14 double,
	V15 double,
	V16 double,
	V17 double,
	V18 double,
	V19 double,
	V20 double,
	V21 double,
	V22 double,
	V23 double,
	V24 double,
	V25 double,
	V26 double,
	V27 double,
	V28 double,
	Amount double,
	Class_ integer
) AS 
SELECT * FROM featuresdb.FRAUD_DATA 
UNION 
SELECT * from csvdata.Features;
