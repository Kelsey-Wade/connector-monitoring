update dbo.MonitoringSchedules
set ActiveInd = 0


declare @currentID int

EXEC [dbo].[uspConfigureMonitoring]
	@TaskType = 'Check Connector Deploys'
	, @Email_To = 'jeff.solomon@arcadiasolutions.com'
	, @Content_Type = 'HTML'
	, @IsExternalEmail = 0
	, @IsInternalEmail = 1
	, @ID = @currentID output

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '16:00'

--EXEC [dbo].[uspConfigureMonitoring]
--	@TaskType = 'SendFileReceivedNotification'
--	, @Client = 'TSTCLI2'
--	, @Source = 'TESTCON'
--	, @Environment = 'DEV'
--	, @Email_From = 'jeff.solomon@arcadiasolutions.com'
--	, @Email_To = 'jeff.solomon@arcadiasolutions.com'
--	, @Email_CC = null
--	, @Content_Type = 'HTML'
--	, @IsExternalEmail = 0
--	, @IsInternalEmail = 1
--	, @ID = @currentID output

--EXEC dbo.uspConfigureMonitoringSchedules 
--	@MonitoringProcedure_ID = @currentId
--	, @ScheduleName = 'Daily'
--	, @StartTime = '11:00' 


--EXEC [dbo].[uspConfigureMonitoring]
--	@TaskType = 'SendFileReceivedNotification'
--	, @Client = 'TSTCLI3'
--	, @Source = 'TESTCON'
--	, @Environment = 'DEV'
--	, @Email_From = 'jeff.solomon@arcadiasolutions.com'
--	, @Email_To = 'jeff.solomon@arcadiasolutions.com'
--	, @Email_CC = null
--	, @Content_Type = 'HTML'
--	, @IsExternalEmail = 0
--	, @IsInternalEmail = 1
--	, @ID = @currentID output

----EXEC dbo.uspConfigureMonitoringSchedules 
----	@MonitoringProcedure_ID = @currentId
----	, @ScheduleName = 'Weekly Monday'
----	, @StartTime = '13:00'

----EXEC dbo.uspConfigureMonitoringSchedules 
----	@MonitoringProcedure_ID = @currentId
----	, @ScheduleName = 'Weekly Wednesday'
----	, @StartTime = '13:00'

--EXEC dbo.uspConfigureMonitoringSchedules 
--	@MonitoringProcedure_ID = @currentId
--	, @ScheduleName = 'Weekly Friday'
--	, @StartTime = '13:00'

