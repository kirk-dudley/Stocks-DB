
CREATE OR ALTER PROCEDURE Add_Source

	@Name				NVARCHAR(255)	
	,@ParentID			INT	= NULL
	,@Description		NVARCHAR(MAX) = NULL
	,@Stage_Table		SYSNAME = NULL
	,@Data_Directory	NVARCHAR(255) = NULL
	,@Error_Directory	NVARCHAR(255) = NULL
	,@Archive_Directory	NVARCHAR(255) = NULL
	,@URL				NVARCHAR(255) = NULL
	,@PK				INT = NULL

AS

BEGIN TRANSACTION Add_Source;

	--If explicit ID is set, sets identity_insert on, and inserts
	IF @PK IS NOT NULL
	BEGIN
		SET IDENTITY_INSERT Sources ON;
		INSERT INTO Sources
			(
			SR_PK
			,SR_SR_FK
			,SR_Name
			,SR_Description
			,SR_Stage_Table
			,SR_Data_Directory
			,SR_Error_Directory
			,SR_Archive_Directory
			,SR_URL
			)
		SELECT
			@PK
			,@ParentID
			,@Name
			,@Description
			,@Stage_Table
			,@Data_Directory
			,@Error_Directory
			,@Archive_Directory
			,@URL
			;
		SET IDENTITY_INSERT Sources OFF;
	END
	ELSE
	BEGIN		--if identity is not set, a normal insert
		INSERT INTO Sources
			(
			SR_SR_FK
			,SR_Name
			,SR_Description
			,SR_Stage_Table
			,SR_Data_Directory
			,SR_Error_Directory
			,SR_Archive_Directory
			,SR_URL
			)
		SELECT
			@ParentID
			,@Name
			,@Description
			,@Stage_Table
			,@Data_Directory
			,@Error_Directory
			,@Archive_Directory
			,@URL
	END
	;
COMMIT TRANSACTION Add_Source;
GO


