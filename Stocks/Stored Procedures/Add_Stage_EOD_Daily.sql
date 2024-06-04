--SELECT * FROM Stock_Type
--SELECT * FROM Exchanges
--SELECT * FROM Stage_EOD_Daily
--TRUNCATE TABLE Stage_EOD_Daily

--IF OBJECT_ID('Add_Stage_EOD_Daily') IS NOT NULL
--DROP PROCEDURE Add_Stage_EOD_Daily
--GO

--DROP PROCEDURE Add_Stage_EOD_Daily
CREATE OR ALTER PROCEDURE Add_Stage_EOD_Daily

AS

BEGIN TRANSACTION EOD_Daily;

--Cleans up symbols once, avoids future processing costs
	UPDATE	Stage_EOD_Daily
	SET		SED_Symbol = UPPER(LTRIM(RTRIM(SED_Symbol)))
	WHERE	SED_Symbol <> UPPER(LTRIM(RTRIM(SED_Symbol)))


--Checks for missing symbols
	INSERT INTO Symbols
		(
		S_Changed_By
		,S_Changed_Date
		,S_SR_FK
		,S_ST_FK
		,S_E_FK
		,S_F_FK
		,S_Symbol
		)
	SELECT	
		T1.SED_Changed_By
		,T1.SED_Changed_Date
		,T1.SED_SR_FK	
		,4
		,0
		,T1.SED_F_FK
		,T1.SED_Symbol
	FROM	Stage_EOD_Daily T1
			JOIN
			(
			SELECT	SED_Symbol
					,MIN(SED_PK) MIN_PK
			FROM	Stage_EOD_Daily
					JOIN
					Files
						ON	SED_F_FK = F_PK
					LEFT OUTER JOIN
					Symbols
						ON	SED_Symbol = S_Symbol
			WHERE	S_PK IS NULL
			GROUP BY SED_Symbol
			) D1
				ON	T1.SED_PK = D1.MIN_PK
	;


	--updates existing records with new info.  
	UPDATE	Daily_Activity
	SET		DA_Changed_By = SED_Changed_By
			,DA_Changed_Date = SED_Changed_Date
			,DA_Close = SED_Close
			,DA_F_FK = SED_F_FK
			,DA_High = SED_High
			,DA_Low = SED_Low
			,DA_Open = SED_Open
			,DA_OpenInt = SED_OpenInt
			,DA_Volume = SED_Volume
	FROM	Stage_EOD_Daily 
			JOIN
			Symbols
				ON	SED_Symbol = S_Symbol
			JOIN
			Daily_Activity
				ON	SED_SR_FK = DA_SR_FK
				AND	SED_Date = DA_Date
				AND	S_PK = DA_S_FK
			JOIN
			Files					--This is to check for "locked" files in previously loaded data, it DOES NOT join to stage. 
				ON	DA_F_FK = F_PK
	WHERE	F_Is_Locked = 0
	;

	--Inserts new records
	INSERT INTO Daily_Activity
		(
		DA_S_FK
		,DA_F_FK
		,DA_SR_FK
		,DA_Changed_By
		,DA_Changed_Date
		,DA_Date
		,DA_Open
		,DA_High
		,DA_Low
		,DA_Close
		,DA_Volume
		,DA_OpenInt
		)
	SELECT
		S_PK
		,SED_F_FK
		,SED_SR_FK
		,SED_Changed_By
		,SED_Changed_Date
		,SED_Date
		,SED_Open
		,SED_High
		,SED_Low
		,SED_Close
		,SED_Volume
		,SED_OpenInt
	FROM	Stage_EOD_Daily
			JOIN
			Symbols
				ON	SED_Symbol = S_Symbol
	AND		NOT EXISTS
					(
					SELECT	*
					FROM	Daily_Activity
					WHERE	DA_S_FK = S_PK
					AND		DA_Date = SED_Date
					AND		DA_SR_FK = SED_SR_FK
					)
	;

COMMIT TRANSACTION EOD_Daily;
GO