using System;
using System.Security.Cryptography;
using System.Configuration;
using System.Web;
using System.Web.UI;

namespace PlateBookingWeb
{
    public partial class PlateBooking : Page
    {
        protected string ApiToken { get; private set; }

        protected void Page_Load(object sender, EventArgs e)
        {
            bool preview = string.Equals(ConfigurationManager.AppSettings["LocalPreviewOnly"], "true", StringComparison.OrdinalIgnoreCase);
            if (preview && !Request.IsLocal)
                throw new HttpException(403, "Local preview is available only from this computer.");
            if (!preview && (Context.User == null || Context.User.Identity == null || !Context.User.Identity.IsAuthenticated))
                throw new HttpException(401, "Windows employee sign-in is required in live mode.");
            // POST AJAX endpoints validate this per-session anti-forgery token.
            var token = Session["PlateBookingToken"] as string;
            if (string.IsNullOrEmpty(token))
            {
                byte[] random = new byte[32];
                using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(random);
                token = Convert.ToBase64String(random);
                Session["PlateBookingToken"] = token;
            }
            ApiToken = token;
            Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
            Response.Cache.SetNoStore();
        }
    }
}
