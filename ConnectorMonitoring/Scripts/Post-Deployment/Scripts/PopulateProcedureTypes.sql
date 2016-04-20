
DECLARE @procedureTypes TABLE(
	Task_Type varchar(255)
	, Proc_Name varchar(255)
)

INSERT @procedureTypes (Task_Type, Proc_Name)
VALUES
('SendFileReceivedNotification','uspFilesReceivedNotification'),
('Check Connector Deploys','uspCheckDeployedConnectors'),
('Check for Failed SFTPs','uspNotifyFailedSFTPTasks'),
('Update master seed list','uspUpdateAllMasterSeeds'), 
('LHCQF Error Reporting to CSV', 'uspLHCQFErrorReporting')

UPDATE p
SET p.Proc_Name =  t.Proc_Name
FROM dbo.ProcedureType p
INNER JOIN @procedureTypes t
	on t.Task_Type = p.Task_Type


INSERT dbo.ProcedureType (Task_Type, Proc_Name)
SELECT Task_Type, Proc_Name
FROM @procedureTypes p
WHERE NOT EXISTS (SELECT 1 FROM dbo.ProcedureType t WHERE t.Task_Type = p.Task_Type)