/* OPTIONAL TEMPLATE - does NOT insert any data unless you edit/uncomment it.
   Execute 01 then 02 before using this file. */
USE PlateBookingDB;
GO
-- In a Windows Command Prompt, run `whoami` to find your real account.
-- Employee account mapping for Windows Authentication (replace both values):
-- INSERT dbo.Employees(FullName, LoginName, Department)
-- VALUES (N'Full Name', N'YOURPC\WindowsUsername', N'Bookings');
-- A real plate example (replace code, type and price with actual values):
-- INSERT dbo.Plates(PlateNumber, PlateTypeID, Price, MapX, MapY)
-- SELECT N'ACTUAL-PLATE-CODE', PlateTypeID, 0, 50, 50
-- FROM dbo.PlateTypes WHERE TypeName=N'6m';
GO
SELECT TypeName, PlateTypeID FROM dbo.PlateTypes;
SELECT EmployeeID, FullName, LoginName FROM dbo.Employees;
SELECT PlateID, PlateNumber FROM dbo.Plates;
