CREATE TABLE [dbo].[MonitoringProcedure]
(
	ID INT NOT NULL PRIMARY KEY IDENTITY(1,1)
	, Task_Type	varchar(255) FOREIGN KEY REFERENCES ProcedureType (Task_Type)
	, Client_Name varchar(1000)
	, Source_Name varchar(1000) 
	, Environment varchar(1000)
	, Email_From varchar(1000)
	, Email_To varchar(1000)
	, Email_CC varchar(1000)
	, Content_Type varchar(1000)
	, IsExternalEmail bit 
	, IsInternalEmail bit
)
