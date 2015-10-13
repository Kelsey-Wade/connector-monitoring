DECLARE @scheduleTypes TABLE
(
	Schedule_Name varchar(100)
	, Interval_Type varchar(100) -- Hourly, Daily, Weekly, Monthly
	, Interval_Day int 
		-- If Interval_Type = Monthly => Day of Month. 
		-- If Interval_Type = Weekly  => Day of week (1-7, based on datepart(weekday...))
	, Hourly_StartTime time -- Earliest in the day that an hourly schedule can start.
	, Hourly_EndTime time   -- Latest time in the day that an hourly schedule can start. 
	, Hourly_Frequency int
	, Hourly_Frequency_Units varchar(100) --Hours, Minutes
)

INSERT @scheduleTypes(Schedule_Name, Interval_Type, Interval_Day, Hourly_StartTime, Hourly_EndTime, Hourly_Frequency, Hourly_Frequency_Units)
VALUES
('Daily','Daily',NULL,NULL,NULL,NULL,NULL),
('Weekly Monday','Weekly',2,NULL,NULL,NULL,NULL),--Use sql datepart convention for day of week integers.
('Weekly Tuesday','Weekly',3,NULL,NULL,NULL,NULL),
('Weekly Wednesday','Weekly',4,NULL,NULL,NULL,NULL),
('Weekly Thursday','Weekly',5,NULL,NULL,NULL,NULL),
('Weekly Friday','Weekly',6,NULL,NULL,NULL,NULL),
('Weekly Saturday','Weekly',7,NULL,NULL,NULL,NULL),
('Weekly Sunday','Weekly',1,NULL,NULL,NULL,NULL),

('Monthly 1st Day','Monthly',1,NULL,NULL,NULL,NULL),
('Monthly 10th Day','Monthly',10,NULL,NULL,NULL,NULL),
('Monthly 15th Day','Monthly',15,NULL,NULL,NULL,NULL),

('Every Hour','Hourly',NULL,NULL,NULL,1,'HOUR'), 
('Every Hour 9-5','Hourly',NULL,'09:00','17:00',1,'HOUR'), 
('Every 30 Minutes','Hourly',NULL,NULL,NULL,30,'MINUTE'),
('Every 10 Minutes','Hourly',NULL,NULL,NULL,10,'MINUTE'),
('Every 15 Minutes','Hourly',NULL,NULL,NULL,15,'MINUTE')


UPDATE s
SET s.Interval_Type = t.Interval_Type
	, s.Interval_Day = t.Interval_Day
	, s.Hourly_StartTime = t.Hourly_StartTime 
	, s.Hourly_EndTime = t.Hourly_EndTime   
	, s.Hourly_Frequency = t.Hourly_Frequency
	, s.Hourly_Frequency_Units = t.Hourly_Frequency_Units
FROM dbo.ScheduleType s
INNER JOIN @scheduleTypes t
	on t.Schedule_Name = s.Schedule_Name

INSERT dbo.ScheduleType (
	Schedule_Name
	, Interval_Type
	, Hourly_StartTime
	, Hourly_EndTime
	, Hourly_Frequency
	, Hourly_Frequency_Units
)
SELECT 
	t.Schedule_Name
	, t.Interval_Type
	, t.Hourly_StartTime
	, t.Hourly_EndTime
	, t.Hourly_Frequency
	, t.Hourly_Frequency_Units
FROM @scheduleTypes t
LEFT JOIN dbo.ScheduleType s
	on t.Schedule_Name = s.Schedule_Name
WHERE s.Schedule_Type_ID IS NULL