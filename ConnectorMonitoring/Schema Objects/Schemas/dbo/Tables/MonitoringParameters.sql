CREATE TABLE [dbo].[MonitoringParameters] 
(
	MonitoringProcedure_ID INT NOT NULL FOREIGN KEY REFERENCES MonitoringProcedure (ID)
	, Parameter varchar(255) NOT NULL
	, DataType varchar(255) NULL
	, Value varchar(1000) NOT NULL
CONSTRAINT pk_Params PRIMARY KEY (MonitoringProcedure_ID, Parameter)
)
