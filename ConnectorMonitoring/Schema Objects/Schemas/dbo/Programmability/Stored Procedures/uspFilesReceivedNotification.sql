CREATE PROCEDURE [dbo].[uspFilesReceivedNotification]
	@Group varchar(100) = null
	, @Source varchar(100) 
	, @Environment varchar(100)
	, @StartTime datetime
	, @EndTime datetime
	, @Email_From varchar(100) = 'jeff.solomon@arcadiasolutions.com'
	, @Email_To varchar(100) = 'jeff.solomon@arcadiasolutions.com'
	, @Email_CC varchar(100) = 'jeff.solomon@arcadiasolutions.com'
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
		, @sftpUN varchar(100) = ''
		, @jobStatus varchar(100) = 'status unknown'

--Basic HTML structures for the email. 
set @body  = 
'<!DOCTYPE html>
<html>
<body style="font-family:Calibri,sans-serif;">
	<p>Hello,<br><br>This message is to inform you that Arcadia Healthcare Solutions has attempted to load files from your organization. {runs} <br><br>If you have any questions, please contact...<br><br>The files received and row counts are listed below.</p>'


set @tableHeader = '
<p style="text-align:left;padding:4px"> <strong>{n}</strong> files recieved from <strong>{u}</strong> on <strong>{d}</strong>. Processing {j}.</p>'

set @tableStart = '
	<table style="border-collapse:collapse;border:1px solid #7E7E7E;"> 
		<thead style="font-weight:bold;border-bottom:1px solid #7E7E7E;">
			<th style="text-align:left;padding:2px;">File Name</th>
			<th style="text-align:left;padding:2px;padding-left:20px;">Rows</th>
			<th style="text-align:left;padding:2px;padding-left:20px;">Timestamp</th>
		</thead>
		<tbody style="border-bottom:1px solid #AFAFAF;">'

set @tableRow = '
		<tr>
			<td style="border-bottom: 1px solid #DBDBDB;padding-left:2px;">{f}</td>
			<td style="border-bottom: 1px solid #DBDBDB;padding-left:20px;">{rc}</td>
			<td style="border-bottom: 1px solid #DBDBDB;padding-left:20px;padding-right:10px;">{ts}</td>
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
	, f.*
into #fileLog
from InformaticaConfig_DEV.maint.FileIntakeLog f
join InformaticaConfig_DEV.dbo.arc_presource p
	on p.arc_sftp_extract_id = f.sftp_id
where p.Arc_PreSource_Acronym = @Source
and f.FileName like '%\'+@Environment+'\%' 


select *
into #informaticaLog
from informaticaconfig_dev.dbo.inf_log with (nolock)
where inf_startTime between @StartTime and @EndTime
and inf_object_name in(
	'PRS_'+ ISNULL(@Group, @Source) + '_' + @Environment + '_PRS_Load_Prestaging',
	'PRS_'+ @Source + '_' + @Environment + '_PRS_Decrypt_ALL'
	)

select tf.Inf_Object_Name
	, tf.Inf_StartTime as tf_start
	, tf.Inf_Status as tf_status
	, d.Inf_StartTime as d_start
	, d.Inf_Status as d_status
	, d.Inf_SuccessSourceRows as d_rowsSource
	, d.Inf_SuccessTargetRows as d_rowsTarget
	, f.*
	, row_number() over (partition by tf.Inf_StartTime order by FileNameShort) as fileNum
into #finalLog
from #informaticaLog tf
left join #informaticaLog d
	on d.Inf_StartTime between tf.Inf_StartTime and tf.Inf_EndTime
	and d.Inf_Type = 'MTT'
left join #fileLog f
	on f.Timestamp between tf.Inf_StartTime and tf.Inf_EndTime
where tf.Inf_Type = 'WORKFLOW'

if @@RowCount > 0 --Do not bother if we haven't tried to load anything. 
begin
	--Calculate number of runs and total number of files
	select @runs = count(distinct tf_start)
			, @sftpUN = isnull(right('0000'+cast(max(sftp_id) as varchar)+ '-',5),'')  + upper(@Source) + '_SFTP_'+upper(@Environment)
			, @jobStatus = case when d_status <> 'Success' or tf_status <> 'Success' then 'was unsuccessful' else 'succeeded' end
	from #finalLog

	--Format body based on numbers. 
	select @body = replace(@body, '{runs}', case when @runs > 1 then 'This has occurred '+cast(@runs as varchar) +' times since the last email we sent.' else '' end)

	--Build the tables from the results
	select @bodyTables +=
	case when fileNum = 1
	then 
		replace(replace(replace(replace(@tableHeader,
			 '{n}', (select isnull(max(fileNum), 0) from #finalLog l where l.tf_start = f.tf_start and l.FileNameShort is not null))
			,'{d}', convert(varchar, cast(tf_start as datetime)))
			,'{u}', @sftpUN)
			,'{j}', @jobStatus)
		+ case when FileNameShort is not null then @tableStart else '' end
	else '' end + 
	case when FileNameShort is not null then 
		replace(replace(replace(replace(
			@tableRow
				,'{f}', case when FileNameShort like '#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]#[_]#[0-9][0-9][0-9][0-9]#[_]%' 
					then right(FileNameShort, len(FileNameShort) - 24)
					else FileNameShort end)
				,'{rc}', [RowCount])
				,'{ts}', convert(varchar, [TimeStamp]))
				,'{color}', case when fileNum%2 = 1 then '#E8F3FC;' else 'white;' end)
	else '' end +
	case when fileNum = (select isnull(max(fileNum), 0) from #finalLog l where l.tf_start = f.tf_start)
		then @tableEnd else '' end
	from #finalLog f
	order by tf_start, fileNum



	select @finalMessageText = @body + @bodyTables + @end

	if @DoNotSend = 0
		EXEC msdb.dbo.sp_send_dbmail  
			@body = @finalMessageText,
			@recipients ='jeff.solomon@arcadiasolutions.com',
			@copy_recipients ='jsolomon9009@gmail.com',
			@subject='Arcadia Files Received Notification',
			@from_address = @Email_From,
			@body_format='HTML',
			@importance='Normal',
			@sensitivity='Normal'

	else
		select @finalMessageText

end
