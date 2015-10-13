CREATE PROCEDURE [dbo].[uspCheckDeployedConnectors]

	 @Email_To varchar(1000) 
	, @Email_CC varchar(1000) = null
	, @Email_Content_Type varchar(100) = null
	, @IsExternalEmail bit = 0 
	, @IsInternalEmail bit = 1
AS

set @Email_Content_Type = isnull(@Email_Content_Type, 'HTML')

if object_id('tempdb..#BadDeploys') is not null drop table #BadDeploys
create table #BadDeploys (
	TaskFlow varchar(255)
	, Query varchar(255)
	, Actual_Template_ID varchar(255)
	, Actual_Template_Name varchar(255)
	, Deploy_Template_ID varchar(255)
	, Deploy_Template_Name varchar(255)
	, Parameter varchar(255)
	, Actual_Value varchar(max)
	, Deploy_Value varchar(max) 
)
insert #BadDeploys
exec informaticaconfig_dev.dbo.uspValidateDeploys
insert #BadDeploys
exec informaticaconfig_qa.dbo.uspValidateDeploys
insert #BadDeploys
exec informaticaconfig_uat.dbo.uspValidateDeploys
insert #BadDeploys
exec informaticaconfig_prd.dbo.uspValidateDeploys

declare @header varchar(1000) = '
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
			<th>TaskFlow</th>
			<th>Query</th>
			<th>Actual Template_ID</th>
			<th>Actual Template_Name</th>
			<th>Deploy Template_ID</th>
			<th>Deploy Template_Name</th>
			<th>Parameter</th>
			<th>Actual Value</th>
			<th>Deploy Value</th> 
		</thead>
		<tbody>'

declare @row varchar(1000)= '
			<tr>
				<td style="white-space:nowrap;">{TaskFlow}</td>
				<td>{Query}</td>
				<td>{Actual_Template_ID}</td>
				<td>{Actual_Template_Name}</td>
				<td>{Deploy_Template_ID}</td>
				<td>{Deploy_Template_Name}</td>
				<td>{Parameter}</td>
				<td>{Actual_Value}</td>
				<td>{Deploy_Value}</td>
			</tr>	
'
declare @tableEnd varchar(100) = '
		</tbody>
	</table>
</body>'
declare @allRows varchar(max) = '' 
select @allRows += 
	replace(replace(replace(replace(replace(replace(replace(replace(replace(@row,
			'{TaskFlow}',isnull(TaskFlow, '')),
			'{Query}',isnull(Query, '')),
			'{Actual_Template_ID}',isnull(Actual_Template_ID, '')),
			'{Actual_Template_Name}',isnull(Actual_Template_Name, '')),
			'{Deploy_Template_ID}',isnull(Deploy_Template_ID, '')),
			'{Deploy_Template_Name}',isnull(Deploy_Template_Name, '')),
			'{Parameter}',isnull(Parameter, '')),
			'{Actual_Value}',isnull(Actual_Value, '')),
			'{Deploy_Value}',isnull(Deploy_Value, ''))
from 
(select distinct *from #BadDeploys)x

declare @finalTable varchar(max) = @header + @allrows + @tableEnd

declare @count int = (select count(1) from (select distinct * from #BadDeploys)x)

if @count>0 and dbo.udfAreEmailsArcadia(@Email_To) = @IsInternalEmail 
begin
	declare @Subject varchar(255) = 'Connector Deployment Discrepancy Report - ' + cast(@count as varchar) +' Errors found.'
	print @Subject 
	select @finalTable
	EXEC msdb.dbo.sp_send_dbmail  
		@body = @finalTable,
		@recipients = @Email_To,
		@subject= @Subject,
		@body_format = @Email_Content_Type,
		@importance='Normal',
		@sensitivity='Normal'
end