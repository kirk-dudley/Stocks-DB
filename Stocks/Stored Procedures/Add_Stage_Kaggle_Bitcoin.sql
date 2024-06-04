
CREATE OR ALTER PROCEDURE Add_Stage_Kaggle_Bitcoin

AS

--Checks for a bitcoin symbol

BEGIN TRANSACTION Kaggle_Bitcoin;

	IF NOT EXISTS (SELECT * FROM Symbols WHERE S_Symbol = 'BTC')
	BEGIN
		INSERT INTO Symbols
			(
			S_SR_FK				
			,S_ST_FK
			,S_E_FK
			,S_F_FK
			,S_Changed_By
			,S_Changed_Date
			,S_Symbol
			,S_Name
			)
		SELECT DISTINCT 
			SKB_SR_FK
			,4
			,0
			,SKB_F_FK
			,SKB_Changed_By
			,SKB_Changed_Date
			,'BTC'
			,'BitCoin'
		FROM	Stage_Kaggle_Bitcoin
	END
	;
--Updates existing

	UPDATE	Daily_Activity
	SET		DA_Changed_By = SKB_Changed_By
			,DA_Changed_Date = SKB_Changed_Date
			,DA_Close = SKB_Close
			,DA_F_FK = SKB_F_FK
			,DA_High = SKB_High
			,DA_Low = SKB_Low
			,DA_Open = SKB_Open
			,DA_Volume = SKB_Volume
	FROM	Stage_Kaggle_Bitcoin
			JOIN
			Symbols
				ON	'BTC' = S_Symbol
			JOIN
			Daily_Activity
				ON	SKB_SR_FK = DA_SR_FK
				AND	SKB_End = DA_Date
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
		)
	SELECT
		S_PK
		,SKB_F_FK
		,SKB_SR_FK
		,SKB_Changed_By
		,SKB_Changed_Date
		,SKB_End
		,SKB_Open
		,SKB_High
		,SKB_Low
		,SKB_Close
		,SKB_Volume
	FROM	Stage_Kaggle_Bitcoin
			JOIN
			Symbols
				ON	'BTC' = S_Symbol
	AND		NOT EXISTS
					(
					SELECT	*
					FROM	Daily_Activity
					WHERE	DA_S_FK = S_PK
					AND		DA_Date = SKB_End
					AND		DA_SR_FK = SKB_SR_FK
					)
	ORDER BY SKB_End
	;

COMMIT TRANSACTION Kaggle_Bitcoin;
GO

