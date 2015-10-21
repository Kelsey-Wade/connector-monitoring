CREATE FUNCTION [dbo].[udfSplitParameterString]
(
	@input varchar(max)
)
RETURNS @returntable TABLE
(
	parameter varchar(255)
	, value varchar(1000)
)
AS
BEGIN

	if @input like '%=%'
	begin 

		insert @returntable (parameter, value)
		select left(val, charindex('=', val) - 1) as parameter
				, right(val, len(val)-charindex('=', val)) as value
		from [dbo].[udfSplitString] (@input)
		where val like '%=%'

	end
	return
END
