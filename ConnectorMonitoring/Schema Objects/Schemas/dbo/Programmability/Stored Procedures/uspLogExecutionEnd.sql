CREATE PROCEDURE [dbo].[uspLogExecutionEnd]
	@MonitoringProcedure_ID int
	, @Execution_ID uniqueidentifier 
	, @Content varchar(max) = null
	, @Status varchar(255)

AS

update ExecutionLog 
set EndTime = GETDATE()
	, Execution_Status = @Status
	, Content = @Content
where MonitoringProcedure_ID = @MonitoringProcedure_ID 
and Execution_ID = @Execution_ID

