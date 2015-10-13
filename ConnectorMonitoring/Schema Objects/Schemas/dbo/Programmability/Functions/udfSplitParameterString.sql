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
		declare @xml xml = cast(('<X>'+replace(@input,',','</X><X>')+'</X>') as xml)

		insert @returntable (parameter, value)
		select left(pair, charindex('=', pair) - 1) as parameter
				, right(pair, len(pair)-charindex('=', pair)) as value
		from(
			SELECT N.value('.', 'varchar(1000)') as pair 
			FROM @xml.nodes('X') as T(N)
		)x

	end
	return
END
