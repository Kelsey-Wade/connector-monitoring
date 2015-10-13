CREATE PROCEDURE [dbo].[uspConfigureMonitoring]
	@TaskType varchar(255)
	, @Client varchar(100) = null
	, @Source varchar(100) = null
	, @Environment varchar(100) = null
	, @Email_From varchar(1000) = null
	, @Email_To varchar(1000) = null
	, @Email_CC varchar(1000) = null
	, @Content_Type varchar(1000) = null
	, @IsExternalEmail bit = 0 
	, @IsInternalEmail bit = 0 
	, @AdditionalParameters varchar(max) = '' --attribute value pairs, e.g. 'a=b,c=d,e=f'
	, @ID int OUTPUT 
AS


declare @msg varchar(1000)

--Confirm task type exists. 
if not exists(select top 1 1 from dbo.ProcedureType where Task_Type = @TaskType)
begin
	select @msg = 'Unknown task type ' + @TaskType
	raiserror(@msg, 16, 1)
	return
end


--Update/insert MonitoringProcedure Table.
update m 
set m.Email_From = @Email_From
	, m.Email_To = @Email_To
	, m.Email_CC = @Email_CC
	, m.Content_Type = @Content_Type
	, m.IsExternalEmail = @IsExternalEmail
	, m.IsInternalEmail = @IsInternalEmail
from dbo.MonitoringProcedure m
where isnull(m.Client_Name, '<m>') = isnull(@Client, '<m>')
and isnull(m.Source_Name, '<m>') = isnull(@Source, '<m>')
and isnull(m.Environment, '<m>') = isnull(@Environment, '<m>') 
and m.Task_Type = @TaskType


insert dbo.MonitoringProcedure
(
	Task_Type
	, Client_Name
	, Source_Name
	, Environment
	, Email_From
	, Email_To
	, Email_CC
	, Content_Type
	, IsExternalEmail
	, IsInternalEmail
)
select	
	@TaskType
	, @Client
	, @Source
	, @Environment
	, @Email_From
	, @Email_To
	, @Email_CC
	, @Content_Type
	, @IsExternalEmail
	, @IsInternalEmail
where not exists (	select 1 
					from dbo.MonitoringProcedure m
					where isnull(m.Client_Name, '<m>') = isnull(@Client, '<m>')
					and isnull(m.Source_Name, '<m>') = isnull(@Source, '<m>')
					and isnull(m.Environment, '<m>') = isnull(@Environment, '<m>')
					and m.Task_Type = @TaskType)

		
select @ID = id 
from dbo.MonitoringProcedure m 
where isnull(m.Client_Name, '<m>') = isnull(@Client, '<m>')
and isnull(m.Source_Name, '<m>') = isnull(@Source, '<m>')
and isnull(m.Environment, '<m>') = isnull(@Environment, '<m>')
and m.Task_Type = @TaskType


--Split out parameters and put in table
delete from MonitoringParameters where MonitoringProcedure_ID = @ID

insert dbo.MonitoringParameters(MonitoringProcedure_ID, Parameter, Value)
select @ID, '@'+Parameter, value 
from dbo.udfSplitParameterString(@AdditionalParameters)
