using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.UI;

namespace PlateBookingWeb
{
    public partial class ConnectionStatus : Page
    {
        protected string ModeLabel, DatabaseName, ServerName, LoginName, ConnectionMessage;
        protected bool ConnectionOK;
        protected int TablesFound;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Request.IsLocal) throw new HttpException(403, "Connection diagnostics are available only locally.");
            bool preview = string.Equals(ConfigurationManager.AppSettings["LocalPreviewOnly"], "true", StringComparison.OrdinalIgnoreCase);
            ModeLabel = preview ? "Local Preview (read-only; no real bookings)" : "Live (Windows employee login required)";
            LoginName = Context.User != null && Context.User.Identity != null && Context.User.Identity.IsAuthenticated
                ? Context.User.Identity.Name : "Not authenticated (expected in preview mode)";
            ConnectionMessage = "Not tested";
            var entry = ConfigurationManager.ConnectionStrings["PlateBookingDB"];
            if (entry == null) { ConnectionMessage = "Missing PlateBookingDB connection string"; return; }
            var sb = new SqlConnectionStringBuilder(entry.ConnectionString);
            DatabaseName = sb.InitialCatalog;
            ServerName = sb.DataSource;
            if (!preview && (Context.User == null || Context.User.Identity == null || !Context.User.Identity.IsAuthenticated))
                throw new HttpException(401, "An authenticated Windows employee is required in Live mode.");
            try
            {
                using (var cn = new SqlConnection(entry.ConnectionString))
                {
                    cn.Open();
                    using (var cmd = new SqlCommand("SELECT COUNT(*) FROM sys.tables WHERE name IN ('Customers','Employees','BookingStatuses','PlateTypes','Plates','BookingRequests','BookingRequestPlates','BookingAttachments') AND schema_id=SCHEMA_ID('dbo')", cn))
                        TablesFound = Convert.ToInt32(cmd.ExecuteScalar());
                    ConnectionOK = true;
                    ConnectionMessage = "Connected successfully";
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("ConnectionStatus SQL error: " + ex);
                ConnectionMessage = "Connection failed. Check your SQL instance, database setup and SQL permissions (details in Visual Studio Output).";
            }
        }
    }
}
