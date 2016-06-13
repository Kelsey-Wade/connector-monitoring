CREATE PROCEDURE [dbo].[uspLHCQFErrorReporting](
	 @Environment varchar(100) = 'PRD'
	, @StartTime datetime = null
	, @EndTime datetime = null
	, @SourceList xml = '
<Sources>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-LAPATH"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-LASMHED"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="GR-LAED" Display="Orion ED Feed"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-LAORIED" Display="Orion ED Feed"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-LAHH"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-LARMC"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-LARMC"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-OCHSNERED"></Source>
	<Source ServerName="LHCQFSQLPRD02" Source="PR-LAMOELG"></Source>
</Sources>
'
	)
 as

select @StartTime = isnull(@StartTime, dateadd(day, -1, getdate()))
		, @EndTime = isnull(@EndTime, getdate());

declare --Test categories (Stage Display Names)
		@Cat_EncryptedFilesReceived varchar(100) = 'Encrypted Files Received'
		, @Cat_Decrypt varchar(100) = 'Decrypt'
		, @Cat_FilePP varchar(100) = 'File Preprocess'
		, @Cat_InformaticaLoad varchar(100) = 'Informatica Load'
		, @Cat_Prestaging varchar(100) = 'Prestaging'
		--Test Types
		, @Test_FileSize varchar(100) = 'File Size (KB)'
		, @Test_RowCount varchar(100) = 'Row Count'
		, @Test_NumberOfFiles varchar(100) = 'Number Of Files'
		, @Test_StatusOfStep varchar(100) = 'Status of Step'
		--Statuses displayed in final table
		, @Status_OK varchar(100) = 'OK'
		, @Status_Warning varchar(100) = 'WARNING'
		--Stages (from task flow naming conventions or derived from file log)
		, @Stage_SFTP varchar(10) = 'SFTP'
		, @Stage_Decrypt varchar(100) = 'Decrypt_All'
		, @Stage_FilePP varchar(100) = 'PreProcessing'
		, @Stage_FilePPTask varchar(100) = 'PreProcess_FlatFiles'
		--From Informatica Logs
		, @InformaticaSuccess varchar(100) = 'Success'
		--File Naming convention to get timestamps: 
		, @FlatFileDateStampConvention varchar(200) = '#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]#[_]#[0-9][0-9][0-9][0-9]#[_]%' 


--Temp table management.
if object_id('tempdb..#sources') is not null drop table #sources
if object_id('tempdb..#fileLog') is not null drop table #fileLog
if object_id('tempdb..#fileLogClean') is not null drop table #fileLogClean
if object_id('tempdb..#informaticaLog') is not null drop table #informaticaLog
if object_id('tempdb..#informaticaLogClean') is not null drop table #informaticaLogClean
if object_id('tempdb..#results') is not null drop table #results

--Get Sources from XML input
select Sources.source.value('@Source','varchar(100)') as Source
	, Sources.source.value('@Display','varchar(100)') as Display
	, 0 as CanQueryDB
	, 0 as CanQueryTable
	, ISNULL(
		Sources.source.value('@ServerName','varchar(100)') , 
		'PRESTGSQL' + @Environment + '01' 
		) AS ServerName
	, replace(Sources.source.value('@Source','varchar(100)'), 'PR-', '') + '_PRESTAGING_' + @Environment as DbName 
into #sources
from @SourceList.nodes('Sources/Source') as Sources(source)


--File Intake Logs
select distinct
	upper(@Environment) as Environment
	, right(FileName, charindex('\', reverse(fileName))-1) as FileNameShort
	, 'PRS_' + p.Arc_Presource_Acronym + '_' + @Environment + '_PRS_Decrypt_ALL' as taskName
	, case when f.FileName like '%[_]SFTP[_]%' then @Stage_SFTP else @Stage_FilePP end as stage
	, p.Arc_Presource_Acronym
	, isnull(s.Display, p.Arc_Presource_Name) as Arc_Presource_Name
	, f.Id
	, f.Sftp_Id
	, f.ErrorMessage
	, f.[RowCount]
	, f.[FileName]
	, f.[FileSize]
	, f.[Timestamp]
into #fileLog
from InformaticaConfig_DEV.maint.FileIntakeLog f
inner join InformaticaConfig_DEV.dbo.arc_presource p
	on p.arc_sftp_extract_id = f.sftp_id
inner join #sources s
	on s.source = p.arc_presource_acronym
where  (f.FileName like '%\'+@Environment+'\%' or f.FileName like '%SFTP[_]'+@Environment+'%')


--Informatica Logs
select l.Inf_Object_Name
		, l.Inf_StartTime
		, l.Inf_EndTime
		, l.Inf_ErrorMessage
		, l.Inf_SuccessTargetRows
		, l.Inf_Type
		, l.Inf_Status
		, p.Arc_PreSource_Acronym
		, isnull(s.Display, p.Arc_PreSource_Name) as Arc_PreSource_Name
		, p.Arc_SFTP_Extract_ID
into #informaticaLog
from informaticaconfig_dev.dbo.inf_log l with (nolock)
inner join #sources s
	on Inf_Object_Name like 'PRS[_]' + Source + '[_]' + @Environment + '[_]PRS[_]%'
inner join informaticaconfig_dev.dbo.Arc_Presource p
	on p.Arc_Presource_Acronym = s.Source
where inf_startTime between isnull(@StartTime, dateadd(day, -1, @EndTime)) and @EndTime --If no starttime provided, look back 1 day.

-- Cleaning up data into more usable format

select tf.Inf_Object_Name as TaskFlowName
		, tf.Arc_Presource_Acronym as Acronym
		, tf.Arc_Presource_Name as SourceName
		, v.Position as PositionInTaskFlow
		, d.Inf_Object_Name as TaskName
		, d.Inf_Status as TaskStatus
		, tf.Inf_StartTime as StartTime
		, tf.Inf_EndTime as EndTime
		, case when charindex('_', reverse(d.Inf_Object_Name), charindex('_', reverse(d.Inf_Object_Name))+ 1) > 0 
			then  right(d.Inf_Object_Name, charindex('_', reverse(d.Inf_Object_Name), charindex('_', reverse(d.Inf_Object_Name))+ 1)-1)
			else null end as Stage
		, case when d.Inf_Object_Name like '%[_]PRS[_]Load[_]%' then SUBSTRING(d.Inf_Object_Name, CHARINDEX('_Load_',d.Inf_Object_Name) + LEN('_Load_'), len(d.Inf_Object_Name)) else null end as FileNameShort
		, p.Arc_SFTP_Extract_ID as SFTPId
		, d.Inf_SuccessTargetRows as Row_Count
		, d.Inf_ErrorMessage as ErrorMessage
		--, FileSize 
into #informaticaLogClean 	
from #informaticaLog tf
inner join #informaticaLog d with (nolock)
	on d.Inf_StartTime between tf.Inf_StartTime and tf.Inf_EndTime
	and d.Inf_Type = 'MTT'
inner join informaticaconfig_dev..v_TaskFlow_Tasks v --Only tasks run during that time and in that task flow
	on v.TaskFlowName = tf.Inf_Object_Name
	and v.TaskName = d.Inf_Object_Name
inner join InformaticaConfig_DEV.dbo.Arc_Presource p
	--on tf.Inf_Object_Name = 'PRS_' + p.Arc_Presource_Acronym + '_' + @Environment + '_PRS_Load_Prestaging'
	on d.Inf_Object_Name like 'PRS[_]' + p.Arc_Presource_Acronym  + '[_]' + @Environment + '[_]PRS[_]%'
where tf.Inf_Type = 'WORKFLOW'


--File Log details
select distinct TaskFlowName as TaskFlowName
		, tf.Acronym as Acronym
		, tf.SourceName as SourceName
		, StartTime as StartTime
		, f.Stage
		, Sftp_Id as SFTPId
		, [RowCount] as Row_Count
		, f.ErrorMessage
		, FileSize 
		, f.FileNameShort as FileNameShort 
into #fileLogClean
from #informaticaLogClean tf
left join #fileLog f
	on f.Timestamp between tf.StartTime and tf.EndTime
	and f.sftp_id = tf.SFTPId 


update #fileLogClean
set FileNameShort = case when FileNameShort like @FlatFileDateStampConvention
					then right(FileNameShort, len(FileNameShort) - 24)
					else FileNameShort end




create table #PrestagingLog(
	ID int not null
	, RuleName varchar(100)
	, RowIdentifier varchar(255)
	, Arc_Orig_FileName varchar(255)
	, Result varchar(100)
	, RowCheckTimestamp datetime
	, DatabaseName varchar(100)
)


--Because dealing with linked servers is no fun, and tends to cause errors with nested if statements...

declare @PrestagingLogSql varchar(max) = ''

--Make sure the DB Exists (in some cases, e.g. LAORIED, it won't)
select @PrestagingLogSql +=
'
if exists(select top 1 1 from ' + quotename(ServerName) + '.master.sys.databases where name = ''' + DbName + ''')
begin
	update #sources set CanQueryDB = 1 where Source = ''' + Source + '''
	
end
' 
from #sources

--select(@PrestagingLogSql)
exec(@PrestagingLogSql)

select @PrestagingLogSQL = ''

--Make sure row-level logging is in place on the DB if we have access. 
select @PrestagingLogSql +=
'
if exists(select top 1 1 from ' + quotename(ServerName) + '.' + quotename(DbName) + '.sys.tables where name = ''RuleViolations'')
begin
	update #sources set CanQueryTable = 1 where Source = ''' + Source + '''
end
' 
from #sources
where CanQueryDB = 1

--select(@PrestagingLogSql)
exec(@PrestagingLogSql)


select @PrestagingLogSQL = ''
select @PrestagingLogSql += 
'
insert #PrestagingLog(ID,RuleName,RowIdentifier,Arc_Orig_FileName,Result,RowCheckTimestamp,DatabaseName)
select ID, RuleName, RowIdentifier, Arc_Orig_FileName, Result, RowCheckTimestamp, DatabaseName
from ' + quotename(ServerName) + '.' + quotename(DbName) + '.dbo.RuleViolations
' 
from #sources
where CanQueryDB = 1
and CanQueryTable = 1


--select(@PrestagingLogSql)
exec(@PrestagingLogSql)



declare @stepNum int = 1; 

create table #results(
	FileProcessingStartTime datetime
	, Source varchar(100)
	, StepNumber int
	, Category varchar(100)
	, [FileName] varchar(100)
	, [RowIdentifier] varchar(100)
	, Test varchar(200)
	, Result varchar(100)
	, Status varchar(50)
	, ErrorMessage varchar(1000)
)


--Tests begin here:

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result)
select StartTime as FileProcessingStartTime
		, SourceName as Source
		, @stepNum as StepNumber
		, @Cat_EncryptedFilesReceived as Category
		, NULL as [FileName]
		, NULL as [RowIdentifier]
		, @Test_NumberOfFiles as Test
		, count(distinct FileNameShort) as Result
from #fileLogClean
where stage = @Stage_SFTP or stage is null
group by SourceName, StartTime
 
set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result)
select distinct 
		StartTime as FileProcessingStartTime
		, SourceName as Source
		, @stepNum as StepNumber
		, @Cat_EncryptedFilesReceived as Category
		, FileNameShort as [FileName]
		, NULL as [RowIdentifier]
		, @Test_FileSize as Test
		, FileSize as Result
from #fileLogClean
where stage = @Stage_SFTP 

set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result, ErrorMessage)
select distinct 
	StartTime as FileProcessingStartTime
	, SourceName as Source
	, @stepNum as StepNumber
	, @Cat_Decrypt as Category
	, NULL as [FileName]
	, NULL as [RowIdentifier]
	, @Test_StatusOfStep as Test
	, TaskStatus as Result
	, case when TaskStatus <> @InformaticaSuccess then ErrorMessage else null end as ErrorMessage
from #informaticaLogClean
where stage = @Stage_Decrypt

set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result, ErrorMessage)
select distinct
	 StartTime as FileProcessingStartTime
	, SourceName as Source
	, @stepNum as StepNumber
	, @Cat_Decrypt as Category
	, NULL as [FileName]
	, NULL as [RowIdentifier]
	, @Test_NumberOfFiles as Test
	, Row_Count as Result
	, case when TaskStatus <> @InformaticaSuccess then ErrorMessage else null end as ErrorMessage
from #informaticaLogClean
where stage = @Stage_Decrypt


set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result)
select StartTime as FileProcessingStartTime
		, SourceName as Source
		, @stepNum as StepNumber
		, @Cat_FilePP as Category
		, NULL as [FileName]
		, NULL as [RowIdentifier]
		, @Test_NumberOfFiles as Test
		, count(distinct FileNameShort) as Result
from #fileLogClean
where stage = @Stage_FilePP or stage is null
group by SourceName, StartTime

set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result)
select distinct 
		StartTime as FileProcessingStartTime
		, SourceName as Source
		, @stepNum as StepNumber
		, @Cat_FilePP as Category
		, FileNameShort as [FileName]
		, NULL as [RowIdentifier]
		, @Test_FileSize as Test
		, FileSize as Result
from #fileLogClean
where stage = @Stage_FilePP 

set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result, ErrorMessage)
select distinct 
		StartTime as FileProcessingStartTime
		, SourceName as Source
		, @stepNum as StepNumber
		, @Cat_FilePP as Category
		, FileNameShort as [FileName]
		, NULL as [RowIdentifier]
		, @Test_RowCount as Test
		, Row_Count as Result
		, ErrorMessage as ErrorMessage
from #fileLogClean
where stage = @Stage_FilePP 

set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result, ErrorMessage)
select distinct 
		StartTime as FileProcessingStartTime
		, SourceName as Source
		, @stepNum as StepNumber
		, @Cat_FilePP as Category
		, NULL as [FileName]
		, NULL as [RowIdentifier]
		, @Test_StatusOfStep as Test
		, TaskStatus as Result
		, case when TaskStatus <> @InformaticaSuccess then ErrorMessage else null end as ErrorMessage
from #informaticaLogClean
where stage = @Stage_FilePPTask


set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result, ErrorMessage)
select distinct StartTime as FileProcessingStartTime
		, SourceName as Source
		, @stepNum as StepNumber
		, @Cat_InformaticaLoad as Category
		, FileNameShort as [FileName]
		, NULL as [RowIdentifier]
		, @Test_RowCount as Test
		, Row_Count as Result
		, case when TaskStatus <> @InformaticaSuccess then ErrorMessage else null end as ErrorMessage
from #informaticaLogClean
where FileNameShort is not null

set @stepNum += 1;

insert #results(FileProcessingStartTime, Source, StepNumber, Category, [FileName], [RowIdentifier], Test, Result, Status)
select distinct StartTime as FileProcessingStartTime
		, tf.SourceName as Source
		, case when RuleName = 'Prestaging Row Count'
				then @stepNum else @stepNum + 1 end as StepNumber
		, 'Prestaging' as Category
		, case when Arc_Orig_FileName like @FlatFileDateStampConvention
					then right(Arc_Orig_FileName, len(Arc_Orig_FileName) - 24)
					else Arc_Orig_FileName end as [FileName] 
		, RowIdentifier as RowIdentifier
		, case when RuleName = 'Prestaging Row Count'
				then @Test_RowCount else RuleName end as Test
		, Result as Result
		, case when RuleName <> 'Prestaging Row Count' then 'WARNING' end as Status
from #InformaticaLogClean tf
join #PrestagingLog p
	on p.RowCheckTimestamp between tf.StartTime and tf.EndTime
	and p.DatabaseName = REPLACE(tf.Acronym, 'PR-', '') + '_PRESTAGING_' + @Environment



--Set status for Informatica tasks. 
update r 
	set r.Status = case when Result = @InformaticaSuccess then @Status_OK else @Status_WARNING end 
from #results r
where Test = @Test_StatusOfStep



--Check file counts through different stages (SFTP -> Decrypt -> PreProcess)
update currentStep
set 
		currentStep.Status = 
			case when currentStep.Category = @Cat_EncryptedFilesReceived
				then case when try_convert(int, currentStep.Result) > 0 then @Status_OK else @Status_WARNING end
			when isnull(currentStep.Result, 0) = isnull(previousStep.Result, 0) then @Status_OK else @Status_WARNING end
		 , currentStep.ErrorMessage = 
			case when currentStep.Category = @Cat_EncryptedFilesReceived
				then case when try_convert(int, currentStep.Result) = 0 then 'No files received' end
			when isnull(currentStep.Result, 0) <> isnull(previousStep.Result, 0) then 
				'Number of Files (' + currentStep.Category + 
				' - ' + currentStep.Result + 
				') differs from previous result (' + 
				previousStep.Category + ' - ' + previousStep.Result + 
				')' end

from #results currentStep
left join #results previousStep
	on currentStep.Source = previousStep.Source
	and currentStep.FileProcessingStartTime = previousStep.FileProcessingStartTime
	and currentStep.Test = previousStep.Test
	and (
			(currentStep.Category = @Cat_Decrypt and previousStep.Category = @Cat_EncryptedFilesReceived)
			or (currentStep.Category = @Cat_FilePP and previousStep.Category = @Cat_Decrypt)
		)
where currentStep.Test = @Test_NumberOfFiles


--Sum of file row counts minus 1 per file (header) should equal number loaded into prestaging. 
update i 
set i.Status = case when isnull(i.Result, 0) <> isnull(f.adjustedRowCount, 0) 
				then @Status_WARNING
				else @Status_OK end
	, i.ErrorMessage =
			case when isnull(i.Result, 0) <> isnull(f.adjustedRowCount, 0) 
			then 'Informatica Load Row Count (' + i.Result + 
					') different from total file row count (' + cast(f.adjustedRowCount as varchar) + 
					')' 
			else null end
from #results i
left join (
	select FileProcessingStartTime
			, Source
			, sum(cast(result as int)) - count(1) as adjustedRowCount
	from #results 
	where Test = @Test_RowCount 
	and Category = @Cat_FilePP
	group by FileProcessingStartTime, Source
	) f
	on f.Source = i.Source
	and f.FileProcessingStartTime = i.FileProcessingStartTime
where i.Test = @Test_RowCount
and i.Category = @Cat_InformaticaLoad


---Informatica load vs prestaging. 
update p
set
	p.Status = case when isnull(FullRowCount , 0) = isnull(i.Result, 0) 
		then @Status_OK else @Status_Warning end
	, p.ErrorMessage =
			case when isnull(FullRowCount , 0) <> isnull(i.Result, 0) 
			then 'Prestaging Row Count (' + cast(isnull(FullRowCount , 0) as varchar) + 
					') different from Informatica row count (' + cast(isnull(i.Result, 0) as varchar) + 
					')' 
			else null end
from (
	select *, sum(try_convert(int, Result)) over (partition by Source, FileProcessingStartTime) as FullRowCount
	from #results 
	where Test = @Test_RowCount
	and Category = @Cat_Prestaging
	) p
left join #results i
	on i.Test = p.Test
	and i.Source = p.Source
	and i.FileProcessingStartTime = p.FileProcessingStartTime
	and i.Category = @Cat_InformaticaLoad



--0 KB and 0 RowCounts
update r
	set r.Status = @Status_WARNING 
		, r.ErrorMessage = 'Value of ' + Result + ' for ' + Test
from #results r
where test in (@Test_FileSize, @Test_RowCount)
and Result = '0'

--Clean up anything left. 
update r
	set r.Status = @Status_OK
from #results r
where status is null


if object_id('InformaticaConfig_Dev.dbo.LHCQF_ErrorReporting') is not null
begin 
	
	delete f 
	from InformaticaConfig_Dev.dbo.LHCQF_ErrorReporting f
	join #results r
		on r.FileProcessingStartTime = f.FileProcessingStartTime
		and r.Source = f. Source

	insert into InformaticaConfig_Dev.dbo.LHCQF_ErrorReporting(
		FileProcessingStartTime 
		, Source 
		, StepNumber 
		, Category 
		, [FileName]
		, RowIdentifier 
		, Test 
		, Result 
		, Status 
		, ErrorMessage 
		, PrestagingEnvironment 
		, MonitoringTimestamp
		)
	select FileProcessingStartTime 
		, Source 
		, StepNumber 
		, Category 
		, [FileName]
		, RowIdentifier 
		, Test 
		, Result 
		, Status 
		, ErrorMessage  
		, upper(@Environment)
		, getdate()
	from #results

end