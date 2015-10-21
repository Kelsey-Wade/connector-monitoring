CREATE VIEW [dbo].[v_Scheduled_Tasks]
	AS 

select distinct
	Task_Type
	, Schedule_Name
	, StartTime
	, Interval_Type
	, Client_Name
	, Source_Name
	, Environment
	, Interval_Day
	, Hourly_StartTime
	, Hourly_EndTime
	, Email_To
	, Email_CC
	, Email_From
	, IsInternalEmail
	, IsExternalEmail
from MonitoringProcedure p
inner join MonitoringSchedules s
	on s.MonitoringProcedure_ID = p.ID
inner join ScheduleType st
	on st.Schedule_Type_ID = s.Schedule_Type_ID
where s.ActiveInd = 1
