CREATE TABLE [dbo].ExecutionParameters
(
	MonitoringProcedure_ID INT NOT NULL FOREIGN KEY REFERENCES MonitoringProcedure (ID)
	, Execution_ID  uniqueidentifier NOT NULL
	, Parameter varchar(255) NOT NULL
	, DataType varchar(255) NULL
	, Value varchar(1000) NULL
CONSTRAINT pk_ExecutionParams PRIMARY KEY (Execution_ID, Parameter)
)
