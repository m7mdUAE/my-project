/* Run after scripts 01 and 02. Real coordinates only; no fabricated locations. */
USE [PlateBookingDB];
GO
IF COL_LENGTH('dbo.Plates', 'Latitude') IS NULL
    ALTER TABLE dbo.Plates ADD Latitude DECIMAL(9,6) NULL;
IF COL_LENGTH('dbo.Plates', 'Longitude') IS NULL
    ALTER TABLE dbo.Plates ADD Longitude DECIMAL(9,6) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Plates_GeoCoordinates' AND parent_object_id = OBJECT_ID('dbo.Plates'))
    ALTER TABLE dbo.Plates ADD CONSTRAINT CK_Plates_GeoCoordinates CHECK (
        (Latitude IS NULL AND Longitude IS NULL) OR
        (Latitude BETWEEN -90 AND 90 AND Longitude BETWEEN -180 AND 180)
    );
GO
/* Enter only surveyed/verified real plate locations. Example syntax (NOT a real location):
UPDATE dbo.Plates SET Latitude = <actual_latitude>, Longitude = <actual_longitude>
WHERE PlateID = <actual_plate_id>;
*/
SELECT PlateID, PlateNumber, Latitude, Longitude FROM dbo.Plates;
GO
