
using System;
using System.Data;
using System.IO;
using ClosedXML.Excel;

namespace PlateBookingWeb
{
    public partial class ExcelImportTest : System.Web.UI.Page
    {
        protected void btnImport_Click(object sender, EventArgs e)
        {
            lblMessage.Text = "";
            GridView1.DataSource = null;
            GridView1.DataBind();

            if (!FileUpload1.HasFile)
            {
                lblMessage.Text = "Please select an Excel file.";
                return;
            }

            string extension = Path.GetExtension(
                FileUpload1.FileName).ToLowerInvariant();

            if (extension != ".xlsx")
            {
                lblMessage.Text = "Only .xlsx files are allowed.";
                return;
            }

            // Example limit: 5 MB
            if (FileUpload1.PostedFile.ContentLength > 5 * 1024 * 1024)
            {
                lblMessage.Text = "File is too large.";
                return;
            }

            try
            {
                DataTable dt = new DataTable();
              
                using (var workbook = new XLWorkbook(
                    FileUpload1.PostedFile.InputStream))
                {
                    var worksheet = workbook.Worksheet(1);
                    var range = worksheet.RangeUsed();

                    if (range == null)
                    {
                        lblMessage.Text = "Excel file is empty.";
                        return;
                    }

                    int firstRow = range.RangeAddress.FirstAddress.RowNumber;
                    int lastRow = range.RangeAddress.LastAddress.RowNumber;
                    int firstCol = range.RangeAddress.FirstAddress.ColumnNumber;
                    int lastCol = range.RangeAddress.LastAddress.ColumnNumber;

                    // Read first row as column headers
                    for (int col = firstCol; col <= lastCol; col++)
                    {
                        string header = worksheet.Cell(firstRow, col)
                            .GetString().Trim();

                        if (string.IsNullOrWhiteSpace(header))
                            header = "Column" + col;

                        string uniqueHeader = header;
                        int suffix = 2;

                        while (dt.Columns.Contains(uniqueHeader))
                            uniqueHeader = header + "_" + suffix++;

                        dt.Columns.Add(uniqueHeader);
                    }

                    // Read remaining rows
                    for (int row = firstRow + 1; row <= lastRow; row++)
                    {
                        DataRow dataRow = dt.NewRow();

                        for (int col = firstCol; col <= lastCol; col++)
                        {
                            dataRow[col - firstCol] =
                                worksheet.Cell(row, col).GetFormattedString();
                        }

                        dt.Rows.Add(dataRow);
                    }
                }

                GridView1.DataSource = dt;
                GridView1.DataBind();

                lblMessage.Text =
                    "Excel loaded successfully. Rows: " + dt.Rows.Count;
            }
            catch (Exception ex)
            {
                lblMessage.ForeColor = System.Drawing.Color.Red;

                lblMessage.Text =
                    "Error Type: " +
                    Server.HtmlEncode(ex.GetType().Name) +
                    "<br/>Error Message: " +
                    Server.HtmlEncode(ex.Message) +
                    "<br/>Inner Exception: " +
                    Server.HtmlEncode(ex.InnerException?.Message ?? "None");
            }
        }

        protected void Button1_Click(object sender, EventArgs e)
        {

        }
    }
}
