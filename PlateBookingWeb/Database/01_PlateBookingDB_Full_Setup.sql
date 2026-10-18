/*
    Plate Booking System - Complete Database Setup
    Target platform: Microsoft SQL Server (SSMS)
    Database: PlateBookingDB (new, standalone database)

    Business rule: Customers call employees. Only employees enter booking
    requests into the application on customers' behalf.

    Running this script does not modify any other database.
    It can be re-run without recreating existing tables or seed statuses.
*/

USE [master];
GO

IF DB_ID(N'PlateBookingDB') IS NULL
BEGIN
    CREATE DATABASE [PlateBookingDB];
END;
GO

USE [PlateBookingDB];
GO

-- 1) Customers: people calling employees to request bookings.
IF OBJECT_ID(N'dbo.Customers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Customers
    (
        CustomerID INT IDENTITY(1,1) NOT NULL,
        FullName NVARCHAR(100) NOT NULL,
        Phone NVARCHAR(20) NOT NULL,
        Email NVARCHAR(100) NULL,
        Address NVARCHAR(200) NULL,
        Notes NVARCHAR(500) NULL,
        CreatedAt DATETIME2(0) NOT NULL
            CONSTRAINT DF_Customers_CreatedAt DEFAULT SYSUTCDATETIME(),
        IsActive BIT NOT NULL
            CONSTRAINT DF_Customers_IsActive DEFAULT (1),
        CONSTRAINT PK_Customers PRIMARY KEY (CustomerID)
    );
END;
GO

-- 2) Employees: authorized staff who enter customer requests.
IF OBJECT_ID(N'dbo.Employees', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Employees
    (
        EmployeeID INT IDENTITY(1,1) NOT NULL,
        FullName NVARCHAR(100) NOT NULL,
        Department NVARCHAR(100) NULL,
        Email NVARCHAR(100) NULL,
        Phone NVARCHAR(20) NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_Employees_IsActive DEFAULT (1),
        CONSTRAINT PK_Employees PRIMARY KEY (EmployeeID)
    );
END;
GO

-- 3) Possible statuses of an entire booking request.
IF OBJECT_ID(N'dbo.BookingStatuses', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BookingStatuses
    (
        StatusID TINYINT NOT NULL,
        StatusName NVARCHAR(50) NOT NULL,
        Description NVARCHAR(200) NULL,
        CONSTRAINT PK_BookingStatuses PRIMARY KEY (StatusID),
        CONSTRAINT UQ_BookingStatuses_StatusName UNIQUE (StatusName)
    );
END;
GO

INSERT INTO dbo.BookingStatuses (StatusID, StatusName, Description)
SELECT S.StatusID, S.StatusName, S.Description
FROM (VALUES
    (1, N'Pending',   N'Awaiting a booking decision'),
    (2, N'Approved',  N'Booking has been approved'),
    (3, N'Rejected',  N'Booking has been rejected'),
    (4, N'Completed', N'Booking has been completed'),
    (5, N'Cancelled', N'Booking has been cancelled')
) AS S(StatusID, StatusName, Description)
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.BookingStatuses AS Existing
    WHERE Existing.StatusID = S.StatusID
);
GO

-- 4) Plate categories/types.
IF OBJECT_ID(N'dbo.PlateTypes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PlateTypes
    (
        PlateTypeID INT IDENTITY(1,1) NOT NULL,
        TypeName NVARCHAR(50) NOT NULL,
        Description NVARCHAR(200) NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_PlateTypes_IsActive DEFAULT (1),
        CONSTRAINT PK_PlateTypes PRIMARY KEY (PlateTypeID),
        CONSTRAINT UQ_PlateTypes_TypeName UNIQUE (TypeName)
    );
END;
GO

-- 5) Individual plates. Plate numbers are unique inside each plate type.
IF OBJECT_ID(N'dbo.Plates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Plates
    (
        PlateID INT IDENTITY(1,1) NOT NULL,
        PlateNumber NVARCHAR(50) NOT NULL,
        PlateTypeID INT NOT NULL,
        Description NVARCHAR(100) NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_Plates_IsActive DEFAULT (1),
        CONSTRAINT PK_Plates PRIMARY KEY (PlateID),
        CONSTRAINT FK_Plates_PlateTypes FOREIGN KEY (PlateTypeID)
            REFERENCES dbo.PlateTypes(PlateTypeID),
        CONSTRAINT UQ_Plates_Type_Number UNIQUE (PlateTypeID, PlateNumber)
    );
END;
GO

-- 6) Booking requests: employee records the request for a customer.
IF OBJECT_ID(N'dbo.BookingRequests', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BookingRequests
    (
        RequestID INT IDENTITY(1,1) NOT NULL,
        CustomerID INT NOT NULL,
        EmployeeID INT NOT NULL,
        StatusID TINYINT NOT NULL
            CONSTRAINT DF_BookingRequests_StatusID DEFAULT (1),
        RequestDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_BookingRequests_RequestDate DEFAULT SYSUTCDATETIME(),
        Notes NVARCHAR(500) NULL,
        CONSTRAINT PK_BookingRequests PRIMARY KEY (RequestID),
        CONSTRAINT FK_BookingRequests_Customers FOREIGN KEY (CustomerID)
            REFERENCES dbo.Customers(CustomerID),
        CONSTRAINT FK_BookingRequests_Employees FOREIGN KEY (EmployeeID)
            REFERENCES dbo.Employees(EmployeeID),
        CONSTRAINT FK_BookingRequests_Statuses FOREIGN KEY (StatusID)
            REFERENCES dbo.BookingStatuses(StatusID)
    );
END;
GO

-- 7) Junction table: one request can contain many plates, and a plate
--    can appear on different requests (subject to date availability).
IF OBJECT_ID(N'dbo.BookingRequestPlates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BookingRequestPlates
    (
        RequestPlateID INT IDENTITY(1,1) NOT NULL,
        RequestID INT NOT NULL,
        PlateID INT NOT NULL,
        FromDate DATE NOT NULL,
        ToDate DATE NOT NULL,
        Notes NVARCHAR(200) NULL,
        CONSTRAINT PK_BookingRequestPlates PRIMARY KEY (RequestPlateID),
        CONSTRAINT FK_BookingRequestPlates_Requests FOREIGN KEY (RequestID)
            REFERENCES dbo.BookingRequests(RequestID),
        CONSTRAINT FK_BookingRequestPlates_Plates FOREIGN KEY (PlateID)
            REFERENCES dbo.Plates(PlateID),
        CONSTRAINT CK_BookingRequestPlates_Dates CHECK (FromDate <= ToDate),
        CONSTRAINT UQ_BookingRequestPlates_ExactPeriod
            UNIQUE (RequestID, PlateID, FromDate, ToDate)
    );
END;
GO

-- 8) Optional documents or images attached to a booking request.
IF OBJECT_ID(N'dbo.BookingAttachments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BookingAttachments
    (
        AttachmentID INT IDENTITY(1,1) NOT NULL,
        RequestID INT NOT NULL,
        FileName NVARCHAR(255) NOT NULL,
        FilePath NVARCHAR(500) NOT NULL,
        UploadedAt DATETIME2(0) NOT NULL
            CONSTRAINT DF_BookingAttachments_UploadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_BookingAttachments PRIMARY KEY (AttachmentID),
        CONSTRAINT FK_BookingAttachments_Requests FOREIGN KEY (RequestID)
            REFERENCES dbo.BookingRequests(RequestID)
    );
END;
GO

-- Helpful indexes on relationship and availability-search columns.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.BookingRequests')
                 AND name = N'IX_BookingRequests_CustomerID')
    CREATE INDEX IX_BookingRequests_CustomerID
        ON dbo.BookingRequests (CustomerID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.BookingRequests')
                 AND name = N'IX_BookingRequests_EmployeeID')
    CREATE INDEX IX_BookingRequests_EmployeeID
        ON dbo.BookingRequests (EmployeeID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.BookingRequests')
                 AND name = N'IX_BookingRequests_StatusID')
    CREATE INDEX IX_BookingRequests_StatusID
        ON dbo.BookingRequests (StatusID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.BookingRequestPlates')
                 AND name = N'IX_BookingRequestPlates_Plate_Dates')
    CREATE INDEX IX_BookingRequestPlates_Plate_Dates
        ON dbo.BookingRequestPlates (PlateID, FromDate, ToDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.BookingAttachments')
                 AND name = N'IX_BookingAttachments_RequestID')
    CREATE INDEX IX_BookingAttachments_RequestID
        ON dbo.BookingAttachments (RequestID);
GO

-- Verify the newly created tables and seeded statuses.
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO

SELECT StatusID, StatusName, Description
FROM dbo.BookingStatuses
ORDER BY StatusID;
GO

/*
 IMPORTANT BUSINESS RULES
 - Customers never insert their own requests; the application must ensure
   that only authenticated employees can create booking requests.
 - SQL foreign keys guarantee that EmployeeID belongs to an existing employee,
   but do not by themselves enforce login permissions.
 - The unique constraint prevents an *identical* duplicate plate/date row
   in the same request; it does not prevent overlapping date ranges across
   approved requests. Implement overlap checks with transaction-safe locking
   at approval time, and avoid bypassing that approval workflow.
 - Plates/requests are retained rather than cascade-deleted to preserve history.
*/
