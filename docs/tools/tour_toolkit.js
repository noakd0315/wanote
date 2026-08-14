// wanote screenshot-tour toolkit.
//
// Re-inject this after EVERY page load (window state is lost on reload).
// Wrap it in an async IIFE when pasting into javascript_tool.
//
// Why it works this way:
//  - Coordinate clicking via the browser tool is broken against this app
//    (flt-glass-pane reports a 0x0 box), and synthetic PointerEvents on
//    <flutter-view> never reach Flutter's gesture arena.
//  - Enabling Flutter's accessibility tree gives a real DOM mirror of the
//    UI; clicking an flt-semantics node with role=button uses the same
//    activation path a screen reader would, and that DOES reach onTap.
//  - Text fields must be typed with REAL key events. Flutter owns the
//    <input> and rewrites any value assigned from JS, so the helper only
//    focuses/selects the field and the caller then sends keystrokes.
(() => {
  const T = {};
  T.log = [];
  T.sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  T.nodes = () => [...document.querySelectorAll('flt-semantics')];

  T.leaves = () =>
    T.nodes()
      .filter((n) => n.getAttribute('role') === 'button' || n.childElementCount === 0)
      .map((n) => ({ role: n.getAttribute('role'), label: (n.textContent || '').trim() }))
      .filter((x) => x.label);

  T.texts = () =>
    T.nodes()
      .filter((n) => n.childElementCount === 0)
      .map((n) => (n.textContent || '').trim())
      .filter(Boolean);

  T.tap = async (text, wait) => {
    const exact = T.nodes().find(
      (n) => n.getAttribute('role') === 'button' && (n.textContent || '').trim() === text,
    );
    const el =
      exact ||
      T.nodes().find(
        (n) => n.getAttribute('role') === 'button' && (n.textContent || '').trim().includes(text),
      );
    if (!el) {
      T.log.push('MISS tap: ' + text);
      return false;
    }
    el.click();
    await T.sleep(wait || 900);
    T.log.push('tap: ' + text);
    return true;
  };

  // Tabs, list rows and other non-button targets.
  T.tapAny = async (text, wait) => {
    if (await T.tap(text, wait)) return true;
    const el =
      T.nodes().find((n) => n.childElementCount === 0 && (n.textContent || '').trim() === text) ||
      T.nodes().find((n) => (n.textContent || '').trim() === text);
    if (!el) {
      T.log.push('MISS tapAny: ' + text);
      return false;
    }
    el.click();
    await T.sleep(wait || 900);
    T.log.push('tapAny: ' + text);
    return true;
  };

  // Semantics nodes whose DIRECT child is the text input.
  T.fields = () =>
    T.nodes().filter((n) => {
      const c = n.firstElementChild;
      return c && (c.tagName === 'INPUT' || c.tagName === 'TEXTAREA');
    });

  /// Focus field [i] and select its contents, ready for real keystrokes from
  /// the caller. Returns the field's label so the caller can assert it hit
  /// the right one.
  T.focusField = async (i) => {
    const wrap = T.fields()[i];
    if (!wrap) {
      T.log.push('MISS field#' + i);
      return null;
    }
    wrap.click();
    await T.sleep(600);
    const input = wrap.firstElementChild;
    input.focus();
    if (input.select) input.select();
    await T.sleep(250);
    return input.getAttribute('aria-label');
  };

  T.fieldValues = () =>
    T.fields().map((f) => ({
      label: f.firstElementChild.getAttribute('aria-label'),
      value: f.firstElementChild.value,
    }));

  T.shot = async (name) => {
    const pane = document.querySelector('flt-glass-pane');
    const canvas =
      pane && pane.shadowRoot
        ? pane.shadowRoot.querySelector('canvas')
        : document.querySelector('canvas');
    const dataUrl = canvas.toDataURL('image/png');
    const blob = await (await fetch(dataUrl)).blob();
    const resp = await fetch('http://localhost:5050/save?name=' + encodeURIComponent(name), {
      method: 'POST',
      body: blob,
    });
    T.log.push(`shot ${name} ${canvas.width}x${canvas.height} -> ${resp.status}`);
    return resp.status;
  };

  T.boot = async () => {
    await T.sleep(2500);
    document
      .querySelectorAll('.firebase-emulator-warning')
      .forEach((e) => (e.style.pointerEvents = 'none'));
    const ph = document.querySelector('flt-semantics-placeholder');
    if (ph) {
      const r = ph.getBoundingClientRect();
      ['pointerdown', 'pointerup', 'click'].forEach((type) => {
        const Ctor = type === 'click' ? MouseEvent : PointerEvent;
        ph.dispatchEvent(
          new Ctor(type, {
            bubbles: true,
            cancelable: true,
            composed: true,
            clientX: r.left + r.width / 2,
            clientY: r.top + r.height / 2,
            button: 0,
          }),
        );
      });
    }
    await T.sleep(1500);
    return T.nodes().length;
  };

  window.__tour = T;
  return 'toolkit ready';
})();
