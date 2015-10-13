CREATE PROCEDURE [dbo].[uspConfigureMonitoringSchedule]
	@MonitoringProcedureID int 
	, @ScheduleName varchar(255)
	, @StartTime time
	, @ActiveInd bit = 1

AS

-- TODO: return ID, split scheduling info to separate proc. 

/*

--USE THIS to split parameter-value structure dynamically 

DECLARE @xml as xml, @str as varchar(100)
SET @str='Client=LHCQF,B=ABCDE,C=3'
SET @xml = cast(('<X>'+replace(@str,',','</X><X>')+'</X>') as xml)

select left(pair, charindex('=', pair) - 1) as parameter
		, right(pair, len(pair)-charindex('=', pair)) as value
from(
	SELECT N.value('.', 'varchar(10)') as pair 
	FROM @xml.nodes('X') as T(N)
)x\

--USE THIS to validate parameters provided.
 
SELECT 
	sp.name as ProcName
	, p.name AS Parameter        
	, t.name AS [Type]
	, NULL as value
FROM sys.procedures sp
JOIN sys.parameters p 
    ON sp.object_id = p.object_id
JOIN sys.types t
    ON p.system_type_id = t.system_type_id


*/

declare @msg varchar(1000)
		, @scheduleId int
		, @monitorId int

if not exists(select top 1 1 from dbo.MonitoringProcedure where ID = @MonitoringProcedureID)
begin
	select @msg = 'Invalid procedure ID provided (' + @TaskType + ')'
	raiserror(@msg, 16, 1)
	return
end

select 
	@scheduleId = Schedule_Type_ID 
from dbo.ScheduleType 
where Schedule_Name = @ScheduleName

if @scheduleId is null
	begin
		select @msg = 'Unknown schedule ' + @ScheduleName + ' specified. Exiting'
		raiserror(@msg, 16, 1)
		return
	end

update s
set s.StartTime = @StartTime
	, s.ActiveInd = @ActiveInd
from [dbo].[MonitoringSchedules] s
where s.Schedule_Type_ID = @scheduleId
and s.MonitoringProcedure_ID = @monitorId

insert [dbo].[MonitoringSchedules] (MonitoringProcedure_ID,Schedule_Type_ID,StartTime)
select @monitorId, @scheduleId, @startTime, @ActiveInd
where not exists(select 1 
				 from [dbo].[MonitoringSchedules] 
				 where s.Schedule_Type_ID = @scheduleId 
				 and s.MonitoringProcedure_ID = @monitorId)




