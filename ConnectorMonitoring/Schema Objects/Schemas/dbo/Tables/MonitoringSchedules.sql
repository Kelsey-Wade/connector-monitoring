CREATE TABLE [dbo].[MonitoringSchedules]
(
	ID INT NOT NULL PRIMARY KEY IDENTITY(1,1)
	, MonitoringProcedure_ID INT FOREIGN KEY REFERENCES MonitoringProcedure (ID) 
	, Schedule_Type_ID INT FOREIGN KEY REFERENCES ScheduleType (Schedule_Type_ID)
	, StartTime time
	, ActiveInd bit
)
