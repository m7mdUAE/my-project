using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

namespace PlateBookingWeb
{
    // Windows-authenticated HTTP endpoint; no mock data and no client-controlled EmployeeID.
    public sealed class PlateBookingApi : IHttpHandler, IRequiresSessionState
    {
        private readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = 8 * 1024 * 1024 };
        private const int MaxFileBytes = 5 * 1024 * 1024;
        private string ConnectionString { get { return ConfigurationManager.ConnectionStrings["PlateBookingDB"].ConnectionString; } }
        public bool IsReusable { get { return false; } }

        public void ProcessRequest(HttpContext ctx)
        {
            ctx.Response.ContentType = "application/json; charset=utf-8";
            ctx.Response.Cache.SetCacheability(HttpCacheability.NoCache);
            ctx.Response.Cache.SetNoStore();
            ctx.Response.TrySkipIisCustomErrors = true;
            try
            {
                bool preview = string.Equals(ConfigurationManager.AppSettings["LocalPreviewOnly"], "true", StringComparison.OrdinalIgnoreCase);
                if (preview)
                {
                    if (!ctx.Request.IsLocal)
                        throw new ApiException(403, "Local preview is available only on localhost.");
                    if (ctx.Request.HttpMethod == "GET" && string.Equals(ctx.Request.QueryString["action"], "load", StringComparison.OrdinalIgnoreCase))
                    {
                        Reply(ctx, 200, new { ok = true, preview = true,
                            data = new { plates = new object[0], bookings = new object[0] } });
                        return;
                    }
                    throw new ApiException(403, "وضع المعاينة فقط. فعّل وضع التشغيل المباشر لتسجيل الطلبات في قاعدة البيانات.");
                }
                if (ctx.User == null || ctx.User.Identity == null || !ctx.User.Identity.IsAuthenticated)
                    throw new ApiException(401, "يلزم تسجيل الدخول بحساب الموظف.");

                using (var cn = new SqlConnection(ConnectionString))
                {
                    cn.Open();
                    int employeeId = FindEmployee(cn, ctx.User.Identity.Name);
                    if (employeeId == 0)
                        throw new ApiException(403, "حسابك غير مرتبط بموظف نشط. أضف LoginName إلى جدول Employees أولاً.");

                    string action = (ctx.Request.QueryString["action"] ?? "").ToLowerInvariant();
                    if (action == "load" && ctx.Request.HttpMethod == "GET")
                        Reply(ctx, 200, new { ok = true, data = LoadData(cn), loggedInAs = ctx.User.Identity.Name });
                    else if (action == "attachment" && ctx.Request.HttpMethod == "GET")
                        Download(ctx, cn);
                    else
                    {
                        if (ctx.Request.HttpMethod != "POST") throw new ApiException(405, "طريقة الطلب غير مدعومة.");
                        string csrf = ctx.Session == null ? null : ctx.Session["PlateBookingToken"] as string;
                        if (string.IsNullOrEmpty(csrf) || !string.Equals(csrf, ctx.Request.Form["token"], StringComparison.Ordinal))
                            throw new ApiException(403, "انتهت صلاحية الجلسة. حدّث الصفحة وحاول مرة أخرى.");

                        switch (action)
                        {
                            case "save": Reply(ctx, 200, Save(ctx, cn, employeeId)); break;
                            case "send": Reply(ctx, 200, ChangeStatus(cn, ctx, "send")); break;
                            case "paid": Reply(ctx, 200, ChangeStatus(cn, ctx, "paid")); break;
                            case "cancel": Reply(ctx, 200, ChangeStatus(cn, ctx, "cancel")); break;
                            default: throw new ApiException(404, "الإجراء المطلوب غير موجود.");
                        }
                    }
                }
            }
            catch (ApiException ex) { Reply(ctx, ex.StatusCode, new { ok = false, error = ex.Message }); }
            catch (SqlException ex)
            {
                System.Diagnostics.Trace.TraceError("PlateBooking SQL error: " + ex);
                Reply(ctx, 500, new { ok = false, error = "تعذر الاتصال بقاعدة البيانات أو تنفيذ العملية. راجع إعدادات الاتصال وسجل الخادم." });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("PlateBooking API error: " + ex);
                Reply(ctx, 500, new { ok = false, error = "حدث خطأ على الخادم. راجع سجل الخادم." });
            }
        }

        private void Reply(HttpContext ctx, int code, object data)
        {
            ctx.Response.StatusCode = code;
            ctx.Response.ContentType = "application/json; charset=utf-8";
            ctx.Response.Write(json.Serialize(data));
        }
        private static SqlParameter P(string key, SqlDbType type, object value)
        {
            return new SqlParameter(key, type) { Value = value ?? DBNull.Value };
        }
        private static object DbNullIfEmpty(string value)
        {
            return string.IsNullOrWhiteSpace(value) ? (object)DBNull.Value : value.Trim();
        }
        private static int FindEmployee(SqlConnection cn, string login)
        {
            using (var cmd = new SqlCommand("SELECT TOP (1) EmployeeID FROM dbo.Employees WHERE IsActive=1 AND LoginName=@login", cn))
            {
                cmd.Parameters.Add(P("@login", SqlDbType.NVarChar, login));
                return Convert.ToInt32(cmd.ExecuteScalar() ?? 0);
            }
        }
        private static string Day(DateTime d) { return d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture); }
        private static string Reference(int id) { return "DH-" + id.ToString("D6", CultureInfo.InvariantCulture); }
        private static int ParseReference(string reference)
        {
            if (reference == null || !Regex.IsMatch(reference, @"^DH-\d{1,9}$", RegexOptions.IgnoreCase))
                throw new ApiException(400, "رقم الطلب غير صالح.");
            int number;
            if (!int.TryParse(reference.Substring(3), out number) || number < 1)
                throw new ApiException(400, "رقم الطلب غير صالح.");
            return number;
        }
        private static bool IsActiveStatus(int status) { return status == 1 || status == 2; }
        private object LoadData(SqlConnection cn)
        {
            var plates = new List<object>();
            using (var cmd = new SqlCommand(@"SELECT p.PlateID,p.PlateNumber,t.TypeName,p.Price,p.Latitude,p.Longitude
                                            FROM dbo.Plates p JOIN dbo.PlateTypes t ON p.PlateTypeID=t.PlateTypeID
                                            WHERE p.IsActive=1 AND t.IsActive=1 ORDER BY p.PlateID", cn))
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                {
                    string size = r.GetString(2);
                    plates.Add(new { dbId = r.GetInt32(0), id = r.GetInt32(0).ToString(CultureInfo.InvariantCulture), name = r.GetString(1), size = size,
                        sizeLabel = size == "6m" ? "6 م" : size == "8m" ? "8 م" : size,
                        price = r.GetDecimal(3), latitude = r.IsDBNull(4) ? (decimal?)null : r.GetDecimal(4), longitude = r.IsDBNull(5) ? (decimal?)null : r.GetDecimal(5) });
                }
            var byId = new Dictionary<int, Dictionary<string, object>>();
            using (var cmd = new SqlCommand(@"SELECT b.RequestID,c.FullName,c.Phone,c.Email,b.IsLicensed,b.WantPickup,
                         b.RequestDate,b.StatusID,b.PaymentStatus,b.Notes
                         FROM dbo.BookingRequests b JOIN dbo.Customers c ON c.CustomerID=b.CustomerID
                         ORDER BY b.RequestID DESC", cn))
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                {
                    int id = r.GetInt32(0), statusId = r.GetByte(7);
                    var b = new Dictionary<string, object> {
                        {"ref",Reference(id)}, {"name",r.GetString(1)}, {"phone",r.GetString(2)},
                        {"email",r.IsDBNull(3) ? "" : r.GetString(3)},
                        {"isLicensed",r.GetBoolean(4) ? "yes" : "no"},
                        {"wantPickup",r.GetBoolean(5) ? "yes" : "no"},
                        {"createdAt",Day(r.GetDateTime(6))},
                        {"status",r.GetString(8)},
                        {"dashboardStatus",statusId == 4 ? "completed" : (statusId == 3 || statusId == 5) ? "canceled" : statusId == 2 ? "in_progress" : "pending"},
                        {"notes",r.IsDBNull(9) ? "" : r.GetString(9)},
                        {"plateIds",new List<string>()},
                        {"dateFrom",""}, {"dateTo",""},
                        {"attachmentName",""}, {"idFrontName",""}, {"idBackName",""}
                    };
                    byId[id] = b;
                }
            using (var cmd = new SqlCommand(@"SELECT rp.RequestID,p.PlateID,rp.FromDate,rp.ToDate
                                         FROM dbo.BookingRequestPlates rp JOIN dbo.Plates p ON rp.PlateID=p.PlateID
                                         ORDER BY rp.RequestPlateID", cn))
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                {
                    Dictionary<string, object> b;
                    if (!byId.TryGetValue(r.GetInt32(0), out b)) continue;
                    ((List<string>)b["plateIds"]).Add(r.GetInt32(1).ToString(CultureInfo.InvariantCulture));
                    // The existing HTML has one date interval for all selected plates.
                    b["dateFrom"] = Day(r.GetDateTime(2));
                    b["dateTo"] = Day(r.GetDateTime(3));
                }
            using (var cmd = new SqlCommand("SELECT RequestID,AttachmentType,FileName FROM dbo.BookingAttachments WHERE AttachmentType IS NOT NULL ORDER BY AttachmentID", cn))
            using (var r = cmd.ExecuteReader())
                while (r.Read())
                {
                    Dictionary<string, object> b;
                    if (!byId.TryGetValue(r.GetInt32(0), out b)) continue;
                    string t = r.GetString(1);
                    if (t == "License") b["attachmentName"] = r.GetString(2);
                    else if (t == "IDFront") b["idFrontName"] = r.GetString(2);
                    else if (t == "IDBack") b["idBackName"] = r.GetString(2);
                }
            return new { plates = plates, bookings = byId.Values.ToArray() };
        }

        private sealed class BookingInput
        {
            public string reference { get; set; }
            public string name { get; set; }
            public string phone { get; set; }
            public string email { get; set; }
            public string isLicensed { get; set; }
            public string wantPickup { get; set; }
            public string dateFrom { get; set; }
            public string dateTo { get; set; }
            public string notes { get; set; }
            public List<int> plateIds { get; set; }
            public bool keepLicense { get; set; }
            public bool keepIDFront { get; set; }
            public bool keepIDBack { get; set; }
        }
        private sealed class FileUpload
        {
            public string Kind, Name, VirtualPath, AbsolutePath;
        }
        private object Save(HttpContext ctx, SqlConnection cn, int employeeId)
        {
            BookingInput input;
            try { input = json.Deserialize<BookingInput>(ctx.Request.Form["payload"] ?? ""); }
            catch { throw new ApiException(400, "بيانات الطلب غير صالحة."); }
            if (input == null || string.IsNullOrWhiteSpace(input.name) || input.name.Trim().Length < 2 || input.name.Length > 100 ||
                string.IsNullOrWhiteSpace(input.phone) || input.phone.Length > 20 ||
                !Regex.IsMatch(input.phone, @"^[+0-9\s()\-]{7,20}$") ||
                !string.IsNullOrWhiteSpace(input.email) && (input.email.Length > 100 || !Regex.IsMatch(input.email, @"^[^\s@]+@[^\s@]+\.[^\s@]+$")) ||
                input.notes != null && input.notes.Length > 500 ||
                (input.isLicensed != "yes" && input.isLicensed != "no") ||
                (input.wantPickup != "yes" && input.wantPickup != "no") ||
                input.plateIds == null || input.plateIds.Count == 0 || input.plateIds.Count > 50 ||
                input.plateIds.Distinct().Count() != input.plateIds.Count)
                throw new ApiException(400, "يرجى التأكد من بيانات المتعامل واللوحات المختارة.");
            DateTime from, to;
            if (!DateTime.TryParseExact(input.dateFrom, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out from) ||
                !DateTime.TryParseExact(input.dateTo, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out to) || from >= to)
                throw new ApiException(400, "تاريخ الحجز غير صالح.");

            int existingId = string.IsNullOrEmpty(input.reference) ? 0 : ParseReference(input.reference);
            // Validate files BEFORE saving them or opening a transaction.
            var uploads = new List<FileUpload>();
            foreach (var item in new [] { new { form="attachment", type="License" }, new { form="id-front",type="IDFront" }, new { form="id-back",type="IDBack" } })
            {
                var file = ctx.Request.Files[item.form];
                if (file == null || file.ContentLength == 0) continue;
                ValidateFile(file);
                string extension = Path.GetExtension(file.FileName).ToLowerInvariant();
                string virtualPath = "~/App_Data/Uploads/" + Guid.NewGuid().ToString("N") + extension;
                uploads.Add(new FileUpload { Kind = item.type, Name = Path.GetFileName(file.FileName), VirtualPath = virtualPath,
                    AbsolutePath = ctx.Server.MapPath(virtualPath) });
            }
            // Track files written to disk; clean up if SQL transaction fails.
            var persistedFiles = new List<string>();
            try
            {
                using (var tx = cn.BeginTransaction(IsolationLevel.Serializable))
                {
                    int requestId = existingId, customerId = 0, statusId = 1;
                    if (existingId != 0)
                    {
                        using (var cmd = new SqlCommand("SELECT CustomerID,StatusID FROM dbo.BookingRequests WITH (UPDLOCK,HOLDLOCK) WHERE RequestID=@id", cn, tx))
                        {
                            cmd.Parameters.Add(P("@id",SqlDbType.Int,existingId));
                            using (var r = cmd.ExecuteReader())
                            {
                                if (!r.Read()) throw new ApiException(404, "الطلب غير موجود.");
                                customerId = r.GetInt32(0); statusId = r.GetByte(1);
                            }
                        }
                        if (statusId != 1) throw new ApiException(409, "يمكن تعديل الطلبات المعلقة فقط. الطلب الحالي ليس معلقاً.");
                    }
                    // A plate row lock serializes competing bookings of the same plate.
                    foreach (int plateId in input.plateIds.OrderBy(x => x))
                    {
                        using (var cmd = new SqlCommand(@"SELECT p.PlateID,t.TypeName
                              FROM dbo.Plates p WITH (UPDLOCK,HOLDLOCK)
                              JOIN dbo.PlateTypes t ON t.PlateTypeID=p.PlateTypeID
                              WHERE p.PlateID=@pid AND p.IsActive=1 AND t.IsActive=1", cn, tx))
                        {
                            cmd.Parameters.Add(P("@pid",SqlDbType.Int,plateId));
                            using (var r = cmd.ExecuteReader())
                            {
                                if (!r.Read()) throw new ApiException(409, "إحدى اللوحات المختارة لم تعد متاحة.");
                                if (r.GetString(1) == "8m" && input.isLicensed != "yes")
                                    throw new ApiException(400, "لوحة 8 م تتطلب جهة حكومية أو رخصة تجارية.");
                            }
                        }
                        using (var cmd = new SqlCommand(@"SELECT TOP (1) b.RequestID
                              FROM dbo.BookingRequestPlates rp WITH (UPDLOCK,HOLDLOCK)
                              JOIN dbo.BookingRequests b ON b.RequestID=rp.RequestID
                              WHERE rp.PlateID=@pid AND b.StatusID IN (1,2) AND b.RequestID<>@self
                              AND rp.FromDate<=@to AND rp.ToDate>=@from", cn, tx))
                        {
                            cmd.Parameters.Add(P("@pid",SqlDbType.Int,plateId));
                            cmd.Parameters.Add(P("@self",SqlDbType.Int,existingId));
                            cmd.Parameters.Add(P("@from",SqlDbType.Date,from));
                            cmd.Parameters.Add(P("@to",SqlDbType.Date,to));
                            if (cmd.ExecuteScalar() != null) throw new ApiException(409, "هذه اللوحة محجوزة خلال الفترة المختارة. حدّث الصفحة واختر فترة أخرى.");
                        }
                    }
                    foreach (var required in new[] { new {kind="IDFront",keep=input.keepIDFront},new {kind="IDBack",keep=input.keepIDBack} })
                    {
                        bool existing = existingId != 0 && required.keep && HasAttachment(cn,tx,existingId,required.kind);
                        if (!existing && !uploads.Any(x=>x.Kind==required.kind))
                            throw new ApiException(400, "يجب إرفاق الوجه الأمامي والخلفي للهوية.");
                    }
                    if (existingId != 0)
                    {
                        // Customer record is shared; reuse exact match or create a new one so historical data is preserved.
                        customerId = FindOrCreateCustomer(cn,tx,input);
                        using (var cmd = new SqlCommand(@"UPDATE dbo.BookingRequests SET CustomerID=@customer,IsLicensed=@licensed,
                                             WantPickup=@pickup,Notes=@notes WHERE RequestID=@id", cn, tx))
                        {
                            cmd.Parameters.Add(P("@customer",SqlDbType.Int,customerId));
                            cmd.Parameters.Add(P("@licensed",SqlDbType.Bit,input.isLicensed=="yes"));
                            cmd.Parameters.Add(P("@pickup",SqlDbType.Bit,input.wantPickup=="yes"));
                            cmd.Parameters.Add(P("@notes",SqlDbType.NVarChar,DbNullIfEmpty(input.notes)));
                            cmd.Parameters.Add(P("@id",SqlDbType.Int,existingId));
                            cmd.ExecuteNonQuery();
                        }
                        using (var cmd = new SqlCommand("DELETE FROM dbo.BookingRequestPlates WHERE RequestID=@id",cn,tx))
                        { cmd.Parameters.Add(P("@id",SqlDbType.Int,existingId));cmd.ExecuteNonQuery(); }
                    }
                    else
                    {
                        customerId = FindOrCreateCustomer(cn,tx,input);
                        using (var cmd = new SqlCommand(@"INSERT dbo.BookingRequests(CustomerID,EmployeeID,StatusID,IsLicensed,WantPickup,PaymentStatus,Notes)
                                  OUTPUT INSERTED.RequestID VALUES(@customer,@employee,1,@licensed,@pickup,N'pending',@notes)", cn, tx))
                        {
                            cmd.Parameters.Add(P("@customer",SqlDbType.Int,customerId));
                            cmd.Parameters.Add(P("@employee",SqlDbType.Int,employeeId));
                            cmd.Parameters.Add(P("@licensed",SqlDbType.Bit,input.isLicensed=="yes"));
                            cmd.Parameters.Add(P("@pickup",SqlDbType.Bit,input.wantPickup=="yes"));
                            cmd.Parameters.Add(P("@notes",SqlDbType.NVarChar,DbNullIfEmpty(input.notes)));
                            requestId = Convert.ToInt32(cmd.ExecuteScalar());
                        }
                    }
                    foreach (int plateId in input.plateIds)
                    {
                        using (var cmd = new SqlCommand(@"INSERT dbo.BookingRequestPlates(RequestID,PlateID,FromDate,ToDate)
                              VALUES(@request,@plate,@from,@to)",cn,tx))
                        {
                            cmd.Parameters.Add(P("@request",SqlDbType.Int,requestId));
                            cmd.Parameters.Add(P("@plate",SqlDbType.Int,plateId));
                            cmd.Parameters.Add(P("@from",SqlDbType.Date,from));
                            cmd.Parameters.Add(P("@to",SqlDbType.Date,to));
                            cmd.ExecuteNonQuery();
                        }
                    }
                    // Save verified files; metadata commits with the transaction.
                    foreach (var upload in uploads)
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(upload.AbsolutePath));
                        var posted = ctx.Request.Files[upload.Kind=="License"?"attachment":upload.Kind=="IDFront"?"id-front":"id-back"];
                        posted.SaveAs(upload.AbsolutePath);
                        persistedFiles.Add(upload.AbsolutePath);
                    }
                    foreach (string kind in new[] {"License","IDFront","IDBack"})
                    {
                        bool keep = kind=="License" ? input.keepLicense && input.isLicensed=="yes" : kind=="IDFront" ? input.keepIDFront : input.keepIDBack;
                        var replacement = uploads.FirstOrDefault(x=>x.Kind==kind);
                        if (existingId != 0 && (!keep || replacement!=null))
                        {
                            using (var cmd = new SqlCommand("DELETE FROM dbo.BookingAttachments WHERE RequestID=@id AND AttachmentType=@kind",cn,tx))
                            {
                                cmd.Parameters.Add(P("@id",SqlDbType.Int,requestId));
                                cmd.Parameters.Add(P("@kind",SqlDbType.NVarChar,kind));
                                cmd.ExecuteNonQuery();
                            }
                        }
                        if (replacement != null && (kind!="License" || input.isLicensed=="yes"))
                        {
                            using (var cmd = new SqlCommand(@"INSERT dbo.BookingAttachments(RequestID,AttachmentType,FileName,FilePath)
                                               VALUES(@id,@kind,@name,@path)",cn,tx))
                            {
                                cmd.Parameters.Add(P("@id",SqlDbType.Int,requestId));
                                cmd.Parameters.Add(P("@kind",SqlDbType.NVarChar,kind));
                                cmd.Parameters.Add(P("@name",SqlDbType.NVarChar,replacement.Name));
                                cmd.Parameters.Add(P("@path",SqlDbType.NVarChar,replacement.VirtualPath));
                                cmd.ExecuteNonQuery();
                            }
                        }
                    }
                    tx.Commit();
                    return new { ok=true, reference=Reference(requestId) };
                }
            }
            catch
            {
                foreach (string file in persistedFiles)
                {
                    try { if (File.Exists(file)) File.Delete(file); } catch { }
                }
                throw;
            }
        }
        private static int FindOrCreateCustomer(SqlConnection cn, SqlTransaction tx, BookingInput item)
        {
            using (var cmd = new SqlCommand(@"SELECT TOP (1) CustomerID FROM dbo.Customers WITH (UPDLOCK,HOLDLOCK)
                         WHERE FullName=@name AND Phone=@phone AND ISNULL(Email,N'')=@email ORDER BY CustomerID",cn,tx))
            {
                cmd.Parameters.Add(P("@name",SqlDbType.NVarChar,item.name.Trim()));
                cmd.Parameters.Add(P("@phone",SqlDbType.NVarChar,item.phone.Trim()));
                cmd.Parameters.Add(P("@email",SqlDbType.NVarChar,(item.email ?? "").Trim()));
                object result = cmd.ExecuteScalar();
                if (result != null) return Convert.ToInt32(result);
            }
            using (var cmd = new SqlCommand(@"INSERT dbo.Customers(FullName,Phone,Email) OUTPUT INSERTED.CustomerID
                                  VALUES(@name,@phone,@email)",cn,tx))
            {
                cmd.Parameters.Add(P("@name",SqlDbType.NVarChar,item.name.Trim()));
                cmd.Parameters.Add(P("@phone",SqlDbType.NVarChar,item.phone.Trim()));
                cmd.Parameters.Add(P("@email",SqlDbType.NVarChar,DbNullIfEmpty(item.email)));
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }
        private static bool HasAttachment(SqlConnection cn,SqlTransaction tx,int id,string kind)
        {
            using (var cmd = new SqlCommand("SELECT TOP (1) 1 FROM dbo.BookingAttachments WHERE RequestID=@id AND AttachmentType=@kind",cn,tx))
            {
                cmd.Parameters.Add(P("@id",SqlDbType.Int,id));
                cmd.Parameters.Add(P("@kind",SqlDbType.NVarChar,kind));
                return cmd.ExecuteScalar()!=null;
            }
        }
        private static void ValidateFile(HttpPostedFile file)
        {
            if (file.ContentLength < 4 || file.ContentLength > MaxFileBytes)
                throw new ApiException(400, "حجم المرفق يجب ألا يتجاوز 5 ميجابايت.");
            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (ext != ".pdf" && ext != ".png" && ext != ".jpg" && ext != ".jpeg")
                throw new ApiException(400, "المرفقات المسموحة: PDF، JPG، PNG.");
            var head = new byte[8];
            long pos = file.InputStream.CanSeek ? file.InputStream.Position : 0;
            int count = file.InputStream.Read(head,0,head.Length);
            if (file.InputStream.CanSeek) file.InputStream.Position=pos;
            bool valid = (ext==".pdf" && count>=5 && head[0]==0x25 && head[1]==0x50 && head[2]==0x44 && head[3]==0x46 && head[4]==0x2D)
                || (ext==".png" && count>=8 && head.Take(8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10}))
                || ((ext==".jpg" || ext==".jpeg") && count>=3 && head[0]==255 && head[1]==216 && head[2]==255);
            if (!valid) throw new ApiException(400, "محتوى المرفق لا يطابق نوع الملف.");
        }
        private object ChangeStatus(SqlConnection cn,HttpContext ctx,string action)
        {
            int id = ParseReference(ctx.Request.Form["reference"]);
            using (var tx = cn.BeginTransaction(IsolationLevel.Serializable))
            {
                string sql;
                if (action=="send")
                    sql = "UPDATE dbo.BookingRequests SET PaymentStatus=N'sent_to_payment' WHERE RequestID=@id AND StatusID=1 AND PaymentStatus=N'pending'";
                else if (action=="paid")
                    sql = "UPDATE dbo.BookingRequests SET PaymentStatus=N'paid',StatusID=2 WHERE RequestID=@id AND StatusID=1 AND PaymentStatus=N'sent_to_payment'";
                else
                    sql = "UPDATE dbo.BookingRequests SET StatusID=5 WHERE RequestID=@id AND StatusID=1 AND PaymentStatus=N'pending'";
                using (var cmd = new SqlCommand(sql,cn,tx))
                {
                    cmd.Parameters.Add(P("@id",SqlDbType.Int,id));
                    if (cmd.ExecuteNonQuery()!=1) throw new ApiException(409,"لا يمكن تغيير حالة هذا الطلب في مرحلته الحالية.");
                }
                tx.Commit();
            }
            return new { ok=true };
        }
        private void Download(HttpContext ctx,SqlConnection cn)
        {
            int id;
            if (!int.TryParse(ctx.Request.QueryString["id"],out id) || id < 1) throw new ApiException(400,"معرف المرفق غير صالح.");
            string filename, virtualPath;
            using (var cmd = new SqlCommand("SELECT FileName,FilePath FROM dbo.BookingAttachments WHERE AttachmentID=@id",cn))
            {
                cmd.Parameters.Add(P("@id",SqlDbType.Int,id));
                using (var r = cmd.ExecuteReader())
                {
                    if (!r.Read()) throw new ApiException(404,"المرفق غير موجود.");
                    filename = r.GetString(0);virtualPath=r.GetString(1);
                }
            }
            string fullPath = ctx.Server.MapPath(virtualPath);
            string directory = Path.GetFullPath(ctx.Server.MapPath("~/App_Data/Uploads/")).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            if (!Path.GetFullPath(fullPath).StartsWith(directory,StringComparison.OrdinalIgnoreCase) || !File.Exists(fullPath))
                throw new ApiException(404,"الملف غير موجود.");
            ctx.Response.Clear();
            ctx.Response.ContentType="application/octet-stream";
            ctx.Response.AddHeader("Content-Disposition","attachment; filename=\"" + Regex.Replace(filename,"[^a-zA-Z0-9_.-]","_") + "\"");
            ctx.Response.TransmitFile(fullPath);
        }
        private sealed class ApiException : Exception
        {
            public int StatusCode {get;private set;}
            public ApiException(int status, string message) : base(message) { StatusCode=status; }
        }
    }
}
