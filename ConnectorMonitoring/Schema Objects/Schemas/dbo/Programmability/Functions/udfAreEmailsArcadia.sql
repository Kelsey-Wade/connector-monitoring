CREATE FUNCTION [dbo].[udfAreEmailsArcadia]
(
	@input varchar(max)
)
RETURNS BIT
AS
BEGIN
	declare @xml xml = cast(('<X>'+replace(@input,';','</X><X>')+'</X>') as xml)

		if exists(
			select 1
			from(
				SELECT N.value('.', 'varchar(1000)') as email 
				FROM @xml.nodes('X') as T(N)
			)x
			where email like '%@%'
			and right(email, len(email) - charindex('@',email)) <> 'arcadiasolutions.com'
			)
		begin
			return 0
		end
		return 1
END
