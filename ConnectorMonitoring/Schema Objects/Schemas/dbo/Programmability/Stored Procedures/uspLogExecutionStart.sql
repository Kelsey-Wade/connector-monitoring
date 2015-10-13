CREATE PROCEDURE [dbo].[uspLogExecutionStart]
	@MonitoringProcedure_ID int
	, @Execution_ID uniqueidentifier 

AS


INSERT ExecutionLog (MonitoringProcedure_ID, Execution_ID, StartTime)
VALUES (@MonitoringProcedure_ID, @Execution_ID, GETDATE())

