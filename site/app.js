/* 4コマ厚労ニュース — 漫画レンダラ
 * episodes/*.json -> data.js (window.EPISODES) をこのファイルが描画する。
 * 画像生成AIは使わず、SVGキャラ（表情差分）＋吹き出しで組み立てる。 */
(function () {
  'use strict';
  const OUT = '#2d2a32';
  const SKIN = '#ffe3cc';
  const CHAR_NAMES = { sensei: 'ヤク先生', mina: 'ミナ' };
  const EXPRS = ['normal', 'smile', 'surprised', 'worried', 'explain', 'serious'];

  const esc = (s) => String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  /* ---------- キャラクター SVG ---------- */
  function arm(x1, y1, cx, cy, x2, y2, color) {
    const d = `M${x1} ${y1} Q${cx} ${cy} ${x2} ${y2}`;
    return `<path d="${d}" stroke="${OUT}" stroke-width="21" fill="none" stroke-linecap="round"/>` +
      `<path d="${d}" stroke="${color}" stroke-width="15" fill="none" stroke-linecap="round"/>` +
      `<circle cx="${x2}" cy="${y2}" r="10" fill="${SKIN}" stroke="${OUT}" stroke-width="3"/>`;
  }

  function face(e, blushAlways) {
    const s = `stroke="${OUT}" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
    const dot = (x) => `<ellipse cx="${x}" cy="108" rx="5" ry="7.5" fill="${OUT}"/><circle cx="${x + 1.8}" cy="104.5" r="1.8" fill="#fff"/>`;
    const blush = `<ellipse cx="63" cy="124" rx="9" ry="5" fill="#ff8f9c" opacity=".45"/><ellipse cx="137" cy="124" rx="9" ry="5" fill="#ff8f9c" opacity=".45"/>`;
    let eyes = dot(78) + dot(122);
    let brows = `<path d="M68 88 Q78 84 88 88" ${s}/><path d="M112 88 Q122 84 132 88" ${s}/>`;
    let mouth = `<path d="M92 132 Q100 139 108 132" ${s}/>`;
    let extra = blushAlways ? blush : '';
    switch (e) {
      case 'smile':
        eyes = `<path d="M70 111 Q78 100 86 111" ${s}/><path d="M114 111 Q122 100 130 111" ${s}/>`;
        mouth = `<path d="M88 127 Q100 147 112 127 Z" fill="#e0565b" stroke="${OUT}" stroke-width="3" stroke-linejoin="round"/>`;
        extra = blush;
        break;
      case 'surprised':
        eyes = [78, 122].map((x) => `<circle cx="${x}" cy="107" r="9" fill="#fff" stroke="${OUT}" stroke-width="3"/><circle cx="${x}" cy="107" r="3.5" fill="${OUT}"/>`).join('');
        brows = `<path d="M67 82 Q78 74 89 82" ${s}/><path d="M111 82 Q122 74 133 82" ${s}/>`;
        mouth = `<ellipse cx="100" cy="136" rx="7" ry="9" fill="#7a2e33" stroke="${OUT}" stroke-width="3"/>`;
        extra += `<path d="M152 42 L168 26 M162 58 L184 50 M140 32 L145 12" stroke="${OUT}" stroke-width="3.5" stroke-linecap="round"/>`;
        break;
      case 'worried':
        brows = `<path d="M68 92 L88 85" ${s}/><path d="M112 85 L132 92" ${s}/>`;
        mouth = `<path d="M90 134 Q95 129 100 134 Q105 139 110 134" ${s}/>`;
        extra += `<path d="M157 74 Q148 90 157 97 Q166 90 157 74 Z" fill="#9fd8ff" stroke="${OUT}" stroke-width="2.5"/>`;
        break;
      case 'explain':
        brows = `<path d="M68 86 Q78 81 88 86" ${s}/><path d="M112 86 Q122 81 132 86" ${s}/>`;
        mouth = `<path d="M89 128 Q100 143 111 128 Z" fill="#e0565b" stroke="${OUT}" stroke-width="3" stroke-linejoin="round"/>`;
        break;
      case 'serious':
        eyes = [78, 122].map((x) => `<ellipse cx="${x}" cy="109" rx="5" ry="6" fill="${OUT}"/>`).join('');
        brows = `<path d="M68 85 L88 91" ${s}/><path d="M112 91 L132 85" ${s}/>`;
        mouth = `<path d="M93 134 L107 134" ${s}/>`;
        break;
      default: break;
    }
    return extra + brows + eyes + mouth;
  }

  function charSVG(id, expr, flip) {
    if (!EXPRS.includes(expr)) expr = 'normal';
    const isS = id === 'sensei';
    const cloth = isS ? '#fbfbfb' : '#f39c5a';
    const hair = isS ? '#2f3542' : '#6b4226';
    let g = '';
    if (!isS) { // ミナの後ろ髪
      g += `<path d="M34 112 Q28 30 100 30 Q172 30 166 112 L166 172 Q150 180 138 160 L62 160 Q50 180 34 172 Z" fill="${hair}" stroke="${OUT}" stroke-width="3"/>`;
    }
    // 胴体
    g += `<path d="M48 302 L56 202 Q60 172 100 166 Q140 172 144 202 L152 302 Z" fill="${cloth}" stroke="${OUT}" stroke-width="3.5" stroke-linejoin="round"/>`;
    if (isS) {
      g += `<path d="M86 170 L100 204 L114 170 Z" fill="#d6efe9" stroke="${OUT}" stroke-width="2.5" stroke-linejoin="round"/>` +
        `<path d="M97 174 L103 174 L105 202 L100 209 L95 202 Z" fill="#1f8a7a" stroke="${OUT}" stroke-width="2"/>` +
        `<path d="M100 209 L100 302" stroke="${OUT}" stroke-width="2.5"/>` +
        `<rect x="112" y="222" width="24" height="15" rx="2" fill="#fff" stroke="${OUT}" stroke-width="2"/>` +
        `<path d="M124 225 v9 M119.5 229.5 h9" stroke="#1f8a7a" stroke-width="2.8"/>` +
        `<path d="M70 230 L70 216 M76 230 L76 212" stroke="#3d7be0" stroke-width="3" stroke-linecap="round"/>` +
        `<rect x="64" y="228" width="20" height="16" rx="2" fill="#fbfbfb" stroke="${OUT}" stroke-width="2"/>`;
    } else {
      g += `<path d="M84 170 L100 188 L116 170 Z" fill="#fff" stroke="${OUT}" stroke-width="2.5" stroke-linejoin="round"/>` +
        `<path d="M100 188 L100 302" stroke="${OUT}" stroke-width="2"/>` +
        `<circle cx="106" cy="218" r="3" fill="${OUT}"/><circle cx="106" cy="244" r="3" fill="${OUT}"/>`;
    }
    // 腕
    g += arm(62, 202, 46, 236, 54, 268, cloth);
    if (expr === 'explain') {
      g += arm(138, 202, 172, 194, 172, 150, cloth) +
        `<path d="M172 140 L172 124" stroke="${OUT}" stroke-width="9" stroke-linecap="round"/>` +
        `<path d="M172 140 L172 124" stroke="${SKIN}" stroke-width="4.5" stroke-linecap="round"/>`;
    } else {
      g += arm(138, 202, 154, 236, 146, 268, cloth);
    }
    // 首・耳・頭
    g += `<rect x="91" y="146" width="18" height="24" fill="${SKIN}" stroke="${OUT}" stroke-width="3"/>` +
      `<circle cx="41" cy="112" r="10" fill="${SKIN}" stroke="${OUT}" stroke-width="3"/>` +
      `<circle cx="159" cy="112" r="10" fill="${SKIN}" stroke="${OUT}" stroke-width="3"/>` +
      `<circle cx="100" cy="100" r="60" fill="${SKIN}" stroke="${OUT}" stroke-width="3.5"/>`;
    g += face(expr, !isS);
    // 前髪
    if (isS) {
      g += `<path d="M40 104 Q36 34 100 33 Q164 34 160 104 Q156 74 140 66 Q120 82 96 70 Q76 84 56 70 Q44 82 40 104 Z" fill="${hair}" stroke="${OUT}" stroke-width="3" stroke-linejoin="round"/>`;
      g += `<circle cx="78" cy="108" r="14" fill="#fff" fill-opacity=".12" stroke="${OUT}" stroke-width="2.8"/>` +
        `<circle cx="122" cy="108" r="14" fill="#fff" fill-opacity=".12" stroke="${OUT}" stroke-width="2.8"/>` +
        `<path d="M92 107 Q100 102 108 107" stroke="${OUT}" stroke-width="2.8" fill="none"/>`;
    } else {
      g += `<path d="M40 104 Q38 36 100 36 Q162 36 160 104 Q150 72 128 62 Q112 80 100 66 Q84 82 64 66 Q48 78 40 104 Z" fill="${hair}" stroke="${OUT}" stroke-width="3" stroke-linejoin="round"/>` +
        `<rect x="128" y="54" width="20" height="9" rx="4" fill="#ffd34d" stroke="${OUT}" stroke-width="2.5" transform="rotate(-20 138 58)"/>`;
    }
    const tr = flip ? ' transform="translate(200 0) scale(-1 1)"' : '';
    return `<svg viewBox="0 0 200 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${esc(CHAR_NAMES[id] || id)}"><g${tr}>${g}</g></svg>`;
  }

  /* ---------- コマ ---------- */
  function panelHTML(p, idx) {
    const chars = p.chars || [];
    const posOf = {};
    chars.forEach((c) => { posOf[c.id] = c.pos; });
    let h = '';
    chars.forEach((c) => {
      h += `<div class="char pos-${esc(c.pos)}">${charSVG(c.id, c.expr, c.pos === 'right')}</div>`;
    });
    if (p.prop) h += `<div class="prop">${esc(p.prop).replace(/\n/g, '<br>')}</div>`;
    const lines = (p.lines || []).filter((l) => l.who !== 'narration');
    lines.forEach((l, i) => {
      let side = posOf[l.who] || (i === 0 ? 'left' : 'right');
      if (side === 'center' && lines.length > 1) side = i === 0 ? 'left' : 'right';
      h += `<div class="bubble side-${side} ${esc(l.style || '')}">${esc(l.text)}</div>`;
    });
    const narr = (p.lines || []).find((l) => l.who === 'narration');
    const cap = p.caption || (narr && narr.text);
    if (cap) h += `<div class="caption">${esc(cap)}</div>`;
    const cls = ['panel', 'bg-' + (p.bg || 'plain')];
    if (p.fx) cls.push('fx-' + p.fx);
    return `<div class="${cls.map(esc).join(' ')}" aria-label="${idx + 1}コマ目">${h}</div>`;
  }

  const fmtDate = (d) => String(d || '').replace(/-/g, '.');

  function comicHTML(ep) {
    const src = ep.source || {};
    return `<div class="comic" id="comic">
      <div class="comic-head"><span class="logo">4コマ厚労ニュース</span><span>${esc(fmtDate(ep.date))}</span></div>
      <h2 class="comic-title">${esc(ep.title)}</h2>
      ${(ep.panels || []).map(panelHTML).join('')}
      <div class="comic-foot">出典：${esc(src.publisher || '')}「${esc(src.title || '')}」（${esc(fmtDate(src.published))}）をもとに作成</div>
    </div>`;
  }

  /* ---------- ページ ---------- */
  const params = new URLSearchParams(location.search);
  const preview = location.protocol === 'file:' || params.has('preview');
  const all = (window.EPISODES || []).concat(preview ? (window.DRAFTS || []) : [])
    .sort((a, b) => (a.date < b.date ? 1 : -1));
  const episodes = all.filter((e) => preview || e.status === 'approved');

  /* ---------- 閲覧数（Googleアナリティクス4） ---------- */
  const gaId = (window.SITE_CONFIG || {}).gaMeasurementId;
  const gaOn = !!gaId && location.protocol.startsWith('http') && !params.has('preview');
  if (gaOn) {
    const s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(gaId);
    document.head.appendChild(s);
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag('js', new Date());
    window.gtag('config', gaId, { send_page_view: false });
  }
  let lastTracked = null;
  function trackView(ep) {
    if (!gaOn || lastTracked === ep.date) return;
    lastTracked = ep.date;
    window.gtag('event', 'page_view', {
      page_title: ep.title,
      page_location: location.origin + location.pathname + '?ep=' + ep.date,
      episode_date: ep.date,
      episode_tag: ep.tag || ''
    });
  }

  function render() {
    const main = document.getElementById('main');
    if (!episodes.length) { main.innerHTML = '<p class="empty">まだ公開された回はありません。</p>'; return; }
    const id = decodeURIComponent(location.hash.slice(1)) || params.get('ep') || '';
    const ep = episodes.find((e) => e.date === id) || episodes[0];
    const src = ep.source || {};
    let h = '';
    if (ep.status !== 'approved') {
      h += `<div class="draft-banner"><strong>確認待ちの下書き</strong>です。下の「根拠チェック」を出典と照らし合わせ、問題なければ <code>scripts\\approve.ps1 ${esc(ep.date)}</code> で公開扱いにしてください。</div>`;
    }
    h += `<article class="episode">
      <div class="ep-meta"><span class="tag">${esc(ep.tag || 'ニュース')}</span><time>${esc(fmtDate(ep.date))}</time></div>
      ${comicHTML(ep)}
      <div class="actions">
        <button type="button" id="save">画像で保存</button>
        ${location.protocol.startsWith('http') ? `<a class="btn" target="_blank" rel="noopener" href="https://twitter.com/intent/tweet?text=${encodeURIComponent('【4コマ厚労ニュース】' + ep.title)}&url=${encodeURIComponent(location.href)}">Xでシェア</a>` : ''}
      </div>
      <section class="notes">
        <h3>ヤク先生のまとめ</h3>
        <ul>${(ep.summary || []).map((s) => `<li>${esc(s)}</li>`).join('')}</ul>
        ${ep.comment ? `<p class="comment"><span class="who">ヤク先生のひとこと</span>${esc(ep.comment)}</p>` : ''}
        <p class="source">出典：<a href="${esc(src.url)}" target="_blank" rel="noopener">${esc(src.publisher)}「${esc(src.title)}」</a>（${esc(fmtDate(src.published))}）</p>
      </section>`;
    if (ep.status !== 'approved' && ep.checks && ep.checks.length) {
      h += `<section class="checks"><h3>根拠チェック（公開前に確認）</h3><table><thead><tr><th>漫画・まとめでの主張</th><th>出典の該当箇所</th></tr></thead><tbody>` +
        ep.checks.map((c) => `<tr><td>${esc(c.claim)}</td><td>${esc(c.quote)}</td></tr>`).join('') + '</tbody></table></section>';
    }
    h += '</article>';
    h += `<section class="archive"><h3>バックナンバー</h3><ul>` +
      episodes.map((e) => `<li${e === ep ? ' class="current"' : ''}><a href="#${esc(e.date)}"><time>${esc(fmtDate(e.date))}</time><span>${esc(e.title)}</span>${e.status !== 'approved' ? '<em>下書き</em>' : ''}</a></li>`).join('') +
      '</ul></section>';
    main.innerHTML = h;
    document.title = ep.title + '｜4コマ厚労ニュース';
    trackView(ep);
    document.getElementById('save').addEventListener('click', () => {
      saveImage(ep);
      if (gaOn) window.gtag('event', 'save_image', { episode_date: ep.date });
    });
    window.scrollTo(0, 0);
  }

  function saveImage(ep) {
    const btn = document.getElementById('save');
    if (typeof html2canvas !== 'function') { alert('画像化ライブラリを読み込めませんでした（オフライン？）'); return; }
    btn.disabled = true; btn.textContent = '作成中…';
    html2canvas(document.getElementById('comic'), { scale: 2, backgroundColor: '#ffffff', useCORS: true })
      .then((canvas) => {
        const a = document.createElement('a');
        a.download = `4koma_${ep.date}.png`;
        a.href = canvas.toDataURL('image/png');
        a.click();
      })
      .catch((err) => alert('画像の作成に失敗しました: ' + err))
      .finally(() => { btn.disabled = false; btn.textContent = '画像で保存'; });
  }

  window.addEventListener('hashchange', render);
  render();
})();
