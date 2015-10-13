CREATE PROCEDURE [dbo].[uspConfigureMonitoringSchedules]
	@MonitoringProcedure_ID int
	, @ScheduleName varchar(255)
	, @startTime time = null
AS

declare @scheduleId int = (select Schedule_Type_ID from ScheduleType where Schedule_Name = @ScheduleName)

update m
	set m.ActiveInd = 1
from MonitoringSchedules m
where MonitoringProcedure_ID = @MonitoringProcedure_ID 
and Schedule_Type_ID = @scheduleId 
and (StartTime = @startTime or isnull(StartTime, @startTime) is null) 

insert MonitoringSchedules (MonitoringProcedure_ID, Schedule_Type_ID, StartTime, ActiveInd) 
select @MonitoringProcedure_ID, @scheduleId, @startTime, 1
where not exists(
	select 1 
	from MonitoringSchedules 
	where MonitoringProcedure_ID = @MonitoringProcedure_ID 
	and Schedule_Type_ID = @scheduleId 
	and (StartTime = @startTime or isnull(StartTime, @startTime) is null)
	)


