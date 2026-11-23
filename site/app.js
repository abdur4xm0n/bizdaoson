/* bizdaoson.uz — dasturlarni tanlash va buyruq yaratish */
(() => {
  'use strict';

  // ===== Sozlamalar =====
  const ALOQA = {
    telegram: 'https://t.me/isroilovxk',
    github: 'https://github.com/abdur4xm0n/bizdaoson'
  };
  const DOMEN = 'bizdaoson.uz';

  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));

  // ---------- Aloqa havolalari ----------
  $$('[data-aloqa]').forEach((a) => {
    const url = ALOQA[a.dataset.aloqa];
    if (!url) return;
    a.href = url;
    a.target = '_blank';
    a.rel = 'noopener';
  });

  // ---------- Nusxalash va xabar ----------
  let toastTimer;
  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove('show'), 2800);
  }

  async function copy(text, msg, btn) {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
    }
    toast(msg || 'Nusxalandi! Endi PowerShell oynasiga joylang.');
    if (btn) {
      const eski = btn.textContent;
      btn.textContent = 'Nusxalandi ✓';
      btn.classList.add('is-done');
      setTimeout(() => { btn.textContent = eski; btn.classList.remove('is-done'); }, 1800);
    }
  }

  $$('.cmd[data-cmd] .cmd__copy').forEach((b) => {
    b.addEventListener('click', () => copy(b.closest('.cmd').dataset.cmd, null, b));
  });

  // ---------- Dasturlar katalogi ----------
  const holat = { apps: [], cats: [], presets: [], tanlov: new Set(), kat: 'all', q: '' };

  const rang = (id) => {
    let h = 0;
    for (const c of id) h = (h * 31 + c.charCodeAt(0)) % 360;
    return h;
  };
  const bosh = (name) => name.replace(/[^A-Za-z0-9 ]/g, ' ').trim().split(/\s+/)
    .slice(0, 2).map((w) => w[0]).join('').toUpperCase();

  function buyruq() {
    return `&([scriptblock]::Create((irm ${DOMEN}/win))) -Dasturlar "${[...holat.tanlov].join(',')}"`;
  }

  function renderPresets() {
    $('#presets').innerHTML = holat.presets.map((p) =>
      `<button type="button" class="chip" data-preset="${esc(p.id)}" title="${esc(p.desc || '')}">${esc(p.name)}<small>${p.apps.length}</small></button>`
    ).join('');
  }

  function renderTabs() {
    const tabs = [{ id: 'all', name: 'Hammasi' }, ...holat.cats];
    $('#tabs').innerHTML = tabs.map((t) =>
      `<button type="button" role="tab" aria-selected="${t.id === holat.kat}" class="tab${t.id === holat.kat ? ' is-on' : ''}" data-kat="${esc(t.id)}">${esc(t.name)}</button>`
    ).join('');
  }

  function renderApps() {
    const q = holat.q.trim().toLowerCase();
    const list = holat.apps.filter((a) =>
      (holat.kat === 'all' || a.cat === holat.kat) &&
      (!q || `${a.name} ${a.desc} ${a.id}`.toLowerCase().includes(q))
    );
    if (!list.length) {
      $('#apps').innerHTML = '<p class="empty">Hech narsa topilmadi.</p>';
      return;
    }
    $('#apps').innerHTML = list.map((a) => {
      const on = holat.tanlov.has(a.id);
      return `<label class="app${on ? ' is-on' : ''}">
        <input type="checkbox" value="${esc(a.id)}"${on ? ' checked' : ''}>
        <span class="app__ico" style="--h:${rang(a.id)}" aria-hidden="true">${esc(bosh(a.name))}</span>
        <span class="app__txt"><b>${esc(a.name)}</b><small>${esc(a.desc)}</small></span>
        <span class="app__tick" aria-hidden="true"></span>
      </label>`;
    }).join('');
  }

  function updateTray() {
    const n = holat.tanlov.size;
    $('#tray').classList.toggle('show', n > 0);
    document.body.classList.toggle('has-tray', n > 0);
    $('#tray-count').textContent = n;
    $('#tray-cmd').textContent = n ? buyruq() : '';

    // Tanlovni manzilda saqlash: havolani mijozga yuborish mumkin
    const url = new URL(location.href);
    if (n) url.searchParams.set('d', [...holat.tanlov].join(','));
    else url.searchParams.delete('d');
    history.replaceState(null, '', url);

    $$('.chip').forEach((c) => {
      const p = holat.presets.find((x) => x.id === c.dataset.preset);
      const on = !!p && p.apps.length === n && p.apps.every((id) => holat.tanlov.has(id));
      c.classList.toggle('is-on', on);
    });
  }

  // ---------- Hodisalar ----------
  $('#presets').addEventListener('click', (e) => {
    const b = e.target.closest('[data-preset]');
    if (!b) return;
    const p = holat.presets.find((x) => x.id === b.dataset.preset);
    if (!p) return;
    holat.tanlov = new Set(p.apps);
    renderApps();
    updateTray();
    toast(`"${p.name}" tanlandi — ${p.apps.length} ta dastur`);
  });

  $('#tabs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-kat]');
    if (!b) return;
    holat.kat = b.dataset.kat;
    renderTabs();
    renderApps();
  });

  $('#qidiruv').addEventListener('input', (e) => {
    holat.q = e.target.value;
    renderApps();
  });

  $('#apps').addEventListener('change', (e) => {
    const cb = e.target;
    if (cb.type !== 'checkbox') return;
    if (cb.checked) holat.tanlov.add(cb.value);
    else holat.tanlov.delete(cb.value);
    cb.closest('.app').classList.toggle('is-on', cb.checked);
    updateTray();
  });

  $('#tray-copy').addEventListener('click', (e) => copy(buyruq(), null, e.currentTarget));
  $('#tray-share').addEventListener('click', () => {
    const u = new URL(location.href);
    u.hash = 'dasturlar';
    copy(u.toString(), 'Havola nusxalandi — uni mijozga yuborishingiz mumkin.');
  });
  $('#tray-clear').addEventListener('click', () => {
    holat.tanlov.clear();
    renderApps();
    updateTray();
  });

  // ---------- Yuklash ----------
  fetch('apps.json', { cache: 'no-cache' })
    .then((r) => { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then((data) => {
      holat.apps = data.apps || [];
      holat.cats = (data.categories || []).filter((c) => holat.apps.some((a) => a.cat === c.id));
      holat.presets = data.presets || [];
      const d = new URLSearchParams(location.search).get('d');
      if (d) {
        d.split(',').forEach((id) => {
          if (holat.apps.some((a) => a.id === id)) holat.tanlov.add(id);
        });
      }
      const soni = $('#app-soni');
      if (soni) soni.textContent = holat.apps.length;
      renderPresets();
      renderTabs();
      renderApps();
      updateTray();
    })
    .catch(() => {
      $('#apps').innerHTML = '<p class="empty">Ro\'yxatni yuklab bo\'lmadi. Sahifani yangilang.</p>';
    });
})();
