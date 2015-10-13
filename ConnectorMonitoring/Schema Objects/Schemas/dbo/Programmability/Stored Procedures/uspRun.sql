CREATE PROCEDURE [dbo].[uspRun]
	@TaskType varchar(255)
	, @Execution_ID uniqueidentifier
	, @MonitoringProcedure_ID int
AS

declare @ProcName varchar(255) = (select Proc_Name from ProcedureType where Task_Type = @TaskType)
declare @SQL varchar(max) = ''


exec uspLogExecutionStart @MonitoringProcedure_ID = @MonitoringProcedure_ID, @Execution_ID = @Execution_ID
begin try

	select @SQL ='execute ['+@ProcName+'] '
	select @SQL +=  dbo.udfDynamicProcParams(Parameter, Value, case when rn = 1 then 1 else 0 end)
	from 
	(
		select *, row_number() over(order by parameter) as rn
		from ExecutionParameters 
		where Execution_ID = @Execution_ID
	) p
	order by parameter
	exec (@SQL)

end try
begin catch
	exec uspLogExecutionEnd @MonitoringProcedure_ID = @MonitoringProcedure_ID, @Execution_ID = @Execution_ID, @Content = null, @Status = 'Failed'
	return
end catch

exec uspLogExecutionEnd @MonitoringProcedure_ID = @MonitoringProcedure_ID, @Execution_ID = @Execution_ID, @Content = @SQL, @Status = 'Success'
return
