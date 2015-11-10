CREATE PROCEDURE [dbo].[uspFilesReceivedNotification]
	@Group varchar(100) = null
	, @Source varchar(100) 
	, @Environment varchar(100)
	, @StartTime datetime
	, @EndTime datetime
	, @Email_From varchar(100) = null
	, @Email_To varchar(100) = null
	, @Email_CC varchar(100) = null
	, @Email_Content_Type varchar(100) = 'HTML'
	, @IsExternalEmail bit
	, @DoNotSend bit = 1
AS
	
--HTML Email variables. 
declare @start varchar(max)
		, @tableStart varchar(max)
		, @tableHeader varchar(max)
		, @tableRow varchar(max)
		, @tableEnd varchar(100)
		, @tables varchar(max) = ''
		, @finalMessageText varchar(max)
		, @end varchar(100) 
		, @runs int
		, @errors varchar(max) = ''
		, @overallStatus varchar(max) = ''
		, @sourceStatus varchar(max) = ''


select @Email_From = isnull(@Email_From, 'Arcadia Monitoring <noreply@arcadiasolutions.com>')
--Basic HTML structures for the email.

--Formatting.
declare 
	@ok varchar(1000) = '<span style="color:#92D050;font-weight:bold;">OK</span>',
	@alert varchar(1000) = '<span style="color:#FF3300;font-weight:bold;">ALERT</span>',
	@h2 varchar(1000) = 'margin-top:10.0pt;
	margin-right:0in;
	margin-bottom:0in;
	margin-left:0in;
	margin-bottom:.0001pt;
	line-height:107%;
	font-size:13.0pt;
	font-family:Calibri Light,Calibri,sans-serif;
	color:#404040;
	font-weight:normal;', 
	@h3 varchar(1000) = '"margin-top:5.0pt;
	margin-right:0in;
	margin-bottom:0in;
	margin-left:0in;
	margin-bottom:.0001pt;
	line-height:107%;
	font-size:11.0pt;
	font-family:Calibri Light,Calibri,sans-serif;
	color:#404040;
	font-weight:bold;"'
	, @tableStyle varchar(1000) ='"font-family:Calibri Light,Calibri,sans-serif;font-size:80%;border-collapse:collapse;margin-top:4.0pt;width:90%;"'
 
set @start  = 
'<!DOCTYPE html>
<html>
<body style="font-family:Calibri,sans-serif;color:#404040;">'

set @overallStatus = '
	<h2 style="'+@h2+'border-bottom:1px solid #A5A5A5;">OVERALL JOB STATUS: {j}</h2>
	{error}'

set @sourceStatus = '
	<br>
	<h2 style="'+@h2+'">SOURCE: <span style="font-weight:bold">{u}</span></h2>
	<h3 style='+@h3+'>STATUS</h3>
	<div style="width: 100%; max-width: 800px;">
		<table style='+@tableStyle+'>
		<tbody>
			<tr>
				<td style="padding-left:8px;width:100px;border-bottom:1px solid #A5A5A5;">Start Time</td>
				<td style="border-bottom:1px solid #A5A5A5;"><strong>{d}</strong></td>
				<td style="border-bottom:1px solid #A5A5A5;"></td>
			</tr>
			<tr>
				<td style="padding-left:8px;width:100px;border-bottom:1px solid #A5A5A5;">Decrypted</td>
				<td style="border-bottom:1px solid #A5A5A5;"><strong>{decrypted}</strong> Files</td>
				<td style="text-align:right;padding-right:10px;border-bottom:1px solid #A5A5A5;"">{decryptStatus}</td>
			</tr>
			<tr>
				<td style="padding-left:8px;width:100px;border-bottom:1px solid #A5A5A5;">Processed</td>
				<td style="border-bottom:1px solid #A5A5A5;"><strong>{n}</strong> Files</td>
				<td style="text-align:right;padding-right:10px;border-bottom:1px solid #A5A5A5;">{receivedStatus}</td>
			</tr>
		</tbody>
		</table>
	</div>'


set @tableStart = '
	<h3 style='+@h3+'>FILES</h3>
	<div style="width: 100%; max-width: 800px;">
		<table style='+@tableStyle+'> 
'

set @tableRow = '
			<tr>
				<td style="padding-left:8px;border-bottom:1px solid #A5A5A5;font-style: italic;">{f}</td>
				<td style="border-bottom:1px solid #A5A5A5;"><strong>{rc}</strong> Rows</td>
				<td style="border-bottom:1px solid #A5A5A5;">{ts}</td>
				<td style="text-align:right;padding-right:10px;border-bottom:1px solid #A5A5A5;">{status}</td>
			</tr>'

set @tableEnd = '
		</table>
	</div>
<br>'

set @end = '
</body>
</html>'


--Actual data collection starts here. 
if object_id('tempdb..#fileLog') is not null drop table #fileLog
if object_id('tempdb..#informaticaLog') is not null drop table #informaticaLog
if object_id('tempdb..#finalLog') is not null drop table #finalLog


select distinct
	upper(@Environment) as Environment
	, right(FileName, charindex('\', reverse(fileName))-1) as FileNameShort
	, 'PRS_' + p.Arc_Presource_Acronym + '_' + @Environment + '_PRS_Decrypt_ALL' as taskName
	, f.*
into #fileLog
from InformaticaConfig_DEV.maint.FileIntakeLog f
join InformaticaConfig_DEV.dbo.arc_presource p
	on p.arc_sftp_extract_id = f.sftp_id
join InformaticaConfig_DEV.dbo.v_TaskFlow_Tasks t
	on t.TaskName = 'PRS_' + p.Arc_Presource_Acronym + '_' + @Environment + '_PRS_Decrypt_ALL'
	and t.TaskFlowName = 'PRS_'+ ISNULL(@Group, @Source) + '_' + @Environment + '_PRS_Load_Prestaging'
where p.Arc_PreSource_Acronym like @Source
and f.FileName like '%\'+@Environment+'\%' 


select *
into #informaticaLog
from informaticaconfig_dev.dbo.inf_log with (nolock)
where inf_startTime between isnull(@StartTime, dateadd(day, -1, @EndTime)) and @EndTime --If no starttime provided, look back 1 day.
and (inf_object_name = 'PRS_'+ ISNULL(@Group, @Source) + '_' + @Environment + '_PRS_Load_Prestaging'
or Inf_Object_Name like	'PRS_'+ @Source + '_' + @Environment + '_PRS_Decrypt_ALL')

select tf.Inf_Object_Name
	, d.Inf_Object_Name as d_Name
	, tf.Inf_StartTime as tf_start
	, tf.Inf_Status as tf_status
	, tf.Inf_ErrorMessage as tf_Error
	, d.Inf_StartTime as d_start
	, d.Inf_Status as d_status
	, d.Inf_ErrorMessage as d_Error
	, d.Inf_SuccessSourceRows as d_rowsSource
	, d.Inf_SuccessTargetRows as d_rowsTarget
	, p.Arc_SFTP_Extract_ID as SFTPId
	, p.Arc_Presource_Acronym as Acronym
	, f.*
	, row_number() over (partition by tf.Inf_StartTime, d.Inf_Object_Name order by FileNameShort) as fileNum
	, row_number() over (partition by tf.Inf_StartTime, d.Inf_Object_Name order by FileNameShort desc) as fileNumReverse
	, row_number() over (partition by tf.Inf_StartTime order by FileNameShort) as rowPerTF
into #finalLog
from #informaticaLog tf
inner join #informaticaLog d
	on d.Inf_StartTime between tf.Inf_StartTime and tf.Inf_EndTime
	and d.Inf_Type = 'MTT'
inner join informaticaconfig_dev..v_TaskFlow_Tasks v
	on v.TaskFlowName = tf.Inf_Object_Name
	and v.TaskName = d.Inf_Object_Name
inner join InformaticaConfig_DEV.dbo.Arc_Presource p
	on d.Inf_Object_Name = 'PRS_' + p.Arc_Presource_Acronym + '_' + @Environment + '_PRS_Decrypt_ALL'
left join #fileLog f
	on f.Timestamp between tf.Inf_StartTime and tf.Inf_EndTime
	and f.TaskName = v.taskName
where tf.Inf_Type = 'WORKFLOW'



if @@RowCount > 0 --Do not bother if we haven't tried to load anything. 
begin
	update #finalLog 
	set FileNameShort = case when FileNameShort like '#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]#[_]#[0-9][0-9][0-9][0-9]#[_]%' 
						then right(FileNameShort, len(FileNameShort) - 24)
						else FileNameShort end
	
	alter table #finalLog add finalText varchar(max)

	--Calculate number of runs and total number of files
	select @runs = count(distinct tf_start)
	from #finalLog

	--Format body based on numbers. TODO - SHOULD WE CHANGE FORMATTING IF MULTIPLE RUNS?
	select @start = replace(@start, '{runs}', case when @runs > 1 then 'This has occurred '+cast(@runs as varchar) +' times since the last email we sent.' else '' end)

	--Build the tables from the results
	update f 
	set f.finalText = 
	case when rowPerTF = 1 --First per task flow: Overall status. 
	then 
		case when tf_Succeeded = 1 
		then replace(replace(@overallStatus,'{j}', @ok), '{error}', '')
		else replace(replace(@overallStatus, '{j}', @alert), '{error}', '<p style="text-indent:25px;">[ERROR] ' + summary.tf_Error + '</p>') end
	else '' end +
	case when fileNum = 1 --First per data source in a task flow. Source status.
	then 
		replace(replace(replace(replace(replace(replace(
			@sourceStatus
				,'{n}', fileCount)
				,'{d}', convert(varchar, cast(f.tf_start as datetime)))
				,'{u}', sftpName)	
				,'{decrypted}', d_rowsTarget)
				,'{decryptStatus}', case when d_Succeeded = 1  and d_rowsTarget > 0 then @ok else @alert end)--'failed with the following error: <blockquote>' + summary.d_Error + '</blockquote>' end)
				,'{receivedStatus}', case when process_Succeeded = 1 and fileCount > 0 then @ok else @alert end)
		+ 
	case when FileNameShort is not null then @tableStart else '' end
	else '' end + 
	case when FileNameShort is not null then --Add files processed to a table. 
		replace(replace(replace(replace(
			@tableRow
				,'{f}', FileNameShort)
				,'{rc}', [RowCount])
				,'{ts}', convert(varchar, [TimeStamp]))
				,'{status}', case when nullif(ErrorMessage, '') is null and [RowCount] > 0 then @ok else @alert end)
	else '' end +
	case when fileNum = fileCount
		then @tableEnd else '' end
	from #finalLog f
	left join (
		select
			tf_Start
			, Acronym 
			, right('0000'+cast(max(SftpId) as varchar),4) + '-' + upper(Acronym) + '_SFTP_'+upper(@Environment) as sftpName
			, sum(case when FileNameShort is not null then 1 else 0 end) as fileCount
			, max(case when d_status = 'success' then 1 else 0 end) as d_Succeeded
			, max(case when tf_status = 'success' then 1 else 0 end) as tf_Succeeded
			, max(case when d_status != 'success' then d_Error else '' end) as d_Error
			, max(case when tf_status != 'success' then tf_Error else '' end) as tf_Error
			, min(case when nullif(ErrorMessage, '') is null then 1 else 0 end) as process_Succeeded
		from #finalLog
		group by tf_Start, Acronym, SftpId) summary 
		on summary.tf_start = f.tf_Start 
		and summary.Acronym = f.Acronym
	
	select @tables += finalText from #finalLog order by tf_start, Acronym, fileNum


	--Capture all the errors. 
		select @errors = '
	<h2 style='+@h2+'>ERRORS:</h2>
	<ul>'
		select @errors+= '
		<li><strong>[ERROR] ['+ right('0000'+cast(SftpId as varchar),4) + '-' + upper(Acronym) + '_SFTP_'+upper(@Environment) + '] ['+convert(varchar, cast(tf_start as datetime))+'] Unable to decrypt files</strong>: '+d_Error+'</li>'

		from #finalLog where d_status != 'success'

		select @errors += '
		<li><strong>[ERROR] ['+ right('0000'+cast(SftpId as varchar),4) + '-' + upper(Acronym) + '_SFTP_'+upper(@Environment) + '] ['+convert(varchar, cast(tf_start as datetime))+'] File formatting error for '+FileNameShort+'</strong>: '+ErrorMessage+'</li>'
		from #finalLog where nullif(ErrorMessage, '') is not null

		select @errors += '
	</ul>'

		if @errors like '%<li><strong>%</strong>%</li>%'--Only show errors if found. 
			select @finalMessageText = @start + @tables + @errors + @end
		else 
			select @finalMessageText = @start + @tables + @end

	if @DoNotSend = 0

		EXEC msdb.dbo.sp_send_dbmail  
			@body = @finalMessageText,
			@recipients = @Email_To,
			@copy_recipients = @Email_CC,
			@subject='Arcadia Solutions Files Received Notification',
			@from_address = @Email_From,
			@body_format='HTML',
			@importance='Normal',
			@sensitivity='Normal'

	else
		select @finalMessageText

end

