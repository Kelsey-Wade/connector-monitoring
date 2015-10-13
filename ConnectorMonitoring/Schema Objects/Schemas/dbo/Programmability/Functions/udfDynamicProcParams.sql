CREATE FUNCTION [dbo].[udfDynamicProcParams]
(
	@parameter varchar(255)
	, @value varchar(255)
	, @isFirstParameter bit = 0
)
RETURNS varchar(500)
AS
BEGIN
	select @parameter = replace(@parameter, '@', '')
	RETURN case when @isFirstParameter = 0 then '
	,' else '
	' end +' @' + @parameter + ' = '+isnull(''''+@value+'''', 'NULL')
END
