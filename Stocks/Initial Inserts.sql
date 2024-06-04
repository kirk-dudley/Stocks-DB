SELECT * FROM Sources

SET IDENTITY_INSERT Sources ON
GO

INSERT INTO Sources
	(
	SR_PK
	,SR_Name
	,SR_Description
	,SR_URL
	)
VALUES (0, 'EOD Data', 'Subscription', 'https://eoddata.com/'), (1, 'Kaggle', 'Free', 'https://www.kaggle.com/datasets'), (2, 'Other', 'Manual/One Offs/Others', nULL)
GO

INSERT INTO Sources
	(
	SR_PK
	,SR_Name
	,SR_SR_FK
	,SR_Description
	,SR_URL
	,SR_Stage_Table
	,SR_Data_Directory
	)

SELECT	3
		,'EOD Data Daily'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'EOD Data')
		,'Daily automated files per day and exchange'
		,'https://eoddata.com/'
		,'Stage_EOD_Daily'
		,'D:\Stock_Data\EODData\EODData - Dailys'

UNION

SELECT	4
		,'EOD Data Exchanges'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'EOD Data')
		,'XML of exchanges from EOD Daily Automation'
		,'https://eoddata.com/'
		,'Stage_EOD_Exchanges'
		,'D:\Stock_Data\EODData\EODData - Dailys'
		
		
UNION

SELECT	5
		,'EOD Data Historic'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'EOD Data')
		,'Historic .zips per year and exchange'
		,'https://eoddata.com/'
		,'Stage_EOD_Daily'
		,'D:\Stock_Data\EODData\EODData_Historic_UnZip'

UNION
		
SELECT	6
		,'EOD Data Manual Download Symbols'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'EOD Data')
		,'Manual download of .TXT files of symbols and names from EOD Data'
		,'https://eoddata.com/'
		,'Stage_EOD_Exchanges'
		,'D:\Stock_Data\EODData\EODData - Dailys'
		
UNION
		
SELECT	7
		,'EOD Data Symbols'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'EOD Data')
		,'XML of symbols from EOD Daily Automation'
		,'https://eoddata.com/'
		,'Stage_EOD_Symbols'
		,'D:\Stock_Data\EODData\EODData - Dailys'

UNION                                   

SELECT	8
		,'Kaggle Bitcoin'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'Kaggle')
		,'Kaggle Bitcoin Data Set'
		,'https://www.kaggle.com/datasets/priyamchoksi/bitcoin-historical-prices-and-activity-2010-2024'
		,'Stage_Kaggle_Bitcoin'
		,'D:\Stock_Data\Kaggle\Bitcoin'

UNION                                   
  		
SELECT	9
		,'Kaggle ETFs'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'Kaggle')
		,'Kaggle Historic ETF Data Set'
		,'https://www.kaggle.com/datasets/borismarjanovic/price-volume-data-for-all-us-stocks-etfs'
		,'Stage_Kaggle_Stocks'
		,'D:\Stock_Data\Kaggle\ETFs'
		
UNION                                   
 		
SELECT	10
		,'Kaggle Stocks'
		,(SELECT SR_PK FROM Sources WHERE SR_Name = 'Kaggle')
		,'Kaggle Historic Stocks Data Set'
		,'https://www.kaggle.com/datasets/borismarjanovic/price-volume-data-for-all-us-stocks-etfs'
		,'Stage_Kaggle_Stocks'
		,'D:\Stock_Data\Kaggle\Stocks'

ORDER BY 1
GO		

SET IDENTITY_INSERT Sources OFF
GO

INSERT INTO Files(F_FileName, F_SR_FK) VALUES('\No File Placeholder.', (SELECT SR_PK FROM Sources WHERE SR_Name = 'Other'))
GO

SET IDENTITY_INSERT Stock_Type ON
GO

INSERT INTO Stock_Type
	(
	ST_PK
	,ST_Name
	,ST_Description
	)
VALUES
	(0, 'Stock', 'Common and Preferred Stocks'), (1, 'Mutual Funds', 'Mutual Funds'), (2, 'Index Funds', 'Index Funds'), (3, 'ETF', 'Exchange-Traded Funds'), (4, 'Unknown', 'Unknown')
GO

INSERT INTO Exchanges
	(
	E_F_FK
	,E_Name
	)
VALUES (0, 'Unknown')
GO
