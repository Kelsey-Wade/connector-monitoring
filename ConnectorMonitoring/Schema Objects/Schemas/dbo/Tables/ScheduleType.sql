CREATE TABLE [dbo].[ScheduleType]
(
	Schedule_Type_ID INT NOT NULL PRIMARY KEY IDENTITY(1,1)
	, Schedule_Name varchar(100)
	, Interval_Type varchar(100) -- Hourly, Daily, Weekly, Monthly
	, Interval_Day int 
		-- If Interval_Type = Monthly => Day of Month. 
		-- If Interval_Type = Weekly  => Day of week (1-7, based on datepart(weekday...))
	, Hourly_StartTime time -- Earliest in the day that an hourly schedule can start. 
	, Hourly_EndTime time   -- Latest time in the day that an hourly schedule can start. 
	, Hourly_Frequency int
	, Hourly_Frequency_Units varchar(100) --Hours, Minutes
CONSTRAINT chk_ValidSchedule 
CHECK (
	Interval_Type = 'Daily'
	
	OR (Interval_Type IN ('Weekly','Monthly') AND
		Interval_Day >= 1 AND 
		Interval_Day <= 31)
	
	OR (Interval_Type = 'Hourly' and
		Hourly_Frequency is not null and 
		Hourly_Frequency_Units IN ('Hour','Minute'))
	)
)
