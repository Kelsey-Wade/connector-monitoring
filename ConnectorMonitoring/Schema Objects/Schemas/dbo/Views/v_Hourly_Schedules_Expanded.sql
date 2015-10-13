CREATE VIEW [dbo].[v_Hourly_Schedules_Expanded]
	AS 

with hourlySchedules as (

select distinct Schedule_Type_ID
	, Schedule_Name
	, isnull(cast(cast(getdate() as date) as datetime) + cast(Hourly_StartTime as datetime)
		, cast(getdate() as date)) as startTime
	, isnull(cast(cast(getdate() as date) as datetime) + cast(Hourly_EndTime as datetime)
		, dateadd(day, 1, cast(getdate() as date))) as endTime
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

select distinct Schedule_Type_ID, Schedule_Name, startTime, mins
from hourlySchedules

