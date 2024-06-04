
--Get_File_IDs 'C:\TEMP\BOB.TXT', 'Test Data'
--SELECT * FROM FILES JOIN SOURCES ON F_SR_FK = SR_PK

CREATE OR ALTER PROCEDURE Get_File_IDs

	@Filename		VARCHAR(260)
	,@SR_PK			INT

AS

SET NOCOUNT ON

--checks that @SR_PK is valid
IF (SELECT COUNT(*) FROM Sources WHERE SR_PK = @SR_PK) = 0
	THROW 50000, 'The value assigned to @SR_PK is not valid', 1;

--checks that @Filename is valid
IF ISNULL(@Filename, '') = ''
	THROW 50000, 'The value assigned to @Filename is not valid', 1;

BEGIN TRANSACTION IDS;

	--inserts values
	INSERT INTO Files
		(
		F_FileName
		,F_SR_FK
		)
	SELECT
		@Filename
		,@SR_PK
	;
--gets timestamp, fileid
	SELECT	F_PK
			,F_Changed_Date
	FROM	Files
	WHERE	F_PK = @@IDENTITY
	;

COMMIT TRANSACTION IDs;
GO