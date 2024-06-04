/*
SELECT * FROM symbols
SELECT * FROM FILES
SELECT * FROM Stage_EOD_Manual_Symbols

DELETE FROM FILES WHERE F_PK > 0

*/

--IF OBJECT_ID('Add_Stage_EOD_Manual_Symbols') IS NOT NULL
--DROP PROCEDURE Add_Stage_EOD_Manual_Symbols
--GO

--DROP PROCEDURE Add_Stage_EOD_Manual_Symbols NULL
CREATE OR ALTER PROCEDURE Add_Stage_EOD_Manual_Symbols

--	@F_PK		INT			--value of F_PK in the Files table, referenced by SEMS_F_FK in Stage_EOD_Manual_Symbols

AS

SET NOCOUNT ON;

--checks that @F_PK is valid
--IF (SELECT COUNT(*) FROM Files WHERE F_PK = @F_PK) = 0
--	THROW 50000, 'The value assigned to @F_PK is not valid', 1;

BEGIN TRANSACTION Add_Symbols;

	--updates existing records with new info
	UPDATE	Symbols
	SET		S_Description = LTRIM(RTRIM(SEMS_Description)) --Make sure there's no excess whitespace
			,S_SR_FK = SEMS_SR_FK
			,S_E_FK = E_PK
			,S_F_FK = SEMS_F_FK
			,S_Changed_By = SEMS_Changed_By
			,S_Changed_Date = SEMS_Changed_Date
	FROM	Symbols S1
			JOIN
			Stage_EOD_Manual_Symbols
				ON	S_Symbol = SEMS_Symbol
			JOIN
			Files F1
				ON	SEMS_F_FK = F_PK
			JOIN
			Exchanges
				ON	F_No_Ext = E_Name
	WHERE	S_Description <> LTRIM(RTRIM(SEMS_Description))
	AND		NOT EXISTS (SELECT * FROM Symbols S2 JOIN Files F2 ON S2.S_F_FK = F2.F_PK WHERE S1.S_PK = S2.S_PK AND F2.F_Is_Locked = 1) --checks that the original record isn't flagged as locked
	;


	--inserts new records
	INSERT INTO Symbols
		(
		S_Changed_By
		,S_Changed_Date
		,S_SR_FK
		,S_ST_FK
		,S_E_FK
		,S_F_FK
		,S_Symbol
		,S_Name
		)	
	SELECT		
		SEMS_Changed_By
		,SEMS_Changed_Date
		,SEMS_SR_FK
		,4  --UNKOWN
		,E_PK
		,F_PK
		,RTRIM(LTRIM(SEMS_Symbol))
		,RTRIM(LTRIM(SEMS_Description))
	--select *
	FROM	Stage_EOD_Manual_Symbols
			JOIN
			Files
				ON	F_PK = SEMS_F_FK
			JOIN
			Exchanges
				ON	F_No_Ext = E_Name
	WHERE	NOT EXISTS 
					(
					SELECT	* 
					FROM	Symbols 
					WHERE	S_Symbol = RTRIM(LTRIM(SEMS_Symbol))
					)
	;

COMMIT TRANSACTION Add_Symbols;
GO

