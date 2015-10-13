truncate table Calendar
declare @StartDate date = '01/01/2015'
		, @MaxDate date = '12/31/2025'

;

with dates as
(
	select refDate = @StartDate 
			, DATEPART(weekday, @StartDate) as day_int
			, DATENAME(weekday, @StartDate) as day_string
		
	union all 

	select refDate = dateadd(day, 1, refDate)
			, DATEPART(weekday, dateadd(day, 1, refDate)) as day_int
			, DateName(weekday, dateadd(day, 1, refDate)) as day_string	
	from dates
	where refDate < @MaxDate 
)

INSERT Calendar(RefDate, DayOfWeek_Int, DayOfWeek_String)
select refDate, day_int, day_string
from dates 
option (maxrecursion 0)