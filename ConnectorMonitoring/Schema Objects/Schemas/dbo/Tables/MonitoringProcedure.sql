CREATE TABLE [dbo].[MonitoringProcedure]
(
	ID INT NOT NULL PRIMARY KEY IDENTITY(1,1)
	, Task_Type	varchar(255) FOREIGN KEY REFERENCES ProcedureType (Task_Type)
	, Client_Name varchar(100)
	, Source_Name varchar(100) 
	, Environment varchar(100)
	, Email_From varchar(100)
	, Email_To varchar(100)
	, Email_CC varchar(100)
	, Content_Type varchar(100)
	, IsExternalEmail bit 
	, IsInternalEmail bit
)
