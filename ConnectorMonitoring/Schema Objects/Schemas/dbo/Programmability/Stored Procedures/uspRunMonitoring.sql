CREATE PROCEDURE [dbo].[uspRunMonitoring]
	@StartTime datetime = null --Use these for tests. 
	, @EndTime datetime = null
AS


DECLARE @Now datetime 
	, @Last datetime 
	, @Today date
	, @ToDayOfMonth int
	, @ToDayOfWeek int
	, @Sql varchar(max) ='DECLARE @ThisID uniqueidentifier '
	, @ProcsRun int = 0

select @Now = isnull(@Endtime, getdate())
		, @Last = coalesce(@Starttime, (select max(EndTime) from ExecutionWrapperLog), '01/01/2015')

select @Today = cast(@Now as date)

SELECT @ToDayOfWeek = DayOfWeek_Int
		, @ToDayOfMonth = DATEPART(DAY, @Now)
FROM Calendar
WHERE RefDate = @Today

insert ExecutionWrapperLog(StartTime) values (@Now)
declare @procId int = (select max(ID) from ExecutionWrapperLog where StartTime = @Now)

;
-- Determine which scheduled tasks are valid based on @now and @last.
WITH DailySchedules AS (
	
	select distinct 
		Schedule_Type_ID
		, 'Hourly' as Interval_Type
		, Schedule_Name
		, startTime
	from [dbo].[udfExpandDailySchedules](@Today) e 

	union 

	select distinct 
		Schedule_Type_ID
		, Interval_Type
		, Schedule_Name
		, @Today 
	from ScheduleType
	where (Interval_Type = 'Weekly' and Interval_Day = @ToDayOfWeek)
	or (Interval_Type ='Monthly' and Interval_Day = @ToDayOfMonth)
	or Interval_Type = 'Daily'

), PotentialTasks as (
	
	select 
		s.Interval_Type
		, mp.*
		, case when s.Interval_Type = 'Hourly'
			then s.StartTime
			else s.startTime + cast(isnull(ms.StartTime, '00:00') as datetime) end as FinalStartTime
		, s.StartTime as RawStartTime
		, ms.StartTime as TaskStartTime
	from DailySchedules s
	inner join MonitoringSchedules ms
		on ms.Schedule_Type_ID = s.Schedule_Type_ID
	inner join MonitoringProcedure mp
		on mp.ID = ms.MonitoringProcedure_ID
	where ms.ActiveInd = 1

), FinalTasks as(

	select distinct 
		t.ID
		, Task_Type
		, Client_Name
		, Source_Name
		, Environment
		, Email_From
		, Email_To
		, Email_CC
		, Content_Type
		, IsExternalEmail
		, lastStart.*
		, FinalStartTime
	from PotentialTasks t
	left join (
		select MonitoringProcedure_ID, max(StartTime) as lastStartTime
		from ExecutionLog e
		group by MonitoringProcedure_ID
		) as lastStart
			on lastStart.MonitoringProcedure_ID = t.ID
	where FinalStartTime between @Last and @Now
	and (lastStart.lastStartTime < @Last or lastStart.lastStartTime is null) --I think this is right? 
)

-- For each scheduled task, call SSIS package for values from dbo.MonitoringProcedure asynchronously 

select @sql +=
'

EXECUTE dbo.uspConfigureExecutionParameters '+
dbo.[udfDynamicProcParams]('MonitoringProcedure_ID', ID, 1) +
--dbo.[udfDynamicProcParams]('StartTime', @Last, 0) +
dbo.[udfDynamicProcParams]('StartTime', lastStartTime, 0) +
dbo.[udfDynamicProcParams]('EndTime', @Now, 0) +'
	, @ID = @ThisId output

EXECUTE dbo.uspRun '+
dbo.[udfDynamicProcParams]('MonitoringProcedure_ID', ID, 1) +
dbo.[udfDynamicProcParams]('TaskType',Task_Type, 0) + '
	, @Execution_ID = @ThisId'
	, @ProcsRun += 1

from FinalTasks


exec(@SQL)
	

update ExecutionWrapperLog 
set EndTime = getdate(), ProceduresCalled = @ProcsRun
where ID = @procId

	
	

