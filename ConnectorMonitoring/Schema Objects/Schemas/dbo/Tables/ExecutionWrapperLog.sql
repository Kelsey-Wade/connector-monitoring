CREATE TABLE [dbo].[ExecutionWrapperLog]
(
	[Id] INT NOT NULL PRIMARY KEY IDENTITY(1,1)
	, StartTime datetime
	, EndTime datetime
	, ProceduresCalled int
)
