/* Run AFTER PlateBookingDB_Full_Setup.sql in SSMS. Idempotent migration.
   Adds columns required by the existing HTML workflow. Does not insert fake bookings. */
USE PlateBookingDB;
GO
IF COL_LENGTH('dbo.Employees','LoginName') IS NULL
    ALTER TABLE dbo.Employees ADD LoginName NVARCHAR(256) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Employees') AND name='UX_Employees_LoginName')
    CREATE UNIQUE INDEX UX_Employees_LoginName ON dbo.Employees(LoginName) WHERE LoginName IS NOT NULL;
GO
IF COL_LENGTH('dbo.BookingRequests','IsLicensed') IS NULL
    ALTER TABLE dbo.BookingRequests ADD IsLicensed BIT NOT NULL CONSTRAINT DF_Bookings_Licensed DEFAULT (0);
IF COL_LENGTH('dbo.BookingRequests','WantPickup') IS NULL
    ALTER TABLE dbo.BookingRequests ADD WantPickup BIT NOT NULL CONSTRAINT DF_Bookings_Pickup DEFAULT (0);
IF COL_LENGTH('dbo.BookingRequests','PaymentStatus') IS NULL
    ALTER TABLE dbo.BookingRequests ADD PaymentStatus NVARCHAR(24) NOT NULL CONSTRAINT DF_Bookings_PaymentStatus DEFAULT (N'pending');
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name='CK_Bookings_PaymentStatus' AND parent_object_id=OBJECT_ID('dbo.BookingRequests'))
    ALTER TABLE dbo.BookingRequests ADD CONSTRAINT CK_Bookings_PaymentStatus CHECK (PaymentStatus IN (N'pending',N'sent_to_payment',N'paid'));
GO
IF COL_LENGTH('dbo.Plates','Price') IS NULL
    ALTER TABLE dbo.Plates ADD Price DECIMAL(12,2) NOT NULL CONSTRAINT DF_Plates_Price DEFAULT (0);
IF COL_LENGTH('dbo.Plates','MapX') IS NULL
    ALTER TABLE dbo.Plates ADD MapX DECIMAL(5,2) NOT NULL CONSTRAINT DF_Plates_MapX DEFAULT (50);
IF COL_LENGTH('dbo.Plates','MapY') IS NULL
    ALTER TABLE dbo.Plates ADD MapY DECIMAL(5,2) NOT NULL CONSTRAINT DF_Plates_MapY DEFAULT (50);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name='CK_Plates_PriceAndMap' AND parent_object_id=OBJECT_ID('dbo.Plates'))
    ALTER TABLE dbo.Plates ADD CONSTRAINT CK_Plates_PriceAndMap CHECK (Price >= 0 AND MapX BETWEEN 0 AND 100 AND MapY BETWEEN 0 AND 100);
GO
IF COL_LENGTH('dbo.BookingAttachments','AttachmentType') IS NULL
    ALTER TABLE dbo.BookingAttachments ADD AttachmentType NVARCHAR(20) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name='CK_AttachmentType' AND parent_object_id=OBJECT_ID('dbo.BookingAttachments'))
    ALTER TABLE dbo.BookingAttachments ADD CONSTRAINT CK_AttachmentType CHECK (AttachmentType IN (N'License',N'IDFront',N'IDBack'));
GO
/* Plate TYPE reference values used by the original interface. No plate records are inserted. */
INSERT dbo.PlateTypes(TypeName, Description)
SELECT s.TypeName,s.Description
FROM (VALUES (N'6m',N'لوحات 6 أمتار'),(N'8m',N'لوحات 8 أمتار'),(N'mobi',N'لوحات متحركة')) s(TypeName,Description)
WHERE NOT EXISTS(SELECT 1 FROM dbo.PlateTypes x WHERE x.TypeName=s.TypeName);
GO
/* No fake plate records or customer bookings are inserted. Add real plates explicitly. */
