
<%@ Page Language="C#" AutoEventWireup="true"
    CodeBehind="ExcelImportTest.aspx.cs"
    Inherits="PlateBookingWeb.ExcelImportTest" %>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Excel Import Test</title>
    <style>
        body {
            font-family: Arial;
            background: #f4f6f9;
            padding: 40px;
        }

        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            max-width: 900px;
            margin: auto;
        }

        .btn {
            background: #1976d2;
            color: white;
            border: none;
            padding: 12px 25px;
            cursor: pointer;
            border-radius: 5px;
            margin-top: 15px;
        }

        .grid {
            width: 100%;
            margin-top: 20px;
            border-collapse: collapse;
        }

        .grid th, .grid td {
            padding: 10px;
            border: 1px solid #ddd;
        }

        .grid th {
            background: #1976d2;
            color: white;
        }
    </style>
</head>

<body>
    <form id="form1" runat="server">
        <div class="container">

            <h2>Excel Import System</h2>
            <p>Select an Excel file to read its data.</p>

            <!-- Excel file selection -->
            <asp:FileUpload
                ID="FileUpload1"
                runat="server" />

            <br />

            <!-- Read Excel button -->
            <asp:Button
                ID="btnImport"
                runat="server"
                Text="Read Excel File"
                CssClass="btn"
                OnClick="btnImport_Click" />

            <br /><br />

            <!-- Status messages -->
            <asp:Label
                ID="lblMessage"
                runat="server" />

            <!-- Excel data preview -->
            <asp:GridView
                ID="GridView1"
                runat="server"
                AutoGenerateColumns="true"
                CssClass="grid"
                EmptyDataText="No data to display." />

        </div>
    </form>
</body>
</html>
