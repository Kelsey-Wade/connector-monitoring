/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

/*
	NOTE: must be in SQLCMD mode prior to execution

*/

:r .\Scripts\PopulateProcedureTypes.sql
:r .\Scripts\PopulateScheduleType.sql
:r .\Scripts\ConfigureMonitoringProcedures.sql
:r .\Scripts\BuildCalendar.sql