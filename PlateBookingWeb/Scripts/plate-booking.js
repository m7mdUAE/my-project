(function(){
  // Loaded from PlateBookingDB. Never generate sample customer requests in the browser.
  var PLATES = [];
  var bookings = {};
  var loaded = false;
  function apiError(err){ showToast('error', err && err.message ? err.message : 'تعذر تنفيذ العملية.'); }
  async function callApi(action, payload, includeFiles){
    var opts = { credentials:'same-origin' };
    if(action !== 'load'){
      var body = new FormData();
      body.append('token',document.getElementById('api-token').value);
      if(action === 'save'){
        body.append('payload',JSON.stringify(payload));
        if(includeFiles){
          ['attachment','id-front','id-back'].forEach(function(id){
            var input = document.getElementById(id);
            if(input && input.files && input.files.length) body.append(id,input.files[0]);
          });
        }
      } else { body.append('reference',payload.reference); }
      opts.method='POST'; opts.body=body;
    }
    var response = await fetch('PlateBookingApi.ashx?action=' + encodeURIComponent(action),opts);
    var data;
    try { data = await response.json(); } catch(ex){ throw new Error('استجابة غير صالحة من الخادم. تأكد من تشغيل الموقع داخل IIS وASP.NET.'); }
    if(!response.ok || !data.ok) throw new Error(data.error || 'تعذر تنفيذ العملية.');
    return data;
  }
  async function loadAll(){
    var result = await callApi('load');
    PLATES = result.data.plates || [];
    bookings = {};
    (result.data.bookings || []).forEach(function(b){ bookings[b.ref] = b; });
    loaded = true;
    var preview = !!result.preview;
    document.getElementById('submit-btn').disabled = preview;
    var notice = document.getElementById('data-source-message');
    notice.style.display = preview ? 'block' : 'none';
    if (preview) notice.innerHTML = 'وضع المعاينة المحلية: يمكنك استعراض الصفحات، لكن لن يتم تحميل بيانات المتعاملين أو حفظ الطلبات. ' +
      '<a href="ConnectionStatus.aspx">فحص الاتصال وإرشادات التفعيل</a>';
    else notice.textContent = '';
    renderPins();renderSelected();renderRequestsList();renderDashboard();
  }
  function plateName(id){
    var plate = PLATES.filter(function(p){return p.id === String(id);})[0];
    return plate ? plate.name : String(id);
  }

  var state = { activeSize:'8m', selected:{}, isLicensed:true, editingRef:null };

  var mapWrap = document.getElementById('map-wrap');
  var leafletMap = null;
  var markerLayer = null;
  // Center is a general map view, not a real advertising-board position.
  var defaultMapCenter = [25.62, 56.27];
  function initRealMap(){
    if (leafletMap) return true;
    if (typeof L === 'undefined') {
      mapWrap.querySelector('#map-empty-note').textContent = 'تعذر تحميل مكتبة الخريطة. تأكد من الاتصال بالإنترنت.';
      mapWrap.querySelector('#map-empty-note').hidden = false;
      return false;
    }
    leafletMap = L.map('realMap', { scrollWheelZoom: false }).setView(defaultMapCenter, 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a> contributors'
    }).addTo(leafletMap);
    markerLayer = L.layerGroup().addTo(leafletMap);
    setTimeout(function(){ leafletMap.invalidateSize(); }, 200);
    return true;
  }
  function hasCoordinates(plate){
    var lat = Number(plate.latitude), lng = Number(plate.longitude);
    return plate.latitude !== null && plate.latitude !== undefined && plate.latitude !== '' &&
           plate.longitude !== null && plate.longitude !== undefined && plate.longitude !== '' &&
           isFinite(lat) && isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
  function refreshMapSize(){
    if(leafletMap) setTimeout(function(){ leafletMap.invalidateSize(); }, 120);
  }
  var selectedList = document.getElementById('selected-list');
  var selectedTitle = document.getElementById('selected-title');
  var totalPriceEl = document.getElementById('total-price');
  var chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));

  function fmt(n){ return n.toLocaleString('en-US'); }

  function formatDateAr(d){
    try{
      return new Intl.DateTimeFormat('ar', { day:'numeric', month:'long', year:'numeric' }).format(d);
    }catch(e){
      return d.toISOString().slice(0,10);
    }
  }

  function addDays(dateStr, days){
    var d = new Date(dateStr + 'T00:00:00');
    d.setDate(d.getDate() + days);
    return d;
  }

  function sizeAllowed(size){
    if(size === '8m' && !state.isLicensed) return false;
    return true;
  }

  // Checks whether `plateId` has a conflicting booking overlapping the
  // currently-selected duration. Returns null if available, or the
  // conflicting booking's end date/time if unavailable (so we can tell the
  // user when it frees up). The booking currently being edited is excluded
  // from its own conflict check.
  function getConflict(plateId){
    var curFrom = new Date(dateFrom.value + 'T00:00');
    var curTo = new Date(dateTo.value + 'T23:59');
    if(isNaN(curFrom) || isNaN(curTo)) return null;

    var latestConflict = null;
    Object.keys(bookings).forEach(function(ref){
      if(state.editingRef && ref === state.editingRef) return;
      var b = bookings[ref];
      if(b.dashboardStatus === 'completed' || b.dashboardStatus === 'canceled') return;
      if(b.plateIds.indexOf(plateId) === -1) return;
      var bFrom = new Date(b.dateFrom + 'T00:00');
      var bTo = new Date(b.dateTo + 'T23:59');
      var overlaps = curFrom <= bTo && curTo >= bFrom;
      if(overlaps){
        if(!latestConflict || bTo > latestConflict) latestConflict = bTo;
      }
    });
    return latestConflict;
  }

  function renderPins(){
    if (!initRealMap()) return;
    markerLayer.clearLayers();
    var bounds = [];
    var visible = 0;
    PLATES.forEach(function(plate){
      // Do not guess a real-world position from the old MapX/MapY percentage coordinates.
      if (!hasCoordinates(plate)) return;
      var matchesFilter = plate.size === state.activeSize;
      if (!matchesFilter) return;
      var conflictUntil = getConflict(plate.id);
      var available = !conflictUntil;
      var allowed = sizeAllowed(plate.size);
      var selected = !!state.selected[plate.id];
      var color = !allowed ? '#718096' : !available ? '#d9534f' : selected ? '#2466b3' : '#18864b';
      var icon = L.divIcon({
        className: 'booking-map-marker-container',
        html: '<span class="booking-map-marker" style="background:' + color + '">' +
              (selected ? '&#10003;' : '&#9679;') + '</span>',
        iconSize: [30, 36], iconAnchor: [15, 34]
      });
      var latlng = [Number(plate.latitude), Number(plate.longitude)];
      var marker = L.marker(latlng, { icon:icon, keyboard:true }).addTo(markerLayer);
      var status = !allowed ? 'غير مسموح لهذا المتعامل' : available ? 'متوفرة' : 'غير متوفرة';
      var info = '<div class="booking-popup" dir="rtl"><strong>لوحة ' + escapeHtml(plate.name) + '</strong>' +
                 '<div>النوع: ' + escapeHtml(plate.sizeLabel || plate.size) + '</div>' +
                 '<div>الحالة: ' + status + '</div>' +
                 '<div>السعر: ' + escapeHtml(String(plate.price)) + ' د.إ</div>' +
                 '<small>اضغط على العلامة لاختيار اللوحة</small></div>';
      marker.bindPopup(info);
      marker.on('click', function(){
        if(!available){
          showToast('error', 'لوحة ' + escapeHtml(plate.name) + ' ستكون متوفرة بعد ' + formatDateAr(addDays(conflictUntil.toISOString().slice(0,10), 1)));
          return;
        }
        if(!allowed){
          showToast('error', 'لوحة 8 م متاحة فقط للجهات الحكومية أو لحاملي الرخص التجارية');
          return;
        }
        togglePlate(plate);
      });
      bounds.push(latlng); visible++;
    });
    var note = document.getElementById('map-empty-note');
    note.hidden = visible > 0;
    if(!visible) note.textContent = 'لا توجد مواقع لوحات مسجلة لهذا النوع بإحداثيات جغرافية. يمكنك استعراض الخريطة.';
    if(bounds.length && !leafletMap._plateBoundsSet){
      leafletMap.fitBounds(bounds, {padding:[32,32],maxZoom:14});
      leafletMap._plateBoundsSet = true;
    }
    refreshMapSize();
  }

  function togglePlate(plate){
    if(state.selected[plate.id]){ delete state.selected[plate.id]; }
    else { state.selected[plate.id] = plate; }
    renderPins();
    renderSelected();
  }

  function renderSelected(){
    var ids = Object.keys(state.selected);
    selectedTitle.textContent = 'اللوحات المختارة (' + ids.length + ')';

    if(ids.length === 0){
      selectedList.innerHTML = '<div class="empty-state">لم يتم اختيار أي لوحة بعد — اضغط على لوحة متوفرة على الخريطة</div>';
      totalPriceEl.textContent = '0 د.إ';
      return;
    }

    var total = 0;
    selectedList.innerHTML = '';
    ids.forEach(function(id){
      var p = state.selected[id];
      total += p.price;
      var row = document.createElement('div');
      row.className = 'selected-item';
      row.innerHTML =
        '<div class="left">' +
          '<span class="check-ic"><svg width="12" height="12" viewBox="0 0 24 24" fill="none"><path d="M4 12l6 6L20 6" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg></span>' +
          'لوحة ' + escapeHtml(p.name) + ' - ' + p.sizeLabel + ' - ' + fmt(p.price) + ' د.إ' +
        '</div>' +
        '<button type="button" class="remove-btn" aria-label="إزالة" data-id="' + p.id + '">' +
          '<svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>' +
        '</button>';
      selectedList.appendChild(row);
    });

    totalPriceEl.textContent = fmt(total) + ' د.إ';

    Array.prototype.slice.call(selectedList.querySelectorAll('.remove-btn')).forEach(function(btn){
      btn.addEventListener('click', function(){
        var id = btn.getAttribute('data-id');
        delete state.selected[id];
        renderPins();
        renderSelected();
      });
    });
  }

  chips.forEach(function(chip){
    chip.addEventListener('click', function(){
      if(chip.disabled) return;
      chips.forEach(function(c){ c.classList.remove('active'); });
      chip.classList.add('active');
      state.activeSize = chip.getAttribute('data-size');
      renderPins();
    });
  });

  function refreshChipAvailability(){
    chips.forEach(function(chip){
      var size = chip.getAttribute('data-size');
      if(size === '8m' && !state.isLicensed){
        chip.disabled = true;
        if(chip.classList.contains('active')){
          chip.classList.remove('active');
          var sixChip = document.querySelector('.chip[data-size="6m"]');
          sixChip.classList.add('active');
          state.activeSize = '6m';
        }
      } else {
        chip.disabled = false;
      }
    });
  }

  var licenseRadios = document.querySelectorAll('input[name="is-licensed"]');
  var attachmentField = document.getElementById('attachment-field');

  function refreshAttachmentVisibility(){
    attachmentField.classList.toggle('hidden', !state.isLicensed);
  }

  licenseRadios.forEach(function(r){
    r.addEventListener('change', function(){
      state.isLicensed = (r.value === 'yes' && r.checked);
      if(!state.isLicensed){
        Object.keys(state.selected).forEach(function(id){
          if(state.selected[id].size === '8m'){ delete state.selected[id]; }
        });
      }
      refreshChipAvailability();
      refreshAttachmentVisibility();
      renderPins();
      renderSelected();
    });
  });

  var phone = document.getElementById('phone');
  var email = document.getElementById('email');
  var customerName = document.getElementById('customer-name');
  var nameShell = document.getElementById('name-shell');
  var nameErr = document.getElementById('name-err');
  var phoneShell = document.getElementById('phone-shell');
  var emailShell = document.getElementById('email-shell');
  var phoneErr = document.getElementById('phone-err');
  var emailErr = document.getElementById('email-err');
  var dateFrom = document.getElementById('date-from');
  var dateTo = document.getElementById('date-to');
  var durationErr = document.getElementById('duration-err');
  var notes = document.getElementById('notes');

  // Generic factory for file-attachment widgets (license proof, ID front, ID back).
  // Each widget is built from a shared id prefix: {prefix}, {prefix}-placeholder,
  // {prefix}-filename, {prefix}-filename-text, {prefix}-remove.
  function createAttachment(prefix, onChange){
    var input = document.getElementById(prefix);
    var placeholder = document.getElementById(prefix + '-placeholder');
    var filenameEl = document.getElementById(prefix + '-filename');
    var filenameText = document.getElementById(prefix + '-filename-text');
    var removeBtn = document.getElementById(prefix + '-remove');
    var current = '';

    function set(name){
      current = name || '';
      if(current){
        placeholder.style.display = 'none';
        filenameEl.style.display = 'flex';
        filenameText.textContent = current;
      } else {
        placeholder.style.display = 'flex';
        filenameEl.style.display = 'none';
        filenameText.textContent = '';
        input.value = '';
      }
      if(onChange) onChange();
    }

    input.addEventListener('change', function(){
      var file = input.files && input.files[0];
      set(file ? file.name : '');
    });
    removeBtn.addEventListener('click', function(e){
      e.preventDefault();
      set('');
    });

    return { set: set, get: function(){ return current; } };
  }

  var licenseAttachment = createAttachment('attachment');
  var idFrontAttachment = createAttachment('id-front', function(){ validateIdCard(); });
  var idBackAttachment = createAttachment('id-back', function(){ validateIdCard(); });

  var idFrontErr = document.getElementById('id-front-err');
  var idBackErr = document.getElementById('id-back-err');

  function validateIdCard(){
    var frontOk = !!idFrontAttachment.get();
    var backOk = !!idBackAttachment.get();
    idFrontErr.textContent = frontOk ? '' : 'يرجى إرفاق صورة الهوية من الأمام';
    idBackErr.textContent = backOk ? '' : 'يرجى إرفاق صورة الهوية من الخلف';
    return frontOk && backOk;
  }

  function validateName(){
    var v = customerName.value.trim();
    var ok = v.length >= 2;
    nameShell.classList.toggle('invalid', !ok);
    nameErr.textContent = ok ? '' : 'يرجى إدخال اسم المتعامل';
    return ok;
  }

  function validatePhone(){
    var v = phone.value.trim();
    var ok = /^0\d{2}\s?\d{3}\s?\d{4}$/.test(v) || /^\+?\d{7,14}$/.test(v.replace(/\s/g,''));
    phoneShell.classList.toggle('invalid', !ok);
    phoneErr.textContent = ok ? '' : 'أدخل رقم هاتف صحيح';
    return ok;
  }
  function validateEmail(){
    var v = email.value.trim();
    var ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
    emailShell.classList.toggle('invalid', !ok);
    emailErr.textContent = ok ? '' : 'أدخل بريدًا إلكترونيًا صحيحًا';
    return ok;
  }
  function validateDuration(){
    var from = new Date(dateFrom.value + 'T00:00');
    var to = new Date(dateTo.value + 'T23:59');
    var ok = dateFrom.value && dateTo.value && from < to;
    durationErr.textContent = ok ? '' : 'تاريخ "إلى" يجب أن يكون بعد تاريخ "من"';
    return ok;
  }

  phone.addEventListener('input', validatePhone);
  email.addEventListener('input', validateEmail);
  customerName.addEventListener('input', validateName);
  [dateFrom,dateTo].forEach(function(el){
    el.addEventListener('change', function(){
      validateDuration();
      // Availability depends on the selected period, so re-check every plate
      // against existing bookings whenever the dates/times change.
      renderPins();
    });
  });

  function showToast(type, message){
    var wrap = document.getElementById('toast-wrap');
    var t = document.createElement('div');
    t.className = 'toast ' + type;
    var icon = type === 'success'
      ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M4 12l6 6L20 6" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>'
      : '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.8"/><path d="M12 8v5M12 16h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>';
    t.innerHTML = '<span class="t-icn">' + icon + '</span><span>' + message + '</span>';
    wrap.appendChild(t);
    setTimeout(function(){
      t.style.transition = 'opacity .3s ease';
      t.style.opacity = '0';
      setTimeout(function(){ t.remove(); }, 300);
    }, 3200);
  }

  var form = document.getElementById('app-form');
  var modalOverlay = document.getElementById('modal-overlay');
  var modalTitle = document.getElementById('modal-title');
  var refNumber = document.getElementById('ref-number');
  var refExpiry = document.getElementById('ref-expiry');
  var retrieveRefInput = document.getElementById('retrieve-ref');
  var editingBanner = document.getElementById('editing-banner');
  var editingRefLabel = document.getElementById('editing-ref-label');

  function dateKeyOffset(days){
    var d=new Date();d.setDate(d.getDate()+days);
    return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
  }
  function yearStart(){return String(new Date().getFullYear())+'-01-01';}
  function todayStr(){
    var d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
  }

  form.addEventListener('submit',async function(e){
    e.preventDefault();
    if(!loaded){ showToast('error','لم يكتمل اتصال قاعدة البيانات.'); return; }
    var nOk=validateName(),pOk=validatePhone(),eOk=validateEmail(),dOk=validateDuration(),idOk=validateIdCard();
    var hasPlates=Object.keys(state.selected).length > 0;
    if(!hasPlates) showToast('error','يرجى اختيار لوحة واحدة على الأقل من الخريطة');
    if(!nOk || !pOk || !eOk || !dOk || !idOk || !hasPlates) return;
    var editing = !!state.editingRef;
    var payload = {
      reference: editing ? state.editingRef : null,
      name:customerName.value.trim(),phone:phone.value.trim(),email:email.value.trim(),
      isLicensed:document.querySelector('input[name="is-licensed"]:checked').value,
      wantPickup:document.querySelector('input[name="want-pickup"]:checked').value,
      dateFrom:dateFrom.value,dateTo:dateTo.value,
      plateIds:Object.keys(state.selected).map(function(id){return Number(id);}),
      notes:notes.value.trim(),
      keepLicense:!!licenseAttachment.get(),
      keepIDFront:!!idFrontAttachment.get(),
      keepIDBack:!!idBackAttachment.get()
    };
    var submitButton = document.getElementById('submit-btn');
    submitButton.disabled=true;
    try{
      var result=await callApi('save',payload,true);
      modalTitle.textContent=editing?'تم تحديث الطلب بنجاح':'تم تقديم الطلب بنجاح';
      refNumber.textContent=result.reference;
      refExpiry.textContent=formatDateAr(addDays(todayStr(),7));
      modalOverlay.classList.add('open');
      exitEditMode();
      state.selected={};
      form.reset();
      customerName.value='';phone.value='';email.value='';notes.value='';
      licenseAttachment.set('');idFrontAttachment.set('');idBackAttachment.set('');
      dateFrom.value=todayStr();dateTo.value=dateKeyOffset(7);
      state.isLicensed=true;refreshChipAvailability();refreshAttachmentVisibility();
      await loadAll();
    } catch(err) { apiError(err); }
    finally { submitButton.disabled=false; }
  });

  document.getElementById('modal-close').addEventListener('click', function(){
    modalOverlay.classList.remove('open');
  });
  modalOverlay.addEventListener('click', function(e){
    if(e.target === modalOverlay) modalOverlay.classList.remove('open');
  });

  document.getElementById('back-btn').addEventListener('click', function(){
    switchView('manager');
  });

  // ---------- Retrieve a previous request for editing ----------
  function enterEditMode(ref){
    var b = bookings[ref];
    if(!b || b.status !== 'pending' || b.dashboardStatus !== 'pending'){ showToast('error','لا يمكن تعديل هذا الطلب بعد إرساله للتحصيل أو إلغائه.'); return; }
    state.editingRef = ref;

    customerName.value = b.name || '';
    phone.value = b.phone;
    email.value = b.email;
    document.querySelector('input[name="is-licensed"][value="' + b.isLicensed + '"]').checked = true;
    document.querySelector('input[name="want-pickup"][value="' + b.wantPickup + '"]').checked = true;
    state.isLicensed = b.isLicensed === 'yes';

    dateFrom.value = b.dateFrom;
    dateTo.value = b.dateTo;
    notes.value = b.notes || '';
    licenseAttachment.set(b.attachmentName || '');
    idFrontAttachment.set(b.idFrontName || '');
    idBackAttachment.set(b.idBackName || '');
    validateIdCard();

    state.selected = {};
    b.plateIds.forEach(function(id){
      var plate = PLATES.filter(function(p){ return p.id === id; })[0];
      if(plate) state.selected[id] = plate;
    });

    editingRefLabel.textContent = ref;
    editingBanner.classList.add('show');

    validatePhone(); validateEmail(); validateDuration(); validateName();
    refreshChipAvailability();
    refreshAttachmentVisibility();
    renderPins();
    renderSelected();

    switchView('order');
    showToast('success', 'تم استرجاع الطلب رقم ' + ref + ' — يمكنك الآن تعديله');
    form.scrollIntoView({ behavior:'smooth', block:'start' });
  }

  var retrieveResultsEl = document.getElementById('retrieve-results');

  function normalize(s){ return (s || '').toString().trim().toLowerCase(); }

  function searchBookings(query){
    var q = normalize(query);
    var qDigits = q.replace(/[^\d]/g, '');
    return Object.keys(bookings).filter(function(ref){
      var b = bookings[ref];
      if(normalize(ref) === q) return true;
      if(normalize(b.email).indexOf(q) !== -1 && q.length > 2) return true;
      if((b.name || '').toLowerCase().indexOf(q) !== -1 && q.length > 1) return true;
      if(qDigits.length >= 3 && (b.phone || '').replace(/[^\d]/g,'').indexOf(qDigits) !== -1) return true;
      return false;
    });
  }

  function showRetrieveResults(refs){
    retrieveResultsEl.innerHTML = '';
    refs.forEach(function(ref){
      var b = bookings[ref];
      var item = document.createElement('div');
      item.className = 'retrieve-result-item';
      item.innerHTML =
        '<div class="retrieve-result-main">' +
          '<div class="retrieve-result-name">' + (b.name || 'بدون اسم') + ' — <span style="direction:ltr;display:inline-block;">' + ref + '</span></div>' +
          '<div class="retrieve-result-meta">' + escapeHtml(b.phone) + ' · ' + escapeHtml(b.email) + '</div>' +
        '</div>' +
        '<span class="retrieve-result-pick">اختيار</span>';
      item.addEventListener('click', function(){
        enterEditMode(ref);
        renderRequestsList();
        retrieveResultsEl.classList.remove('show');
      });
      retrieveResultsEl.appendChild(item);
    });
    retrieveResultsEl.classList.add('show');
  }

  function exitEditMode(){
    state.editingRef = null;
    editingBanner.classList.remove('show');
    retrieveRefInput.value = '';
    retrieveResultsEl.classList.remove('show');
    retrieveResultsEl.innerHTML = '';
  }

  document.getElementById('retrieve-btn').addEventListener('click', function(){
    var query = retrieveRefInput.value.trim();
    if(!query){
      showToast('error', 'يرجى إدخال رقم الطلب أو الهاتف أو البريد أو الاسم');
      return;
    }
    var matches = searchBookings(query);
    if(matches.length === 0){
      retrieveResultsEl.classList.remove('show');
      showToast('error', 'لم يتم العثور على أي طلب يطابق "' + query + '"');
      return;
    }
    if(matches.length === 1){
      retrieveResultsEl.classList.remove('show');
      enterEditMode(matches[0]);
      renderRequestsList();
      return;
    }
    showRetrieveResults(matches);
    showToast('success', 'تم العثور على ' + matches.length + ' طلبات مطابقة — يرجى اختيار الطلب المطلوب');
  });

  document.getElementById('cancel-edit-btn').addEventListener('click', function(){
    exitEditMode();
    state.selected = {};
    licenseAttachment.set('');
    idFrontAttachment.set('');
    idBackAttachment.set('');
    renderPins();
    renderSelected();
    renderRequestsList();
    showToast('success', 'تم إلغاء التعديل — يمكنك البدء بطلب جديد');
  });

  // ---------- Previous requests list ----------
  var requestsListEl = document.getElementById('requests-list');
  var paymentListEl = document.getElementById('payment-list');
  var managerTabs = Array.prototype.slice.call(document.querySelectorAll('.manager-tab'));

  function switchManagerTab(name){
    managerTabs.forEach(function(tab){
      var active = tab.getAttribute('data-manager-tab') === name;
      tab.classList.toggle('active',active);
      tab.setAttribute('aria-selected',active?'true':'false');
    });
    Array.prototype.slice.call(document.querySelectorAll('.manager-panel')).forEach(function(panel){
      panel.classList.toggle('active',panel.id === 'manager-' + name);
    });
  }

  managerTabs.forEach(function(tab){
    tab.addEventListener('click',function(){ switchManagerTab(tab.getAttribute('data-manager-tab')); });
  });

  var STATUS_LABEL = { pending:'بانتظار المراجعة', sent_to_payment:'بانتظار التحصيل', paid:'تم التحصيل' };
  var DASH_STATUS_LABEL = { completed:'منجزة', canceled:'ملغاة', pending:'معلقة', in_progress:'قيد التنفيذ' };

  function bookingTotal(b){
    return b.plateIds.reduce(function(sum, id){
      var plate = PLATES.filter(function(p){ return p.id === id; })[0];
      return sum + (plate ? plate.price : 0);
    }, 0);
  }

  function renderRequestsList(){
    var refs = Object.keys(bookings).sort(function(a,b){
      return bookings[b].createdAt.localeCompare(bookings[a].createdAt);
    });
    document.getElementById('requests-tab-count').textContent = refs.length;

    if(refs.length === 0){
      requestsListEl.innerHTML = '<div class="requests-empty">لا توجد طلبات سابقة بعد</div>';
    } else {
      requestsListEl.innerHTML = '';
      refs.forEach(function(ref){
        var b = bookings[ref];
        var plateTags = b.plateIds.map(function(id){
          return '<span class="req-plate-tag">' + escapeHtml(plateName(id)) + '</span>';
        }).join(' ');
        var statusClass = b.status || 'pending';
        var dashboardClass = b.dashboardStatus || 'pending';

        var canModify = statusClass === 'pending' && dashboardClass === 'pending';
        var sendBtn = canModify
          ? '<button type="button" class="req-send-btn" data-ref="' + ref + '">' +
              '<svg width="14" height="14" viewBox="0 0 24 24" fill="none"><rect x="2" y="6" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.8"/><path d="M2 10h20" stroke="currentColor" stroke-width="1.8"/></svg>' +
              'إرسال للتحصيل' +
            '</button>'
          : '';

        var row = document.createElement('div');
        row.className = 'req-row';
        row.innerHTML =
          '<div class="req-main">' +
            '<div class="req-ref">' + ref +
              '<span class="status-tag ' + dashboardClass + '">' + DASH_STATUS_LABEL[dashboardClass] + '</span>' +
              (state.editingRef === ref ? '<span class="editing-tag">قيد التعديل الآن</span>' : '') +
            '</div>' +
            '<div class="req-name">' + escapeHtml(b.name || '—') + '</div>' +
            '<div class="req-meta">' +
              '<span>' + escapeHtml(b.phone) + '</span>' +
              '<span>' + b.dateFrom + ' → ' + b.dateTo + '</span>' +
              '<span>' + (plateTags || '—') + '</span>' +
              '<span>ينتهي في ' + formatDateAr(addDays(b.createdAt, 7)) + '</span>' +
              (b.attachmentName ? '<span>📎 ' + b.attachmentName + '</span>' : '') +
              '<span>🪪 ' + (b.idFrontName && b.idBackName ? 'الهوية مرفقة (أمام وخلف)' : 'الهوية غير مكتملة') + '</span>' +
            '</div>' +
            (b.notes ? '<div class="req-notes">"' + escapeHtml(b.notes) + '"</div>' : '') +
          '</div>' +
          '<div class="req-actions">' +
            sendBtn +
            (canModify ? ('<button type="button" class="req-edit-btn" data-ref="' + ref + '">' +
              '<svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M4 20h4l11-11-4-4L4 16v4Z" stroke="currentColor" stroke-width="1.8"/></svg>تعديل</button>' +
              '<button type="button" class="req-delete-btn" data-ref="' + ref + '">' +
              '<svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2m-9 0 1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13" stroke="currentColor" stroke-width="1.8"/></svg>إلغاء الطلب</button>') : '') +
          '</div>';
        requestsListEl.appendChild(row);
      });

      Array.prototype.slice.call(requestsListEl.querySelectorAll('.req-edit-btn')).forEach(function(btn){
        btn.addEventListener('click', function(){
          enterEditMode(btn.getAttribute('data-ref'));
          renderRequestsList();
        });
      });

      Array.prototype.slice.call(requestsListEl.querySelectorAll('.req-delete-btn')).forEach(function(btn){
        btn.addEventListener('click', function(){
          deleteRequest(btn.getAttribute('data-ref'));
        });
      });

      Array.prototype.slice.call(requestsListEl.querySelectorAll('.req-send-btn')).forEach(function(btn){
        btn.addEventListener('click', function(){
          sendToPayment(btn.getAttribute('data-ref'));
        });
      });
    }

    renderPaymentList();
  }

  function renderPaymentList(){
    var refs = Object.keys(bookings).filter(function(ref){
      return bookings[ref].status === 'sent_to_payment' || bookings[ref].status === 'paid';
    }).sort(function(a,b){
      return bookings[b].createdAt.localeCompare(bookings[a].createdAt);
    });
    document.getElementById('payment-tab-count').textContent = refs.length;

    if(refs.length === 0){
      paymentListEl.innerHTML = '<div class="requests-empty">لا توجد طلبات مُرسلة للتحصيل حاليًا</div>';
      return;
    }

    paymentListEl.innerHTML = '';
    refs.forEach(function(ref){
      var b = bookings[ref];
      var total = bookingTotal(b);
      var plateTags = b.plateIds.map(function(id){
        return '<span class="req-plate-tag">' + escapeHtml(plateName(id)) + '</span>';
      }).join(' ');
      var isPaid = b.status === 'paid';

      var row = document.createElement('div');
      row.className = 'req-row';
      row.innerHTML =
        '<div class="req-main">' +
          '<div class="req-ref">' + ref +
            '<span class="status-tag ' + b.status + '">' + STATUS_LABEL[b.status] + '</span>' +
          '</div>' +
          '<div class="req-name">' + escapeHtml(b.name || '—') + '</div>' +
          '<div class="req-meta">' +
            '<span>' + escapeHtml(b.phone) + '</span>' +
            '<span>' + (plateTags || '—') + '</span>' +
            '<span class="req-price">' + fmt(total) + ' د.إ</span>' +
          '</div>' +
        '</div>' +
        (isPaid ? '' :
          '<div class="req-actions">' +
            '<button type="button" class="req-collect-btn" data-ref="' + ref + '">' +
              '<svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M4 12l6 6L20 6" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>' +
              'تأكيد التحصيل' +
            '</button>' +
          '</div>');
      paymentListEl.appendChild(row);
    });

    Array.prototype.slice.call(paymentListEl.querySelectorAll('.req-collect-btn')).forEach(function(btn){
      btn.addEventListener('click', function(){
        markPaid(btn.getAttribute('data-ref'));
      });
    });
  }

  async function sendToPayment(ref){
    try{ await callApi('send',{reference:ref}); await loadAll();
      showToast('success','تم إرسال الطلب رقم ' + ref + ' إلى قائمة التحصيل'); }
    catch(err){ apiError(err); }
  }
  async function markPaid(ref){
    if(!window.confirm('هل تم تحصيل المبلغ فعليًا للطلب ' + ref + '؟')) return;
    try{ await callApi('paid',{reference:ref}); await loadAll();
      showToast('success','تم تأكيد التحصيل للطلب رقم ' + ref); }
    catch(err){ apiError(err); }
  }
  async function deleteRequest(ref){
    var b = bookings[ref];if(!b) return;
    if(!window.confirm('هل تريد إلغاء الطلب رقم ' + ref + '؟ سيظل محفوظًا في السجل.')) return;
    try{
      await callApi('cancel',{reference:ref});
      if(state.editingRef===ref){exitEditMode();state.selected={};renderSelected();}
      await loadAll();showToast('success','تم إلغاء الطلب رقم ' + ref);
    } catch(err){apiError(err);}
  }

  // ---------- Dashboard view ----------
  var orderPage = document.getElementById('order-page');
  var dashboardPage = document.getElementById('dashboard-page');
  var managerPage = document.getElementById('manager-page');
  var orderViewBtn = document.getElementById('order-view-btn');
  var dashboardViewBtn = document.getElementById('dashboard-view-btn');
  var managerViewBtn = document.getElementById('manager-view-btn');
  var dashboardDateFrom = document.getElementById('dashboard-date-from');
  var dashboardDateTo = document.getElementById('dashboard-date-to');
  var dashboardPlateType = document.getElementById('dashboard-plate-type');
  var dashboardApply = document.getElementById('dashboard-apply');
  var dashboardFilterError = document.getElementById('dashboard-filter-error');
  var dashboardDetails = document.getElementById('dashboard-details');
  var dashboardState = { filtered:[], selectedStatus:null };
  var DASHBOARD_ORDER = ['completed','canceled','pending','in_progress'];
  var DASHBOARD_COLOR = { completed:'#1e9e5a', canceled:'#d9463c', pending:'#596579', in_progress:'#e49a24' };

  function switchView(view){
    var showOrder = view === 'order';
    var showDashboard = view === 'dashboard';
    var showManager = view === 'manager';
    orderPage.classList.toggle('active', showOrder);
    dashboardPage.classList.toggle('active', showDashboard);
    managerPage.classList.toggle('active', showManager);
    orderViewBtn.classList.toggle('active', showOrder);
    dashboardViewBtn.classList.toggle('active', showDashboard);
    managerViewBtn.classList.toggle('active', showManager);
    orderViewBtn.setAttribute('aria-current', showOrder ? 'page' : 'false');
    dashboardViewBtn.setAttribute('aria-current', showDashboard ? 'page' : 'false');
    managerViewBtn.setAttribute('aria-current', showManager ? 'page' : 'false');
    if(showDashboard) renderDashboard();
    if(showManager) renderRequestsList();
    window.scrollTo({top:0,behavior:'smooth'});
  }

  orderViewBtn.addEventListener('click', function(){ switchView('order'); });
  dashboardViewBtn.addEventListener('click', function(){ switchView('dashboard'); });
  managerViewBtn.addEventListener('click', function(){ switchView('manager'); });

  function dashboardBookingList(){
    var fromValue = dashboardDateFrom.value;
    var toValue = dashboardDateTo.value;
    if(!fromValue || !toValue || fromValue > toValue){
      dashboardFilterError.textContent = 'يرجى اختيار فترة صحيحة، بحيث يكون تاريخ «من» قبل تاريخ «إلى».';
      return null;
    }
    dashboardFilterError.textContent = '';
    var type = dashboardPlateType.value;
    return Object.keys(bookings).map(function(ref){ return bookings[ref]; }).filter(function(b){
      var withinDates = b.createdAt >= fromValue && b.createdAt <= toValue;
      if(!withinDates) return false;
      if(type === 'all') return true;
      return b.plateIds.some(function(id){
        var plate = PLATES.filter(function(p){ return p.id === id; })[0];
        return plate && plate.size === type;
      });
    }).sort(function(a,b){ return b.createdAt.localeCompare(a.createdAt); });
  }

  function countPlates(list){
    return list.reduce(function(total,b){ return total + b.plateIds.length; },0);
  }

  function countPlatesByType(list){
    var counts = { mobi:0, '6m':0, '8m':0 };
    list.forEach(function(b){
      b.plateIds.forEach(function(id){
        var plate = PLATES.filter(function(p){ return p.id === id; })[0];
        if(plate && counts.hasOwnProperty(plate.size)) counts[plate.size]++;
      });
    });
    return counts;
  }

  function displayPercent(count,total){
    if(!total) return '0%';
    var value = Math.round((count/total)*1000)/10;
    return (value % 1 === 0 ? value.toFixed(0) : value.toFixed(1)) + '%';
  }

  function escapeHtml(value){
    return String(value == null ? '' : value).replace(/[&<>"]/g,function(char){
      return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[char];
    });
  }

  function updateDashboardCards(list){
    var total = list.length;
    document.getElementById('dashboard-total-orders').textContent = total;
    document.getElementById('dashboard-total-plates').textContent = 'إجمالي اللوحات: ' + countPlates(list);

    DASHBOARD_ORDER.forEach(function(status){
      var statusList = list.filter(function(b){ return (b.dashboardStatus || 'pending') === status; });
      var card = document.querySelector('.status-card[data-dashboard-status="' + status + '"]');
      card.querySelector('[data-count]').textContent = statusList.length;
      card.querySelector('[data-percent]').textContent = displayPercent(statusList.length,total);
      card.classList.toggle('selected', dashboardState.selectedStatus === status);
      card.setAttribute('aria-label', DASH_STATUS_LABEL[status] + ': ' + statusList.length + ' طلب، ' + displayPercent(statusList.length,total));
    });
  }

  function plateDetails(ids){
    return ids.map(function(id){
      var plate = PLATES.filter(function(p){ return p.id === id; })[0];
      return plate ? ('لوحة ' + escapeHtml(plate.name) + ' (' + plate.sizeLabel + ')') : id;
    }).join('، ');
  }

  function renderDashboardDetails(){
    var status = dashboardState.selectedStatus;
    if(!status){
      dashboardDetails.classList.remove('show');
      dashboardDetails.parentElement.classList.remove('has-details');
      return;
    }
    var list = dashboardState.filtered.filter(function(b){ return (b.dashboardStatus || 'pending') === status; });
    dashboardDetails.classList.add('show');
    dashboardDetails.parentElement.classList.add('has-details');
    document.getElementById('dashboard-details-title').textContent = 'تفاصيل الطلبات — ' + DASH_STATUS_LABEL[status];
    document.getElementById('dashboard-details-count').textContent = list.length + ' طلب';

    var sizeCounts = { mobi:0, '6m':0, '8m':0 };
    list.forEach(function(b){
      b.plateIds.forEach(function(id){
        var plate = PLATES.filter(function(p){ return p.id === id; })[0];
        if(plate) sizeCounts[plate.size]++;
      });
    });
    document.getElementById('dashboard-breakdown').innerHTML =
      '<span class="breakdown-pill">Mobi: ' + sizeCounts.mobi + '</span>' +
      '<span class="breakdown-pill">6 م: ' + sizeCounts['6m'] + '</span>' +
      '<span class="breakdown-pill">8 م: ' + sizeCounts['8m'] + '</span>' +
      '<span class="breakdown-pill">إجمالي اللوحات: ' + countPlates(list) + '</span>';

    var body = document.getElementById('dashboard-table-body');
    var empty = document.getElementById('dashboard-table-empty');
    body.innerHTML = '';
    empty.hidden = list.length !== 0;
    document.querySelector('.dashboard-table').style.display = list.length ? 'table' : 'none';
    list.forEach(function(b){
      var row = document.createElement('tr');
      row.innerHTML =
        '<td><span class="table-ref">' + escapeHtml(b.ref) + '</span></td>' +
        '<td>' + escapeHtml(b.name || '—') + '</td>' +
        '<td>' + escapeHtml(plateDetails(b.plateIds)) + '</td>' +
        '<td>' + b.plateIds.length + '</td>' +
        '<td>' + escapeHtml(b.dateFrom) + '</td>' +
        '<td>' + escapeHtml(b.dateTo) + '</td>' +
        '<td><span class="status-tag ' + status + '">' + DASH_STATUS_LABEL[status] + '</span></td>';
      body.appendChild(row);
    });
  }

  function selectDashboardStatus(status,shouldScroll){
    dashboardState.selectedStatus = status;
    updateDashboardCards(dashboardState.filtered);
    renderDashboardDetails();
    if(shouldScroll && dashboardDetails.classList.contains('show')){
      dashboardDetails.scrollIntoView({behavior:'smooth',block:'start'});
    }
  }

  Array.prototype.slice.call(document.querySelectorAll('.status-card')).forEach(function(card){
    card.addEventListener('click',function(){ selectDashboardStatus(card.getAttribute('data-dashboard-status'),true); });
  });

  function renderDashboard(){
    var list = dashboardBookingList();
    if(list === null) return;
    dashboardState.filtered = list;
    updateDashboardCards(list);
    renderDashboardDetails();
  }

  function buildPdfReport(list){
    var typeLabel = dashboardPlateType.options[dashboardPlateType.selectedIndex].text;
    document.getElementById('pdf-report-generated').textContent = 'تاريخ إنشاء التقرير: ' + formatDateAr(new Date());
    document.getElementById('pdf-filter-summary').textContent =
      'فترة تاريخ الطلب: من ' + dashboardDateFrom.value + ' إلى ' + dashboardDateTo.value +
      ' — نوع اللوحة: ' + typeLabel;

    var summaryHtml =
      '<div class="pdf-summary-item" style="--pdf-color:#1f4e78">' +
        '<div class="pdf-summary-label">إجمالي الطلبات</div>' +
        '<div class="pdf-summary-value">' + list.length + '</div>' +
        '<div class="pdf-summary-meta">' + countPlates(list) + ' لوحة</div>' +
      '</div>';
    DASHBOARD_ORDER.forEach(function(status){
      var statusList = list.filter(function(b){ return (b.dashboardStatus || 'pending') === status; });
      summaryHtml +=
        '<div class="pdf-summary-item" style="--pdf-color:' + DASHBOARD_COLOR[status] + '">' +
          '<div class="pdf-summary-label">' + DASH_STATUS_LABEL[status] + '</div>' +
          '<div class="pdf-summary-value">' + statusList.length + '</div>' +
          '<div class="pdf-summary-meta">' + displayPercent(statusList.length,list.length) + ' من إجمالي الطلبات</div>' +
        '</div>';
    });
    document.getElementById('pdf-summary-grid').innerHTML = summaryHtml;

    var plateTypeCounts = countPlatesByType(list);
    document.getElementById('pdf-plate-type-grid').innerHTML =
      '<div class="pdf-plate-type-item"><div class="pdf-plate-type-label">Mobi</div><div class="pdf-plate-type-value">' + plateTypeCounts.mobi + '</div></div>' +
      '<div class="pdf-plate-type-item"><div class="pdf-plate-type-label">6 م</div><div class="pdf-plate-type-value">' + plateTypeCounts['6m'] + '</div></div>' +
      '<div class="pdf-plate-type-item"><div class="pdf-plate-type-label">8 م</div><div class="pdf-plate-type-value">' + plateTypeCounts['8m'] + '</div></div>' +
      '<div class="pdf-plate-type-item"><div class="pdf-plate-type-label">إجمالي اللوحات</div><div class="pdf-plate-type-value">' + countPlates(list) + '</div></div>';

    var pdfStatusCounts = DASHBOARD_ORDER.map(function(status){
      return list.filter(function(b){ return (b.dashboardStatus || 'pending') === status; }).length;
    });
    var pdfChartMax = Math.max.apply(Math,pdfStatusCounts.concat([1]));
    document.getElementById('pdf-status-chart').innerHTML = DASHBOARD_ORDER.map(function(status,index){
      var width = (pdfStatusCounts[index] / pdfChartMax) * 100;
      return '<div class="pdf-chart-row">' +
        '<div class="pdf-chart-label">' + DASH_STATUS_LABEL[status] + '</div>' +
        '<div class="pdf-chart-track"><div class="pdf-chart-bar" style="--pdf-bar-color:' + DASHBOARD_COLOR[status] + ';width:' + width + '%"></div></div>' +
        '<div class="pdf-chart-value">' + pdfStatusCounts[index] + '</div>' +
      '</div>';
    }).join('');

    var pdfBody = document.getElementById('pdf-table-body');
    if(!list.length){
      pdfBody.innerHTML = '<tr><td colspan="7">لا توجد طلبات ضمن التصفية الحالية.</td></tr>';
      return;
    }
    pdfBody.innerHTML = list.map(function(b){
      var status = b.dashboardStatus || 'pending';
      return '<tr>' +
        '<td>' + escapeHtml(b.ref) + '</td>' +
        '<td>' + escapeHtml(b.name || '—') + '</td>' +
        '<td>' + escapeHtml(plateDetails(b.plateIds)) + '</td>' +
        '<td>' + b.plateIds.length + '</td>' +
        '<td>' + escapeHtml(b.dateFrom) + '</td>' +
        '<td>' + escapeHtml(b.dateTo) + '</td>' +
        '<td>' + DASH_STATUS_LABEL[status] + '</td>' +
      '</tr>';
    }).join('');
  }

  document.getElementById('dashboard-export-pdf').addEventListener('click',function(){
    var list = dashboardBookingList();
    if(list === null){
      showToast('error','يرجى تصحيح فترة التصفية قبل تصدير التقرير.');
      return;
    }
    dashboardState.filtered = list;
    buildPdfReport(list);
    var previousTitle = document.title;
    document.title = 'تقرير-طلبات-اللوحات-' + todayStr();
    var restoreTitle = function(){ document.title = previousTitle; };
    window.addEventListener('afterprint',restoreTitle,{once:true});
    showToast('success','تم تجهيز التقرير — اختر «حفظ بصيغة PDF» من نافذة الطباعة.');
    setTimeout(function(){ window.print(); setTimeout(restoreTitle,500); },120);
  });

  dashboardApply.addEventListener('click',renderDashboard);
  dashboardPlateType.addEventListener('change',renderDashboard);
  dashboardDateFrom.addEventListener('change',renderDashboard);
  dashboardDateTo.addEventListener('change',renderDashboard);

  document.getElementById('submit-btn').disabled=true;
  dateFrom.value=todayStr();dateTo.value=dateKeyOffset(7);
  dashboardDateFrom.value=yearStart();dashboardDateTo.value=todayStr();
  refreshChipAvailability();refreshAttachmentVisibility();
  renderPins();renderSelected();renderRequestsList();renderDashboard();
  var orderPageObserver = new MutationObserver(function(){
    if (document.getElementById('order-page').classList.contains('active')) refreshMapSize();
  });
  orderPageObserver.observe(document.getElementById('order-page'), {attributes:true, attributeFilter:['class']});
  loadAll().catch(function(err){
    var notice=document.getElementById('data-source-message');
    notice.style.display='block';
    notice.textContent='تعذر تحميل البيانات من PlateBookingDB: '+err.message;
    apiError(err);
  });
})();