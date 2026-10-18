<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="ConnectionStatus.aspx.cs" Inherits="PlateBookingWeb.ConnectionStatus" %>
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>PlateBookingDB — Connection Status</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#eef2f8;color:#15263c;padding:28px;line-height:1.55}
main{background:white;max-width:840px;margin:auto;border-radius:15px;padding:32px;box-shadow:0 6px 30px #1c3b6b13}
h1{color:#1f4e78;margin-top:0} .tag{display:inline-block;border-radius:20px;padding:6px 14px;background:#eaf3fd;color:#225f96;font-weight:600}
.ok{color:#137345}.bad{color:#a32222}code,pre{background:#f4f6fa;border-radius:6px;padding:3px 6px}li{margin-bottom:9px} a{color:#215e9f}
</style></head><body><main>
<a href="PlateBooking.aspx">← Back to Booking System</a>
<h1>PlateBookingDB — Connection Status</h1>
<p><span class="tag"><%= Server.HtmlEncode(ModeLabel) %></span></p>
<p><b>Database:</b> <%= Server.HtmlEncode(DatabaseName) %></p>
<p><b>SQL Server:</b> <%= Server.HtmlEncode(ServerName) %></p>
<p><b>Windows account:</b> <%= Server.HtmlEncode(LoginName) %></p>
<p><b>Database test:</b> <span class="<%= ConnectionOK ? "ok" : "bad" %>"><%= Server.HtmlEncode(ConnectionMessage) %></span></p>
<p><b>Database tables found:</b> <%= TablesFound %> / 8</p>
<hr />
<h2>First-time setup</h2>
<ol><li>Run <code>Database/01_PlateBookingDB_Full_Setup.sql</code> and then <code>Database/02_WebForms_Upgrade.sql</code> in SSMS.</li>
<li>Open <code>Web.config</code> and set the <code>PlateBookingDB</code> connection string to your SQL Server instance.</li>
<li>Register the Windows login in <code>dbo.Employees.LoginName</code> (see <code>Database/03_Add_Real_Employee_And_Plates_Template.sql</code>).</li>
<li>Stop Visual Studio, run <code>Set-Mode.ps1 -Mode Live</code>, reopen the solution and press F5.</li></ol>
<p><b>Note:</b> Preview mode deliberately displays no booking/customer data and blocks saves. Live mode requires an authenticated Windows employee.</p>
</main></body></html>
