CREATE PROCEDURE [dbo].[uspUpdateAllMasterSeeds]

AS

EXECUTE InformaticaConfig_DEV.dbo.uspUpdateMasterSeeds
EXECUTE InformaticaConfig_QA.dbo.uspUpdateMasterSeeds
EXECUTE InformaticaConfig_UAT.dbo.uspUpdateMasterSeeds
EXECUTE InformaticaConfig_PRD.dbo.uspUpdateMasterSeeds

