CREATE PROCEDURE [dbo].[uspConfigureExecutionParameters]
	@MonitoringProcedure_ID int
	, @StartTime datetime
	, @EndTime datetime
	, @ID uniqueidentifier output
AS



select @ID = newid();

with ProcedureParams as(

	select distinct
		p.name AS Parameter        
		, t.name AS DataType
	from sys.procedures sp
	inner join sys.parameters p 
		ON sp.object_id = p.object_id
	inner join sys.types t
		ON p.system_type_id = t.system_type_id
	inner join ProcedureType pt
		on pt.Proc_Name = sp.name
	inner join MonitoringProcedure mp
		on mp.Task_Type = pt.Task_Type
	where mp.ID = @MonitoringProcedure_ID

), ProvidedParams as (
	
	select 
		p.Parameter
		, p.Value
	from MonitoringParameters p
	where p.MonitoringProcedure_ID = @MonitoringProcedure_ID

	union 

	select 
		'@'+parameter as Parameter
		, nullif(value, '') as Value
	from (
		select 
			Client_Name as Client
			, Source_Name as Source
			, isnull(Email_From, '') as Email_From
			, isnull(Email_To, '') as Email_To
			, isnull(Email_CC, '') as Email_CC
			, isnull(Environment, '') as Environment
			, isnull(Content_Type, '') as Content_Type
			, cast(IsExternalEmail as varchar(1000)) as IsExternalEmail
			, cast(IsInternalEmail as varchar(1000)) as IsInternalEmail
		from MonitoringProcedure
		where id = @MonitoringProcedure_ID
	) f
	UNPIVOT (
		value 
		for parameter in([Email_From],[Email_To],[Email_CC],[Environment],[Client],[Source],[Content_Type], [IsExternalEmail], [IsInternalEmail])
	) u

	union select '@StartTime' as Parameter, cast(@StartTime as varchar) as Value
	union select '@EndTime' as Parameter, cast(@EndTime as varchar) as Value
	
)

insert ExecutionParameters(Execution_ID, MonitoringProcedure_ID, Parameter, Value)
select distinct @ID, @MonitoringProcedure_ID, p.Parameter, p.Value
from ProvidedParams p
inner join ProcedureParams prc
	on prc.Parameter = p.Parameter



