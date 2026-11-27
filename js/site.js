/* New Era Public School, Dwarka: site behaviour. No libraries. */
(function () {
  'use strict';
  /* Show the hidden draft slots when the address has ?drafts=1 */
  try { if (/[?&]drafts=1/.test(location.search)) document.documentElement.classList.add('show-drafts'); } catch (e) {}
  var SITE = {
    whatsapp: '919870552633',
    // Set this to the Edunext enquiry endpoint or a Google Sheet web app URL.
    // While it is empty, forms hand the details to WhatsApp and nothing is stored.
    leadEndpoint: ''
  };
  var $ = function (s, c) { return (c || document).querySelector(s); };
  var $$ = function (s, c) { return Array.prototype.slice.call((c || document).querySelectorAll(s)); };

  window.dataLayer = window.dataLayer || [];
  function track(event, detail) {
    window.dataLayer.push(Object.assign({ event: event }, detail || {}));
  }
  function waLink(text) {
    return 'https://wa.me/' + SITE.whatsapp + '?text=' + encodeURIComponent(text);
  }

  /* Mobile menu */
  var menu = $('#mmenu');
  $$('[data-menu]').forEach(function (b) {
    b.addEventListener('click', function () {
      var open = b.dataset.menu === 'open';
      menu.classList.toggle('open', open);
      document.body.style.overflow = open ? 'hidden' : '';
    });
  });
  $$('#mmenu a').forEach(function (a) {
    a.addEventListener('click', function () {
      menu.classList.remove('open');
      document.body.style.overflow = '';
    });
  });

  /* Hero crossfade */
  var slides = $$('.hero-media img');
  if (slides.length > 1 && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    var i = 0;
    setInterval(function () {
      slides[i].classList.remove('on');
      i = (i + 1) % slides.length;
      slides[i].classList.add('on');
    }, 6000);
  }

  /* Admissions tabs: keep the current page in view on phones */
  var here = $('.anav a[aria-current]');
  if (here) here.parentNode.scrollLeft = here.offsetLeft - here.parentNode.offsetLeft - 16;

  /* Reveal on scroll */
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { rootMargin: '0px 0px -6% 0px' });
    $$('.rv').forEach(function (el) { io.observe(el); });
  } else {
    $$('.rv').forEach(function (el) { el.classList.add('in'); });
  }

  /* Enquiry / visit dialog */
  var dlg = $('#enquire');
  $$('[data-open]').forEach(function (b) {
    b.addEventListener('click', function () {
      if (!dlg) return;
      var visit = b.dataset.open === 'visit';
      dlg.classList.toggle('visit', visit);
      $('[data-formbox]', dlg).classList.remove('sent');
      $('#dlg-title').textContent = visit ? 'Book a campus visit' : 'Talk to our admission team';
      $('#dlg-sub').textContent = visit ? 'Pick a day and a slot. We will confirm on WhatsApp.' : 'Three quick details and we will call you back.';
      $('input[name=date]', dlg).required = visit;
      dlg.querySelector('form').dataset.kind = visit ? 'visit' : 'enquiry';
      dlg.showModal();
    });
  });
  $$('[data-close]').forEach(function (b) {
    b.addEventListener('click', function () { dlg.close(); });
  });
  if (dlg) {
    dlg.addEventListener('click', function (e) { if (e.target === dlg) dlg.close(); });
  }
  /* Visit dates start tomorrow */
  var tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1);
  $$('input[name=date]').forEach(function (d) { d.min = tomorrow.toISOString().slice(0, 10); });

  /* Lead forms */
  $$('form[data-lead]').forEach(function (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var err = $('.err', form), f = new FormData(form);
      var name = String(f.get('name') || '').trim();
      var phone = String(f.get('phone') || '').replace(/\D/g, '').replace(/^(91|0)(?=\d{10}$)/, '');
      var cls = String(f.get('class') || '');
      err.textContent = '';
      if (name.length < 2) { err.textContent = 'Please enter your name.'; return; }
      if (!/^[6-9]\d{9}$/.test(phone)) { err.textContent = 'Please enter a 10-digit mobile number.'; return; }
      if (!cls) { err.textContent = 'Please choose a class.'; return; }
      var kind = form.dataset.kind || 'enquiry';
      var msg = 'Hi, I am ' + name + ' (' + phone + '). ';
      msg += kind === 'visit'
        ? 'I would like to book a campus visit for ' + cls + ' on ' + f.get('date') + ', ' + f.get('slot') + '.'
        : 'I want admission details for ' + cls + ' (2027-28).';
      if (SITE.leadEndpoint) {
        fetch(SITE.leadEndpoint, { method: 'POST', mode: 'no-cors', body: f }).catch(function () {});
      }
      track('generate_lead', { lead_type: kind, class_sought: cls, form_location: form.dataset.lead });
      var box = form.closest('[data-formbox]');
      var link = $('.ok a', box);
      if (link) link.href = waLink(msg);
      box.classList.add('sent');
      window.open(waLink(msg), '_blank', 'noopener');
    });
  });

  /* Age calculator: completed years on 31 March 2027 */
  var calc = $('#calc');
  if (calc) {
    var CUTOFF = new Date(2027, 2, 31);
    calc.addEventListener('submit', function (e) {
      e.preventDefault();
      var v = calc.dob.value, out = $('#calc-out');
      if (!v) return;
      var p = v.split('-').map(Number);
      var age = CUTOFF.getFullYear() - p[0];
      if (CUTOFF.getMonth() + 1 < p[1] || (CUTOFF.getMonth() + 1 === p[1] && CUTOFF.getDate() < p[2])) age--;
      var res;
      if (age < 3) res = [age === 2 && p[1] === 4 ? 'Just under the Nursery age' : 'Not eligible for 2027-28 yet', 'Your child will be under 3 on 31 March 2027. Talk to us about the next session.', 'the next session'];
      else if (age === 3) res = ['Nursery', 'Your child will be 3+ on 31 March 2027.'];
      else if (age === 4) res = ['Lower KG', 'Your child will be 4+ on 31 March 2027.'];
      else if (age === 5) res = ['Upper KG', 'Your child will be 5+ on 31 March 2027. If your child is in KG at a recognised school in 2026-27, the next step is Class I.'];
      else res = ['Our team will confirm the class', 'Your child will be ' + age + '+ on 31 March 2027. From Class I upwards, the class depends on the last class passed at a recognised school.', 'Class I or above'];
      // The DoE lets the Head of School relax the age by one month either side of the cut-off.
      var note = age >= 2 && age <= 5 && (p[1] === 3 || p[1] === 4) ? ' This birthday is close to the cut-off, and the Head of School can allow up to one month of relaxation, so please ask us.' : '';
      $('b', out).textContent = res[0];
      $('span', out).textContent = res[1] + note;
      $('a', out).href = waLink('Hi, my child was born on ' + v + '. Please share admission details for ' + (res[2] || res[0]) + ' (2027-28).');
      out.classList.add('show');
      track('age_calculator_used', { result: res[0] });
    });
  }

  /* Fee finder: reads the fee table, so the numbers live in one place */
  var feeSel = $('#fee-class'), feeTable = $('#fee-table');
  if (feeSel && feeTable) {
    var feeRows = $$('tbody tr', feeTable);
    var feeHead = $$('thead th', feeTable).map(function (th) { return th.textContent; });
    feeRows.forEach(function (r, n) {
      var o = document.createElement('option');
      o.value = n; o.textContent = $('th', r).textContent;
      feeSel.appendChild(o);
    });
    // Columns: monthly total, due at admission (monthly plan), due at admission (quarterly plan), then the breakdown
    var plan = 'monthly', plans = $$('[data-plan]');
    var showFee = function () {
      var c = $$('td', feeRows[feeSel.value]).map(function (td) { return td.textContent; });
      var q = plan === 'quarterly';
      $('#fee-month').textContent = '₹' + c[0];
      $('#fee-due').textContent = '₹' + (q ? c[2] : c[1]);
      $('#fee-due-label').textContent = q ? 'Quarterly admission fee' : 'Due at admission';
      $('#fee-note').textContent = q ? 'As shown in the school\'s quarterly fee plan for 2026-27.' : 'One-time admission fee of ₹7,196 plus the first month\'s fee.';
      $('#fee-rows').innerHTML = c.slice(3).map(function (v, n) {
        return v === '0' ? '' : '<div><dt>' + feeHead[n + 4] + '</dt><dd>₹' + v + '</dd></div>';
      }).join('');
    };
    plans.forEach(function (b) {
      b.addEventListener('click', function () {
        plan = b.dataset.plan;
        plans.forEach(function (x) { x.setAttribute('aria-pressed', x === b); });
        showFee();
      });
    });
    feeSel.addEventListener('change', showFee);
    showFee();
  }

  /* Admission list PDF slots: live once data-pdf is set */
  $$('.pdf-slot').forEach(function (a) {
    var f = a.getAttribute('data-pdf');
    if (f) { a.href = f; a.setAttribute('download', ''); }
    else { a.removeAttribute('href'); a.setAttribute('aria-disabled', 'true'); a.textContent = 'PDF will be uploaded here'; }
  });

  /* Instagram reels: load the embeds only when the section comes near the screen */
  var igFrames = $$('.ig-item iframe[data-src]');
  if (igFrames.length) {
    var loadIg = function () { igFrames.forEach(function (f) { if (!f.src) f.src = f.getAttribute('data-src'); }); };
    if ('IntersectionObserver' in window) {
      var igObs = new IntersectionObserver(function (es) { if (es.some(function (e) { return e.isIntersecting; })) { loadIg(); igObs.disconnect(); } }, { rootMargin: '400px 0px' });
      igObs.observe(igFrames[0].closest('.ig-rail'));
    } else { loadIg(); }
  }

  /* Parent videos: load and play on tap; only one plays at a time */
  $$('.pv').forEach(function (card) {
    var btn = $('.pv-play', card);
    if (!btn) return;
    btn.addEventListener('click', function () {
      $$('.pv video').forEach(function (other) { other.pause(); });
      var v = $('video', card);
      if (!v) {
        v = document.createElement('video');
        v.src = card.getAttribute('data-src'); v.controls = true; v.playsInline = true; v.preload = 'auto';
        v.setAttribute('playsinline', '');
        var img = $('img', card); if (img) v.poster = img.currentSrc || img.src;
        card.insertBefore(v, btn);
      }
      card.classList.add('is-playing');
      var p = v.play(); if (p && p.catch) p.catch(function () {});
      track('parent_video_play');
    });
  });

  /* Print a checklist */
  $$('[data-print]').forEach(function (b) {
    b.addEventListener('click', function () { window.print(); });
  });

  /* Parent video cards: show the YouTube thumbnail, load the player only on tap */
  $$('.vt').forEach(function (card) {
    var id = card.dataset.yt;
    if (!id) { card.setAttribute('aria-disabled', 'true'); card.setAttribute('aria-label', card.dataset.label + ', recording pending'); return; }
    card.classList.add('has-video');
    card.setAttribute('aria-label', 'Play the ' + card.dataset.label);
    card.style.backgroundImage = 'url(https://i.ytimg.com/vi/' + encodeURIComponent(id) + '/hqdefault.jpg)';
    var pending = $('.vt-pending', card); if (pending) pending.remove();
    card.addEventListener('click', function () {
      if ($('iframe', card)) return;
      var f = document.createElement('iframe');
      f.src = 'https://www.youtube-nocookie.com/embed/' + encodeURIComponent(id) + '?autoplay=1&rel=0';
      f.title = card.dataset.label;
      f.allow = 'autoplay; encrypted-media; picture-in-picture';
      f.allowFullscreen = true;
      card.appendChild(f);
      track('testimonial_play', { video: card.dataset.label });
    });
  });

  /* Virtual tour: the photo shows first. When the box scrolls into view the video loads and
     plays silently on a loop over it. "Watch with sound" restarts it with sound and controls.
     People who ask for reduced motion or data saving get the photo and a play button instead. */
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var saveData = navigator.connection && navigator.connection.saveData;
  function tourVideo(box) {
    var v = $('video', box);
    if (!v) {
      v = document.createElement('video');
      v.muted = true; v.loop = true; v.playsInline = true; v.preload = 'auto';
      v.setAttribute('muted', ''); v.setAttribute('playsinline', '');
      v.setAttribute('aria-label', 'Campus tour video');
      v.addEventListener('playing', function () {
        box.classList.add('is-playing');
        var l = $('.tour-lbl', box); if (l && v.muted) l.textContent = 'Watch with sound';
      });
      v.src = box.dataset.src;
      box.insertBefore(v, $('button', box));
    }
    return v;
  }
  function tryPlay(v) { var p = v.play(); if (p && p.catch) p.catch(function () {}); }
  if (!reduceMotion && !saveData && 'IntersectionObserver' in window) {
    $$('.tour[data-src]').forEach(function (box) {
      new IntersectionObserver(function (es) {
        es.forEach(function (en) {
          var v = $('video', box);
          if (en.isIntersecting) { v = tourVideo(box); if (v.muted) tryPlay(v); }
          else if (v && v.muted) v.pause();
        });
      }, { threshold: 0.35 }).observe(box);
    });
  }
  function playTour(e) {
    var box = (e && e.currentTarget && e.currentTarget.closest('.tour')) || $('.tour[data-src]');
    if (!box) return;
    box.scrollIntoView({ block: 'center' });
    var v = tourVideo(box);
    v.muted = false; v.loop = false; v.controls = true; v.currentTime = 0;
    tryPlay(v);
    box.classList.add('is-playing', 'has-sound');
    track('tour_play');
  }
  $$('[data-tour]').forEach(function (b) { b.addEventListener('click', playTour); });

  /* Click tracking */
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a');
    if (!a) return;
    if (/wa\.me/.test(a.href)) track('whatsapp_click', { link_location: a.dataset.loc || 'page' });
    if (/^tel:/.test(a.href)) track('call_click', { link_location: a.dataset.loc || 'page' });
  });

  /* Blog: category chips and search */
  var chips = $$('.chip'), cards = $$('[data-cat]'), q = $('#q'), none = $('#none');
  if (chips.length) {
    var cat = 'all';
    var apply = function () {
      var term = (q && q.value || '').trim().toLowerCase(), shown = 0;
      cards.forEach(function (c) {
        var ok = (cat === 'all' || c.dataset.cat === cat) && c.textContent.toLowerCase().indexOf(term) > -1;
        c.style.display = ok ? '' : 'none';
        if (ok) { shown++; c.classList.add('in'); }
      });
      if (none) none.style.display = shown ? 'none' : 'block';
    };
    chips.forEach(function (c) {
      c.addEventListener('click', function () {
        chips.forEach(function (x) { x.setAttribute('aria-pressed', x === c); });
        cat = c.dataset.filter; apply();
      });
    });
    if (q) q.addEventListener('input', apply);
  }

  /* Article reading progress */
  var bar = $('.progress');
  if (bar) {
    addEventListener('scroll', function () {
      var h = document.documentElement;
      bar.style.width = (h.scrollTop / (h.scrollHeight - h.clientHeight) * 100) + '%';
    }, { passive: true });
  }
})();
