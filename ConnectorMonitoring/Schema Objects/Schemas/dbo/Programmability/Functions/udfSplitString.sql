CREATE FUNCTION [dbo].[udfSplitString]
(
	@input varchar(max)
)
RETURNS @returntable TABLE
(
	val varchar(max)
)
AS
BEGIN
	declare @xml xml = cast(('<X>'+replace(@input,',','</X><X>')+'</X>') as xml)

	insert @returntable (val)
	select val
	from(
		SELECT N.value('.', 'varchar(1000)') as val 
		FROM @xml.nodes('X') as T(N)
	)x
	return
END
