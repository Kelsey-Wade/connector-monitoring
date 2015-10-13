CREATE FUNCTION [dbo].[udfExpandDailySchedules]
(
	@date date 
)
RETURNS @returntable TABLE
(
	Schedule_Type_ID int
	, Schedule_Name varchar(255)
	, startTime datetime
	, mins int
)
AS
BEGIN
	with hourlySchedules as (

	select distinct Schedule_Type_ID
		, Schedule_Name
		, cast(@date as datetime) + cast(isnull(Hourly_StartTime, '00:00') as datetime) as startTime
		, cast(@date as datetime) + isnull(cast(Hourly_EndTime as datetime), dateadd(day, 1, 0)) as endTime
		, case when Hourly_Frequency_Units = 'HOUR' 
			then Hourly_Frequency * 60 
			else Hourly_Frequency end as mins
	from ScheduleType
	where Interval_Type = 'Hourly'

	union all

	select Schedule_Type_ID
		, Schedule_Name
		, dateadd(minute, mins, startTime) as startTime
		, endTime
		, mins
	from hourlySchedules s
	where dateadd(minute, mins, startTime) <= endTime

	)

	insert @returntable (Schedule_Type_ID, Schedule_Name, startTime, mins)
	select distinct Schedule_Type_ID, Schedule_Name, startTime, mins
	from hourlySchedules 
	OPTION (MAXRECURSION 0)

	return
END




