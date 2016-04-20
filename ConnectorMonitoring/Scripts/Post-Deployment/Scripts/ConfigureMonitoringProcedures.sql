update dbo.MonitoringSchedules
set ActiveInd = 0


declare @currentID int

EXEC [dbo].[uspConfigureMonitoring]
	@TaskType = 'Check Connector Deploys'
	, @Email_To = 'jeff.solomon@arcadiasolutions.com;omar.nema@arcadiasolutions.com'
	, @Content_Type = 'HTML'
	, @IsExternalEmail = 0
	, @IsInternalEmail = 1
	, @ID = @currentID output

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '16:30'

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '9:00'

EXEC [dbo].[uspConfigureMonitoring]
	@TaskType = 'SendFileReceivedNotification'
	, @Source = 'PR-LAORIED'
	, @Environment = 'PRD'
	, @Email_From = null
	, @Email_To = 'jeff.solomon@arcadiasolutions.com;steve.copans@arcadiasolutions.com'
	, @Email_CC = null
	, @Content_Type = 'HTML'
	, @IsExternalEmail = 0
	, @IsInternalEmail = 1
	, @AdditionalParameters = 'Group=GR-LAED,DoNotSend=0'
	, @ID = @currentID output
	

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '09:00' 


EXEC [dbo].[uspConfigureMonitoring]
	@TaskType = 'SendFileReceivedNotification'
	, @Source = '%'
	, @Environment = 'PRD'
	, @Email_From = null
	, @Email_To = 'jeff.solomon@arcadiasolutions.com'
	, @Email_CC = null
	, @Content_Type = 'HTML'
	, @IsExternalEmail = 0
	, @IsInternalEmail = 1
	, @AdditionalParameters = 'Group=GR-LAED,DoNotSend=0'
	, @ID = @currentID output
	

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '12:30' 


EXEC [dbo].[uspConfigureMonitoring]
	@TaskType = 'Check for Failed SFTPs'
	, @Email_To = 'jeff.solomon@arcadiasolutions.com;InformaticaAlertsCT@arcadiasolutions.com;omar.nema@arcadiasolutions.com'
	, @Content_Type = 'HTML'
	, @IsExternalEmail = 0
	, @IsInternalEmail = 1
	, @ID = @currentID output

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '09:30'

EXEC [dbo].[uspConfigureMonitoring]
	@TaskType = 'Update master seed list'
	, @Email_To = null
	, @Content_Type = null
	, @IsExternalEmail = 0
	, @IsInternalEmail = 1
	, @ID = @currentID output

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '07:30'

--LHCQF Error Reporting to CSV
EXEC [dbo].[uspConfigureMonitoring]
	@TaskType = 'LHCQF Error Reporting to CSV'
	, @Environment = 'PRD'
	, @ID = @currentID output

EXEC dbo.uspConfigureMonitoringSchedules 
	@MonitoringProcedure_ID = @currentId
	, @ScheduleName = 'Daily'
	, @StartTime = '09:00'

	