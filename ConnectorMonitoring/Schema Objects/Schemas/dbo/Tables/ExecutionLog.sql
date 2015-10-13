CREATE TABLE [dbo].[ExecutionLog]
(
	[Id] int NOT NULL PRIMARY KEY IDENTITY(1,1)
	, MonitoringProcedure_ID INT FOREIGN KEY REFERENCES MonitoringProcedure (ID) 
	, Execution_ID uniqueidentifier
	, StartTime datetime
	, EndTime datetime
	, Content varchar(max)
	, Execution_Status varchar(100)
)
