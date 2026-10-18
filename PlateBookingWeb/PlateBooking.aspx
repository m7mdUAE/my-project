<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="PlateBooking.aspx.cs" Inherits="PlateBookingWeb.PlateBooking" %>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>نظام اللوحات الذكي - شاشة الطلب</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800&family=Almarai:wght@400;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzxU8V4S9fZ9l9EwIhQvO8U+RE=" crossorigin="anonymous">
<link rel="stylesheet" href="Content/plate-booking.css">
</head>
<body>
<input type="hidden" id="api-token" value="<%= System.Web.HttpUtility.HtmlAttributeEncode(ApiToken) %>">  <div class="data-source-message" id="data-source-message" role="alert" style="display:none;"></div>

  <div id="toast-wrap"></div>

  <div id="modal-overlay">
    <div class="modal">
      <div class="m-icn">
        <svg width="30" height="30" viewBox="0 0 24 24" fill="none"><path d="M4 12l6 6L20 6" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </div>
      <h3 id="modal-title">تم تقديم الطلب بنجاح</h3>
      <p>سيتم التواصل مع المتعامل عبر الهاتف أو البريد الإلكتروني لاستكمال باقي الإجراءات.<br>
      رقم المرجع: <span class="ref" id="ref-number">—</span><br>
      هذا الطلب ساري المفعول حتى <span class="ref" id="ref-expiry">—</span> (أسبوع من تاريخ اليوم).</p>
      <button id="modal-close">تم</button>
    </div>
  </div>

  <header class="topbar">
    <div class="brand">
      <div class="brand-mark">
        <img src="Content/municipality-logo.png" alt="شعار بلدية دبا الحصن">
      </div>
      <div>
        <div class="brand-text-ar">بلديـة دبـا الحـصـن</div>
        <div class="brand-text-en">Dibba Al-Hisn Municipality</div>
      </div>
    </div>
    <div class="divider-v"></div>
    <div class="system-title">نظام اللوحات الذكي</div>
    <nav class="topbar-nav" aria-label="التنقل بين الشاشات">
      <button type="button" class="view-btn active" id="order-view-btn" aria-controls="order-page">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M5 4h14v16H5V4Z" stroke="currentColor" stroke-width="1.8"/><path d="M8 8h8M8 12h8M8 16h5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
        شاشة الطلب
      </button>
      <button type="button" class="view-btn" id="dashboard-view-btn" aria-controls="dashboard-page">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><rect x="3" y="3" width="7" height="7" rx="1" stroke="currentColor" stroke-width="1.8"/><rect x="14" y="3" width="7" height="7" rx="1" stroke="currentColor" stroke-width="1.8"/><rect x="3" y="14" width="7" height="7" rx="1" stroke="currentColor" stroke-width="1.8"/><rect x="14" y="14" width="7" height="7" rx="1" stroke="currentColor" stroke-width="1.8"/></svg>
        لوحة المعلومات
      </button>
      <button type="button" class="view-btn" id="manager-view-btn" aria-controls="manager-page">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M4 6h16M4 12h16M4 18h10" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="19" cy="18" r="2" stroke="currentColor" stroke-width="1.6"/></svg>
        إدارة الطلبات
      </button>
    </nav>
  </header>

  <main class="page app-view active" id="order-page">

    <div class="page-heading">
      <h1>شاشة الطلب</h1>
      <div class="heading-underline"></div>
    </div>

    <div class="order-layout">
      <aside class="order-sidebar" aria-label="الملاحظات والتعليمات">
        <div class="staff-notice">
          <span class="staff-notice-icn">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.8"/><path d="M12 8h.01M11 11h1v5h1" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
          </span>
          <div class="staff-notice-text">
            <strong>ملاحظة هامة:</strong> هذه الشاشة مخصصة لموظفي مركز إسعاد المتعاملين لإدخال بيانات الراغبين في حجز اللوحات.
          </div>
        </div>

        <section class="card sidebar-guidance">
          <div class="request-manager-head">
            <h2>ملاحظات وتعليمات الاختيار</h2>
            <span>شروط اللوحات والمرفقات والرسوم</span>
          </div>
          <div class="sidebar-guidance-body">
            <div class="notice">
              <span class="dot"><svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 2 1 21h22L12 2Z" stroke="#9a6b12" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 9v5" stroke="#9a6b12" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="17" r="1" fill="#9a6b12"/></svg></span>
              يحق اختيار لوحة 8 م فقط للجهات الحكومية أو لحاملي الرخص التجارية، أما غير ذلك فيقتصر الاختيار على Mobi أو 6 م.
            </div>

            <div class="field attachment-field" id="attachment-field">
              <label for="attachment">إرفاق ما يثبت أنك جهة حكومية أو رخصة تجارية <span class="field-optional">(اختياري)</span></label>
              <label class="attachment-shell" id="attachment-shell">
                <span class="attachment-placeholder" id="attachment-placeholder">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none"><path d="M21 12v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h9" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><path d="M15 4h5v5M20 4l-9 9" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  اضغط لإرفاق ملف (PDF أو صورة) — مثل الرخصة التجارية أو خطاب رسمي
                </span>
                <span class="attachment-filename" id="attachment-filename" style="display:none;">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M14 2v6h6" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>
                  <span id="attachment-filename-text"></span>
                  <button type="button" id="attachment-remove" aria-label="إزالة المرفق">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
                  </button>
                </span>
                <input id="attachment" type="file" accept=".pdf,.jpg,.jpeg,.png" style="display:none;">
              </label>
            </div>

            <div class="notice notice-success" id="exemption-notice">
              <span class="dot"><svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 22s8-4.5 8-11V5l-8-3-8 3v6c0 6.5 8 11 8 11Z" stroke="#1e9e5a" stroke-width="1.6" stroke-linejoin="round"/><path d="M9 12l2 2 4-4" stroke="#1e9e5a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></span>
              يتم إعفاء الجهات الحكومية من دفع رسوم اللوحات، بينما يبقى حاملو الرخص التجارية والأفراد ملزمين بالرسوم المقررة.
            </div>
          </div>
        </section>
      </aside>

      <form id="app-form" novalidate>

      <section class="card">
        <div class="card-head">
          <h2>
            <span class="icn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z" stroke="currentColor" stroke-width="1.8"/><path d="M4 20c0-3.5 3.5-6 8-6s8 2.5 8 6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></span>
            بيانات مقدم الطلب
          </h2>
        </div>
        <div class="card-body">
          <div class="field-row" style="grid-template-columns:1fr;margin-bottom:20px;">
            <div class="field">
              <label for="customer-name">اسم المتعامل</label>
              <div class="input-shell" id="name-shell">
                <input id="customer-name" type="text" placeholder="الاسم الكامل"  required>
                <span class="field-icn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z" stroke="currentColor" stroke-width="1.6"/><path d="M4 20c0-3.5 3.5-6 8-6s8 2.5 8 6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg></span>
              </div>
              <div class="err" id="name-err"></div>
            </div>
          </div>

          <div class="field-row">
            <div class="field">
              <label for="phone">الهاتف</label>
              <div class="input-shell" id="phone-shell">
                <input id="phone" type="tel" placeholder="05X XXX XXXX"  required>
                <span class="field-icn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M6.6 10.8c1.4 2.8 3.8 5.2 6.6 6.6l2.2-2.2c.3-.3.7-.4 1.1-.3 1.2.4 2.5.6 3.8.6.6 0 1 .5 1 1V20c0 .6-.4 1-1 1C10.6 21 3 13.4 3 3.7c0-.6.5-1 1-1h3.5c.6 0 1 .4 1 1 0 1.3.2 2.6.6 3.8.1.4 0 .8-.3 1.1L6.6 10.8Z" stroke="currentColor" stroke-width="1.6"/></svg></span>
              </div>
              <div class="err" id="phone-err"></div>
            </div>
            <div class="field">
              <label for="email">البريد الإلكتروني</label>
              <div class="input-shell" id="email-shell">
                <input id="email" type="email" placeholder="name@example.com"  required>
                <span class="field-icn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M3 6h18v12H3V6Z" stroke="currentColor" stroke-width="1.6"/><path d="M3 7l9 6 9-6" stroke="currentColor" stroke-width="1.6"/></svg></span>
              </div>
              <div class="err" id="email-err"></div>
            </div>
          </div>

          <div class="field-row">
            <div class="field">
              <label for="id-front">صورة الهوية الإماراتية - الوجه الأمامي</label>
              <label class="attachment-shell" id="id-front-shell">
                <span class="attachment-placeholder" id="id-front-placeholder">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none"><rect x="2" y="5" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.7"/><circle cx="8" cy="12" r="2.2" stroke="currentColor" stroke-width="1.5"/><path d="M13 10h6M13 14h4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
                  اضغط لإرفاق صورة الهوية (الوجه الأمامي)
                </span>
                <span class="attachment-filename" id="id-front-filename" style="display:none;">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M14 2v6h6" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>
                  <span id="id-front-filename-text"></span>
                  <button type="button" id="id-front-remove" aria-label="إزالة المرفق">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
                  </button>
                </span>
                <input id="id-front" type="file" accept=".pdf,.jpg,.jpeg,.png" style="display:none;">
              </label>
              <div class="err" id="id-front-err"></div>
            </div>
            <div class="field">
              <label for="id-back">صورة الهوية الإماراتية - الوجه الخلفي</label>
              <label class="attachment-shell" id="id-back-shell">
                <span class="attachment-placeholder" id="id-back-placeholder">
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none"><rect x="2" y="5" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.7"/><path d="M5 9h14M5 13h9" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
                  اضغط لإرفاق صورة الهوية (الوجه الخلفي)
                </span>
                <span class="attachment-filename" id="id-back-filename" style="display:none;">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M14 2v6h6" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>
                  <span id="id-back-filename-text"></span>
                  <button type="button" id="id-back-remove" aria-label="إزالة المرفق">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
                  </button>
                </span>
                <input id="id-back" type="file" accept=".pdf,.jpg,.jpeg,.png" style="display:none;">
              </label>
              <div class="err" id="id-back-err"></div>
            </div>
          </div>

          <div class="question-row">
            <div class="question-text">
              <span class="qi"><svg width="17" height="17" viewBox="0 0 24 24" fill="none"><path d="M4 21V9l8-6 8 6v12" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9 21v-6h6v6" stroke="currentColor" stroke-width="1.7"/></svg></span>
              هل مقدم الطلب جهة حكومية او لديه رخصة تجارية ؟
            </div>
            <div class="radio-group">
              <label class="radio-opt"><input type="radio" name="is-licensed" value="no"><span>لا</span></label>
              <label class="radio-opt"><input type="radio" name="is-licensed" value="yes" checked><span>نعم</span></label>
            </div>
          </div>

          <div class="question-row">
            <div class="question-text">
              <span class="qi"><svg width="17" height="17" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="16" rx="2" stroke="currentColor" stroke-width="1.7"/><path d="M3 9h18M8 3v4M16 3v4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg></span>
              هل ترغب في استلام اللوحة بعد انتهاء المدة؟
            </div>
            <div class="radio-group">
              <label class="radio-opt"><input type="radio" name="want-pickup" value="no"><span>لا</span></label>
              <label class="radio-opt"><input type="radio" name="want-pickup" value="yes" checked><span>نعم</span></label>
            </div>
          </div>

          <div class="field notes-field" style="margin-top:18px;">
            <label for="notes">ملاحظات <span class="field-optional">(اختياري)</span></label>
            <div class="input-shell">
              <textarea id="notes" placeholder="أي تفاصيل إضافية يذكرها المتعامل أثناء الاتصال أو في البريد الإلكتروني..."></textarea>
            </div>
          </div>
        </div>
      </section>

      <section class="card">
        <div class="card-head">
          <h2>
            <span class="icn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="16" rx="2" stroke="currentColor" stroke-width="1.7"/><path d="M3 9h18M8 3v4M16 3v4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg></span>
            اختيار المدة
          </h2>
        </div>
        <div class="card-body">
          <div class="duration-grid">
            <div class="duration-field">
              <label>إلى</label>
              <div class="duration-inputs">
                <div class="duration-chip">
                  <input id="date-to" type="date" >
                  <span class="field-icn"><svg width="15" height="15" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="16" rx="2" stroke="currentColor" stroke-width="1.6"/></svg></span>
                </div>
              </div>
            </div>
            <div class="duration-field">
              <label>من</label>
              <div class="duration-inputs">
                <div class="duration-chip">
                  <input id="date-from" type="date" >
                  <span class="field-icn"><svg width="15" height="15" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="16" rx="2" stroke="currentColor" stroke-width="1.6"/></svg></span>
                </div>
              </div>
            </div>
          </div>
          <div class="err" id="duration-err"></div>
          <div class="info-bar">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.6"/><path d="M12 8h.01M11 11h1v5h1" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
            تظهر حالة التوفر بناءً على الفترة المحددة أعلاه.
          </div>
        </div>
      </section>

      <div class="bottom-grid">
        <section class="card selected-card">
          <div class="card-head">
            <h2 id="selected-title">اللوحات المختارة (0)</h2>
          </div>
          <div class="selected-list" id="selected-list">
            <div class="empty-state">لم يتم اختيار أي لوحة بعد — اضغط على لوحة متوفرة على الخريطة</div>
          </div>
          <div class="price-total">
            <div class="label">إجمالي السعر :</div>
            <div class="amount" id="total-price">0 د.إ</div>
          </div>
        </section>

        <section class="card map-card">
          <div class="card-head">
            <h2>
              <span class="icn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 21s7-6.4 7-11.5A7 7 0 0 0 5 9.5C5 14.6 12 21 12 21Z" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="9.5" r="2.3" stroke="currentColor" stroke-width="1.5"/></svg></span>
              اختيار اللوحة على الخريطة
            </h2>
            <span class="map-sub">تظهر حالة التوفر بناءً على الفترة المحددة</span>
          </div>

          <div class="map-wrap" id="map-wrap">
            <div id="realMap" class="real-map" role="application" aria-label="خريطة مواقع اللوحات الإعلانية"></div>
            <div class="map-empty-note" id="map-empty-note" hidden>لا توجد مواقع لوحات مسجلة بإحداثيات صحيحة حتى الآن.</div>
          </div>

          <div class="filter-row">
            <div class="filter-chips" id="filter-chips">
              <button type="button" class="chip" data-size="mobi">Mobi</button>
              <button type="button" class="chip" data-size="6m">6 م</button>
              <button type="button" class="chip active" data-size="8m">8 م <span class="chip-badge"><svg width="10" height="10" viewBox="0 0 24 24" fill="none"><path d="M4 12l6 6L20 6" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg></span></button>
            </div>
            <div class="filter-label">
              تصفية حسب حجم اللوحة
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none"><path d="M4 5h16l-6 8v6l-4-2v-4L4 5Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>
            </div>
          </div>
          <div class="filter-note">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.6"/><path d="M8 12l3 3 5-6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>
            لوحة 8 م متاحة فقط للجهات الحكومية أو لحاملي الرخص التجارية
          </div>
        </section>
      </div>

      <div class="actions">
        <button type="submit" class="btn btn-primary" id="submit-btn">
          تقديم
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M21 3 3 10.5l7 3 3 7L21 3Z" stroke="#fff" stroke-width="1.7" stroke-linejoin="round"/></svg>
        </button>
        <button type="button" class="btn btn-outline" id="back-btn">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M19 12H5M11 6l-6 6 6 6" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>
          رجوع
        </button>
      </div>

      <div class="validity-note">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.7"/><path d="M12 7v5l4 2" stroke="currentColor" stroke-width="1.7"/></svg>
        سيبقى الطلب ساري المفعول لمدة أقصاها أسبوع من تاريخ تقديمه لاستكمال باقي الإجراءات.
      </div>
      </form>
    </div>

  </main>

  <main class="page manager-page app-view" id="manager-page">
    <div class="dashboard-heading">
      <div class="page-heading">
        <h1>إدارة الطلبات</h1>
        <div class="heading-underline"></div>
      </div>
      <p>البحث عن الطلبات السابقة ومتابعة جميع الطلبات وقائمة التحصيل</p>
    </div>

    <section class="card request-manager manager-page-card">
      <div class="request-manager-head">
        <h2>مركز إدارة الطلبات</h2>
        <span>اختر القسم المطلوب من الخيارات أدناه</span>
      </div>
      <div class="manager-tabs" role="tablist" aria-label="خيارات إدارة الطلبات">
        <button type="button" class="manager-tab" data-manager-tab="retrieve" role="tab" aria-selected="false">الرجوع لطلب سابق</button>
        <button type="button" class="manager-tab active" data-manager-tab="requests" role="tab" aria-selected="true">جميع الطلبات <span id="requests-tab-count">0</span></button>
        <button type="button" class="manager-tab" data-manager-tab="payment" role="tab" aria-selected="false">قائمة التحصيل <span id="payment-tab-count">0</span></button>
      </div>

      <div class="manager-panel retrieve-card" id="manager-retrieve" role="tabpanel">
        <div class="manager-panel-title">الرجوع لطلب سابق وتعديله</div>
        <div class="card-body">
          <div class="retrieve-row">
            <div class="field">
              <label for="retrieve-ref">رقم الطلب أو الهاتف أو البريد الإلكتروني أو الاسم</label>
              <div class="input-shell">
                <input id="retrieve-ref" type="text" placeholder="مثال: DH-100001 أو أحمد">
              </div>
            </div>
            <button type="button" class="btn btn-outline" id="retrieve-btn">بحث واسترجاع</button>
          </div>
          <div class="retrieve-hint">ابحث عن الطلب ثم اختره للعودة مباشرة إلى شاشة الطلب وبياناته.</div>
          <div class="retrieve-results" id="retrieve-results"></div>
          <div class="editing-banner" id="editing-banner">
            <div class="editing-banner-text">جاري تعديل الطلب رقم <b id="editing-ref-label">—</b></div>
            <button type="button" class="editing-cancel" id="cancel-edit-btn">إلغاء التعديل</button>
          </div>
        </div>
      </div>

      <div class="manager-panel active" id="manager-requests" role="tabpanel">
        <div class="manager-panel-title">جميع الطلبات</div>
        <div class="requests-list" id="requests-list"></div>
      </div>

      <div class="manager-panel" id="manager-payment" role="tabpanel">
        <div class="manager-panel-title">قائمة التحصيل والدفع</div>
        <div class="requests-list" id="payment-list"></div>
      </div>
    </section>
  </main>

  <main class="page dashboard-page app-view" id="dashboard-page">
    <div class="dashboard-heading">
      <div class="page-heading">
        <h1>لوحة معلومات الطلبات</h1>
        <div class="heading-underline"></div>
      </div>
      <div class="dashboard-heading-actions">
        <p>متابعة حالات الطلبات ونسب الإنجاز حسب تاريخ الطلب ونوع اللوحة</p>
        <button type="button" class="pdf-export-btn" id="dashboard-export-pdf">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none"><path d="M7 3h7l4 4v14H7V3Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M14 3v5h4M9.5 14h5M9.5 17h3.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          تصدير البيانات PDF
        </button>
      </div>
    </div>

    <section class="card">
      <div class="dashboard-filters">
        <div class="field">
          <label for="dashboard-date-from">من تاريخ</label>
          <div class="input-shell">
            <input id="dashboard-date-from" type="date" >
          </div>
        </div>
        <div class="field">
          <label for="dashboard-date-to">إلى تاريخ</label>
          <div class="input-shell">
            <input id="dashboard-date-to" type="date" >
          </div>
        </div>
        <div class="field">
          <label for="dashboard-plate-type">نوع اللوحة</label>
          <div class="input-shell">
            <select id="dashboard-plate-type" aria-label="تصفية حسب نوع اللوحة">
              <option value="all">جميع الأنواع</option>
              <option value="mobi">Mobi</option>
              <option value="6m">6 م</option>
              <option value="8m">8 م</option>
            </select>
          </div>
        </div>
        <button type="button" class="filter-apply" id="dashboard-apply">تطبيق التصفية</button>
        <div class="dashboard-filter-error" id="dashboard-filter-error" role="alert"></div>
      </div>
    </section>

    <section class="dashboard-summary" aria-live="polite">
      <div>
        <div class="summary-label">إجمالي الطلبات ضمن الفترة المحددة</div>
        <div class="summary-number" id="dashboard-total-orders">0</div>
      </div>
      <div class="summary-meta" id="dashboard-total-plates">إجمالي اللوحات: 0</div>
    </section>

    <section class="status-grid" id="dashboard-status-grid" aria-label="ملخص حالات الطلبات">
      <button type="button" class="status-card completed" data-dashboard-status="completed">
        <span class="status-card-head">
          <span class="status-name">منجزة</span>
          <span class="status-icon"><svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M4 12l5 5L20 6" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg></span>
        </span>
        <span class="status-card-value"><span class="status-count" data-count>0</span><span class="status-percent" data-percent>0%</span></span>
      </button>
      <button type="button" class="status-card canceled" data-dashboard-status="canceled">
        <span class="status-card-head">
          <span class="status-name">ملغاة</span>
          <span class="status-icon"><svg width="20" height="20" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.9"/><path d="m9 9 6 6m0-6-6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg></span>
        </span>
        <span class="status-card-value"><span class="status-count" data-count>0</span><span class="status-percent" data-percent>0%</span></span>
      </button>
      <button type="button" class="status-card pending" data-dashboard-status="pending">
        <span class="status-card-head">
          <span class="status-name">معلقة</span>
          <span class="status-icon"><svg width="20" height="20" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.9"/><path d="M12 7v5l3 2" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg></span>
        </span>
        <span class="status-card-value"><span class="status-count" data-count>0</span><span class="status-percent" data-percent>0%</span></span>
      </button>
      <button type="button" class="status-card in_progress" data-dashboard-status="in_progress">
        <span class="status-card-head">
          <span class="status-name">قيد التنفيذ</span>
          <span class="status-icon"><svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M12 3v3m0 12v3M3 12h3m12 0h3M5.6 5.6l2.1 2.1m8.6 8.6 2.1 2.1m0-12.8-2.1 2.1m-8.6 8.6-2.1 2.1" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg></span>
        </span>
        <span class="status-card-value"><span class="status-count" data-count>0</span><span class="status-percent" data-percent>0%</span></span>
      </button>
    </section>

    <section class="dashboard-grid">
      <section class="card details-card" id="dashboard-details">
        <div class="card-head">
          <h2 id="dashboard-details-title">تفاصيل الحالة</h2>
          <span class="detail-count" id="dashboard-details-count">0 طلب</span>
        </div>
        <div class="status-breakdown" id="dashboard-breakdown"></div>
        <div class="dashboard-table-wrap">
          <table class="dashboard-table">
            <thead>
              <tr>
                <th>رقم الطلب</th>
                <th>اسم المتعامل</th>
                <th>اللوحات</th>
                <th>العدد</th>
                <th>من</th>
                <th>إلى</th>
                <th>الحالة</th>
              </tr>
            </thead>
            <tbody id="dashboard-table-body"></tbody>
          </table>
          <div class="table-empty" id="dashboard-table-empty" hidden>لا توجد طلبات مطابقة لهذه الحالة والتصفية.</div>
        </div>
      </section>
    </section>

    <section class="pdf-report" id="pdf-report" aria-hidden="true">
      <div class="pdf-report-header">
        <div>
          <h1>تقرير طلبات اللوحات</h1>
          <p>بلدية دبا الحصن — نظام اللوحات الذكي</p>
        </div>
        <div class="pdf-report-date" id="pdf-report-generated"></div>
      </div>
      <div class="pdf-filter-summary" id="pdf-filter-summary"></div>
      <div class="pdf-summary-grid" id="pdf-summary-grid"></div>
      <div class="pdf-section-grid">
        <div class="pdf-section-box">
          <h2>عدد اللوحات حسب النوع</h2>
          <div class="pdf-plate-type-grid" id="pdf-plate-type-grid"></div>
        </div>
        <div class="pdf-section-box">
          <h2>الرسم البياني لحالات الطلبات</h2>
          <div class="pdf-status-chart" id="pdf-status-chart"></div>
        </div>
      </div>
      <h2>تفاصيل الطلبات</h2>
      <table class="pdf-data-table">
        <thead>
          <tr>
            <th>رقم الطلب</th>
            <th>المتعامل</th>
            <th>اللوحات</th>
            <th>العدد</th>
            <th>من</th>
            <th>إلى</th>
            <th>الحالة</th>
          </tr>
        </thead>
        <tbody id="pdf-table-body"></tbody>
      </table>
    </section>
  </main>

<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin="anonymous"></script>
<script src="Scripts/plate-booking.js"></script>

</body>
</html>