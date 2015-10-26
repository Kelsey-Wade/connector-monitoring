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
declare @body varchar(max)
		, @tableStart varchar(max)
		, @tableHeader varchar(max)
		, @tableRow varchar(max)
		, @tableEnd varchar(100)
		, @bodyTables varchar(max) = ''
		, @finalMessageText varchar(max)
		, @end varchar(100) 
		, @runs int
		, @columnErrors varchar(max) = ''

select @Email_From = isnull(@Email_From, 'Arcadia Monitoring <noreply@arcadiasolutions.com>')
--Basic HTML structures for the email. 
set @body  = 
'<!DOCTYPE html>
<html>
<body style="font-family:Calibri,sans-serif;font-size: 75%;">
	<p>Hello,<br><br>This message is to inform you that Arcadia Healthcare Solutions has attempted to load files from your organization. {runs} <br><br>If you have any questions, please contact...<br><br>The files received and row counts are listed below.</p>'


set @tableHeader = '
<h5>{n} files were recieved from {u} on {d}.</h5>
<p>Decryption of these files <strong>{s}</strong> Overall file processing <strong>{j}</strong> </p>'

set @tableStart = '
	<table style="font-family:Calibri,sans-serif;font-size: 75%;border-collapse:collapse;border:1px solid #7E7E7E;"> 
		<thead style="font-weight:bold;">
			<th style="border-bottom:1px solid #7E7E7E;text-align:left;padding:2px;">File Name</th>
			<th style="border-bottom:1px solid #7E7E7E;text-align:left;padding:2px;padding-left:20px;">Rows</th>
			<th style="border-bottom:1px solid #7E7E7E;text-align:left;padding:2px;padding-left:20px;">Timestamp</th>
		</thead>
		<tbody style="border-bottom:1px solid #AFAFAF;">'

set @tableRow = '
		<tr>
			<td style="border-bottom: 1px solid {color};padding-left:2px;">{f}</td>
			<td style="border-bottom: 1px solid {color};padding-left:20px;">{rc}</td>
			<td style="border-bottom: 1px solid {color};padding-left:20px;padding-right:10px;">{ts}</td>
		</tr>'

set @tableEnd = '
	</tbody>
	</table>
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
or inf_object_name = 'PRS_'+ ISNULL(@Group, @Source) + '_' + @Environment + '_PRS_Preprocess_FlatFiles'
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
into #finalLog
from #informaticaLog tf
inner join #informaticaLog d
	on d.Inf_StartTime between tf.Inf_StartTime and tf.Inf_EndTime
	and d.Inf_Type = 'MTT'
inner join informaticaconfig_dev..v_TaskFlow_Tasks v
	on v.TaskFlowName = tf.Inf_Object_Name
	and v.TaskName = d.Inf_Object_Name
left join InformaticaConfig_DEV.dbo.Arc_Presource p
	on d.Inf_Object_Name = 'PRS_' + p.Arc_Presource_Acronym + '_' + @Environment + '_PRS_Decrypt_ALL'
left join #fileLog f
	on f.Timestamp between tf.Inf_StartTime and tf.Inf_EndTime
	and f.TaskName = v.taskName
where tf.Inf_Type = 'WORKFLOW'
and (p.Arc_Presource_Acronym is not null or 
v.taskName = 'PRS_'+ ISNULL(@Group, @Source) + '_' + @Environment + '_PRS_Preprocess_FlatFiles')


if @@RowCount > 0 --Do not bother if we haven't tried to load anything. 
begin
	update #finalLog 
	set FileNameShort = case when FileNameShort like '#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]#[_]#[0-9][0-9][0-9][0-9]#[_]%' 
						then right(FileNameShort, len(FileNameShort) - 24)
						else FileNameShort end
	
	--Calculate number of runs and total number of files
	select @runs = count(distinct tf_start)
	from #finalLog

	--Format body based on numbers. 
	select @body = replace(@body, '{runs}', case when @runs > 1 then 'This has occurred '+cast(@runs as varchar) +' times since the last email we sent.' else '' end)

	--Build the tables from the results
	select @bodyTables +=
	case when fileNum = 1
	then 
		replace(replace(replace(replace(replace(
			@tableHeader
				,'{n}', fileCount)
				,'{d}', convert(varchar, cast(f.tf_start as datetime)))
				,'{u}', sftpName)
				,'{j}', case when tf_Succeeded = 1 then 'succeeded.' else 'failed with the following error: <blockquote>' + summary.tf_Error + '</blockquote>' end)
				,'{s}', case when d_Succeeded = 1 then 'succeeded.' else 'failed with the following error: <blockquote>' + summary.d_Error + '</blockquote>' end)
		+ 
	case when FileNameShort is not null then @tableStart else '' end
	else '' end + 
	case when FileNameShort is not null then 
		replace(replace(replace(replace(
			@tableRow
				,'{f}', FileNameShort)
				,'{rc}', [RowCount])
				,'{ts}', convert(varchar, [TimeStamp]))
				,'{color}', case when fileNum = fileCount then '#7E7E7E' else '#DBDBDB' end)
	else '' end +
	case when fileNum = fileCount
		then @tableEnd else '' end
	from #finalLog f
	inner join (
		select
			tf_Start
			, Acronym 
			, right('0000'+cast(max(SftpId) as varchar),4) + '-' + upper(Acronym) + '_SFTP_'+upper(@Environment) as sftpName
			, sum(case when FileNameShort is not null then 1 else 0 end) as fileCount
			, max(case when d_status = 'success' then 1 else 0 end) as d_Succeeded
			, max(case when tf_status = 'success' then 1 else 0 end) as tf_Succeeded
			, max(case when d_status != 'success' then d_Error else '' end) as d_Error
			, max(case when tf_status != 'success' then tf_Error else '' end) as tf_Error
		from #finalLog
		group by tf_Start, Acronym, SftpId) summary 
		on summary.tf_start = f.tf_Start 
		and summary.Acronym = f.Acronym
	order by f.tf_start, f.Acronym, fileNum



		select @columnErrors = '<h5>The following files were not loaded due to formatting errors:</h5>'
		select @columnErrors+= '
<p><strong>'+FileNameShort+'</strong> (' + right('0000'+cast(SftpId as varchar),4) + '-' + upper(Acronym) + '_SFTP_'+upper(@Environment)  + ')</p>'
		+ErrorMessage
		from #finalLog where nullif(ErrorMessage, '') is not null 
		if @@rowcount > 0 
			select @finalMessageText = @body + @bodyTables + @columnErrors + @end
		else 
			select @finalMessageText = @body + @bodyTables + @end

	if @DoNotSend = 0

		EXEC msdb.dbo.sp_send_dbmail  
			@body = @finalMessageText,
			@recipients = @Email_To,
			@copy_recipients = @Email_CC,
			@subject='Arcadia Files Received Notification',
			@from_address = @Email_From,
			@body_format='HTML',
			@importance='Normal',
			@sensitivity='Normal'

	else
		select @finalMessageText

end
