CREATE PROCEDURE [dbo].[uspNotifyFailedSFTPTasks]

	 @Email_To varchar(1000) 
	, @Email_CC varchar(1000) = null
	, @Email_Content_Type varchar(100) = null
	, @IsExternalEmail bit = 0 
	, @IsInternalEmail bit = 1
AS

set @Email_Content_Type = isnull(@Email_Content_Type, 'HTML')

declare @tableRow varchar(max) = '
<tr>
	<td>{1}</td>
	<td>{2}</td>
	<td>{3}</td>
	<td>{4}</td>
</tr>
'

declare @table varchar(max) = '
<head>
<style>
table {
border-collapse:collapse;
border:1px solid #7E7E7E;
}

td {
border-bottom: 1px solid #DBDBDB;
padding-left:10px;
}

</style>
</head>
<body>
	<table>
		<thead>
			<th>Task</th>
			<th>Start Time</th>
			<th>Status</th>
			<th>Error</th>
		</thead>
		<tbody>
'


select @table +=
replace(replace(replace(replace(@tableRow,
	'{1}', Inf_Object_Name),
	'{2}', convert(varchar, cast(inf_starttime as datetime))),
	'{3}', Inf_Status),
	'{4}', Inf_ErrorMessage)
from informaticaconfig_dev..inf_log (NOLOCK)
where inf_starttime >= dateadd(day, -1, getdate())
and Inf_Object_Name like '%SFTP%'
and Inf_Status <> 'Success'
and Inf_Object_Name not like '%[_]DEV[_]%'
and Inf_Object_Name not like 'EBNHC%'
order by Inf_Object_Name

declare @count int = @@rowcount 

if @count > 0 
begin
	select @table += '
	</tbody>
</table>
</body>'
	declare @Subject varchar(255) = 'Failed SFTP Task Report ('+cast(@count as varchar)+' Failures)'
	print @Subject 
	select @table
	EXEC msdb.dbo.sp_send_dbmail  
		@body = @table,
		@recipients = @Email_To,
		@subject= @Subject,
		@body_format = @Email_Content_Type,
		@importance='Normal',
		@sensitivity='Normal'
end


