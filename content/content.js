// Content script injected into labs.google/fx/tools/flow
// Handles DOM interaction via element descriptors and mouse simulation.

(() => {
  'use strict';

  // ---- Cached picked element descriptors ----
  let pickedElements = {};

  async function loadPickedElements() {
    if (typeof Storage !== 'undefined' && Storage.getPickedElements) {
      pickedElements = await Storage.getPickedElements();
    }
  }
  loadPickedElements();

  // ============================================================
  // A. Element Picker System
  // ============================================================

  let pickerActive = false;
  let pickerRole = null;
  let pickerOverlay = null;
  let pickerLabel = null;
  let pickerHighlighted = null;

  function startPicker(role) {
    if (pickerActive) stopPicker();
    pickerRole = role;
    pickerActive = true;

    // Create overlay container (fixed, covers entire viewport, pointer-events none)
    pickerOverlay = document.createElement('div');
    pickerOverlay.id = 'veo3-picker-overlay';
    Object.assign(pickerOverlay.style, {
      position: 'fixed', top: '0', left: '0', width: '100vw', height: '100vh',
      zIndex: '2147483647', pointerEvents: 'none',
    });

    // Floating label
    pickerLabel = document.createElement('div');
    pickerLabel.id = 'veo3-picker-label';
    Object.assign(pickerLabel.style, {
      position: 'fixed', top: '8px', left: '50%', transform: 'translateX(-50%)',
      background: '#1a73e8', color: '#fff', padding: '8px 16px', borderRadius: '8px',
      fontSize: '13px', fontWeight: '600', zIndex: '2147483647', pointerEvents: 'none',
      fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
      boxShadow: '0 2px 12px rgba(0,0,0,0.3)',
    });
    pickerLabel.textContent = `Click an element to pick: ${role}  (Esc to cancel)`;

    document.body.appendChild(pickerOverlay);
    document.body.appendChild(pickerLabel);

    document.addEventListener('mousemove', onPickerMouseMove, true);
    document.addEventListener('click', onPickerClick, true);
    document.addEventListener('keydown', onPickerKeyDown, true);

    return { success: true };
  }

  function onPickerMouseMove(e) {
    const el = document.elementFromPoint(e.clientX, e.clientY);
    if (!el || el === pickerOverlay || el === pickerLabel) return;

    // Remove previous highlight
    if (pickerHighlighted && pickerHighlighted !== el) {
      pickerHighlighted.style.outline = pickerHighlighted._veo3PrevOutline || '';
      delete pickerHighlighted._veo3PrevOutline;
    }

    if (el !== pickerHighlighted) {
      el._veo3PrevOutline = el.style.outline;
      el.style.outline = '3px solid #1a73e8';
      pickerHighlighted = el;
    }

    // Update label with element info
    const tag = el.tagName.toLowerCase();
    const text = (el.textContent || '').trim().slice(0, 40);
    const aria = el.getAttribute('aria-label') || '';
    let info = tag;
    if (aria) info += ` [${aria}]`;
    else if (text) info += ` "${text}"`;
    pickerLabel.textContent = `Pick ${pickerRole}: ${info}  (Esc to cancel)`;
  }

  function onPickerClick(e) {
    e.preventDefault();
    e.stopImmediatePropagation();

    const el = document.elementFromPoint(e.clientX, e.clientY);
    if (!el || el === pickerOverlay || el === pickerLabel) return;

    const descriptor = buildElementDescriptor(el);
    const role = pickerRole;

    stopPicker();

    // Send to background for storage
    chrome.runtime.sendMessage({
      type: 'elementPicked',
      payload: { role, descriptor },
    });
  }

  function onPickerKeyDown(e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopImmediatePropagation();
      stopPicker();
      chrome.runtime.sendMessage({ type: 'pickerCancelled' });
    }
  }

  function stopPicker() {
    pickerActive = false;
    pickerRole = null;

    if (pickerHighlighted) {
      pickerHighlighted.style.outline = pickerHighlighted._veo3PrevOutline || '';
      delete pickerHighlighted._veo3PrevOutline;
      pickerHighlighted = null;
    }

    document.removeEventListener('mousemove', onPickerMouseMove, true);
    document.removeEventListener('click', onPickerClick, true);
    document.removeEventListener('keydown', onPickerKeyDown, true);

    pickerOverlay?.remove();
    pickerLabel?.remove();
    pickerOverlay = null;
    pickerLabel = null;

    return { success: true };
  }

  // ============================================================
  // B. Robust Element Identification
  // ============================================================

  function buildElementDescriptor(el) {
    const descriptor = {
      tagName: el.tagName.toLowerCase(),
      textContent: (el.textContent || '').trim().slice(0, 80),
      ariaLabel: el.getAttribute('aria-label') || '',
      role: el.getAttribute('role') || '',
      placeholder: el.getAttribute('placeholder') || '',
      type: el.getAttribute('type') || '',
      dataAttributes: {},
      nthChildPath: buildNthChildPath(el),
      displayLabel: '',
    };

    // Collect data-* attributes
    for (const attr of el.attributes) {
      if (attr.name.startsWith('data-')) {
        descriptor.dataAttributes[attr.name] = attr.value;
      }
    }

    // Build a human-readable display label
    const tag = descriptor.tagName;
    if (descriptor.ariaLabel) {
      descriptor.displayLabel = `${tag} [${descriptor.ariaLabel}]`;
    } else if (descriptor.placeholder) {
      descriptor.displayLabel = `${tag} (${descriptor.placeholder})`;
    } else if (descriptor.textContent) {
      descriptor.displayLabel = `${tag} "${descriptor.textContent.slice(0, 30)}"`;
    } else {
      descriptor.displayLabel = tag;
    }

    return descriptor;
  }

  function buildNthChildPath(el) {
    const path = [];
    let current = el;
    while (current && current !== document.body && path.length < 10) {
      const parent = current.parentElement;
      if (!parent) break;
      const siblings = Array.from(parent.children);
      const index = siblings.indexOf(current);
      path.unshift({ tag: current.tagName.toLowerCase(), index });
      current = parent;
    }
    return path;
  }

  function findByDescriptor(descriptor) {
    if (!descriptor) return null;

    const candidates = [];

    // Strategy 1: aria-label match (score 10)
    if (descriptor.ariaLabel) {
      const els = document.querySelectorAll(`[aria-label]`);
      for (const el of els) {
        if (el.getAttribute('aria-label') === descriptor.ariaLabel) {
          candidates.push({ el, score: 10 });
        } else if (el.getAttribute('aria-label').toLowerCase().includes(descriptor.ariaLabel.toLowerCase())) {
          candidates.push({ el, score: 8 });
        }
      }
    }

    // Strategy 2: role + text match (score 8)
    if (descriptor.role && descriptor.textContent) {
      const els = document.querySelectorAll(`[role="${descriptor.role}"]`);
      for (const el of els) {
        const text = (el.textContent || '').trim();
        if (text === descriptor.textContent) {
          candidates.push({ el, score: 8 });
        } else if (text.includes(descriptor.textContent.slice(0, 20))) {
          candidates.push({ el, score: 6 });
        }
      }
    }

    // Strategy 3: placeholder match (score 8)
    if (descriptor.placeholder) {
      const els = document.querySelectorAll(`[placeholder]`);
      for (const el of els) {
        if (el.getAttribute('placeholder') === descriptor.placeholder) {
          candidates.push({ el, score: 8 });
        }
      }
    }

    // Strategy 4: data-attribute match (score 7)
    const dataKeys = Object.keys(descriptor.dataAttributes || {});
    if (dataKeys.length > 0) {
      for (const key of dataKeys) {
        const val = descriptor.dataAttributes[key];
        const els = document.querySelectorAll(`[${key}="${CSS.escape(val)}"]`);
        for (const el of els) {
          candidates.push({ el, score: 7 });
        }
      }
    }

    // Strategy 5: tag + text match (score 6)
    if (descriptor.tagName && descriptor.textContent) {
      const els = document.querySelectorAll(descriptor.tagName);
      for (const el of els) {
        const text = (el.textContent || '').trim();
        if (text === descriptor.textContent) {
          candidates.push({ el, score: 6 });
        } else if (descriptor.textContent.length > 5 && text.includes(descriptor.textContent.slice(0, 20))) {
          candidates.push({ el, score: 4 });
        }
      }
    }

    // Strategy 6: nth-child path walk (score 3, last resort)
    if (descriptor.nthChildPath && descriptor.nthChildPath.length > 0) {
      const el = walkNthChildPath(descriptor.nthChildPath);
      if (el) {
        candidates.push({ el, score: 3 });
      }
    }

    if (candidates.length === 0) return null;

    // Boost score if tagName also matches
    for (const c of candidates) {
      if (c.el.tagName.toLowerCase() === descriptor.tagName) {
        c.score += 1;
      }
    }

    // Return highest-scoring candidate
    candidates.sort((a, b) => b.score - a.score);
    return candidates[0].el;
  }

  function walkNthChildPath(path) {
    let current = document.body;
    for (const step of path) {
      if (!current) return null;
      const children = Array.from(current.children);
      const child = children[step.index];
      if (!child) return null;
      if (child.tagName.toLowerCase() !== step.tag) return null;
      current = child;
    }
    return current;
  }

  // ============================================================
  // C. Mouse Simulation
  // ============================================================

  function simulateClick(el) {
    el.scrollIntoView({ block: 'center', behavior: 'instant' });

    const rect = el.getBoundingClientRect();
    const x = rect.left + rect.width / 2;
    const y = rect.top + rect.height / 2;

    const commonInit = {
      bubbles: true, cancelable: true, composed: true,
      clientX: x, clientY: y, screenX: x, screenY: y,
      button: 0, buttons: 1,
    };

    // Full realistic event sequence
    el.dispatchEvent(new PointerEvent('pointerover', { ...commonInit, buttons: 0 }));
    el.dispatchEvent(new MouseEvent('mouseover', { ...commonInit, buttons: 0 }));
    el.dispatchEvent(new PointerEvent('pointerenter', { ...commonInit, buttons: 0, bubbles: false }));
    el.dispatchEvent(new MouseEvent('mouseenter', { ...commonInit, buttons: 0, bubbles: false }));
    el.dispatchEvent(new PointerEvent('pointermove', { ...commonInit, buttons: 0 }));
    el.dispatchEvent(new MouseEvent('mousemove', { ...commonInit, buttons: 0 }));
    el.dispatchEvent(new PointerEvent('pointerdown', commonInit));
    el.dispatchEvent(new MouseEvent('mousedown', commonInit));
    el.dispatchEvent(new PointerEvent('pointerup', { ...commonInit, buttons: 0 }));
    el.dispatchEvent(new MouseEvent('mouseup', { ...commonInit, buttons: 0 }));
    el.dispatchEvent(new MouseEvent('click', { ...commonInit, buttons: 0 }));
  }

  function simulateTyping(el, text) {
    el.scrollIntoView({ block: 'center', behavior: 'instant' });
    el.focus();

    // Select all existing content and delete it
    document.execCommand('selectAll', false, null);
    document.execCommand('delete', false, null);

    // Insert text — this triggers React/framework change detection natively
    const inserted = document.execCommand('insertText', false, text);

    if (!inserted) {
      // Fallback: InputEvent dispatch
      el.textContent = '';
      const inputEvent = new InputEvent('beforeinput', {
        bubbles: true, cancelable: true, inputType: 'insertText', data: text,
      });
      el.dispatchEvent(inputEvent);

      if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
        el.value = text;
      } else {
        el.textContent = text;
      }

      el.dispatchEvent(new InputEvent('input', {
        bubbles: true, inputType: 'insertText', data: text,
      }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }

  // ============================================================
  // D. Video Spec Interaction
  // ============================================================

  function setVideoSpec(specKey, value) {
    if (!value) return { success: true, skipped: true };

    const descriptor = pickedElements[`spec_${specKey}`];
    if (!descriptor) {
      return { success: false, error: `No picked element for spec: ${specKey}` };
    }

    const container = findByDescriptor(descriptor);
    if (!container) {
      return { success: false, error: `Spec control not found: ${specKey}` };
    }

    // Find a button/option within the container that matches the value text
    const clickTargets = container.querySelectorAll('button, [role="option"], [role="tab"], [role="radio"], [role="menuitemradio"], li, div[tabindex]');
    for (const target of clickTargets) {
      const text = (target.textContent || '').trim().toLowerCase();
      if (text === value.toLowerCase() || text.includes(value.toLowerCase())) {
        simulateClick(target);
        return { success: true };
      }
    }

    // Also try clicking the container itself if it looks like a toggle
    const containerText = (container.textContent || '').trim().toLowerCase();
    if (containerText.includes(value.toLowerCase())) {
      simulateClick(container);
      return { success: true };
    }

    return { success: false, error: `No matching option "${value}" found in spec control: ${specKey}` };
  }

  function applyAllVideoSpecs(specs) {
    const results = {};
    for (const [key, value] of Object.entries(specs)) {
      if (value) {
        results[key] = setVideoSpec(key, value);
      }
    }
    return results;
  }

  // ============================================================
  // E. Refactored Core Actions
  // ============================================================

  function findElement(key) {
    // Try picked element descriptor first
    if (pickedElements[key]) {
      const el = findByDescriptor(pickedElements[key]);
      if (el) return el;
    }

    // Fallback strategies for critical elements
    const fallbacks = {
      promptInput: () => {
        return document.querySelector('textarea[aria-label*="prompt" i]')
          || document.querySelector('textarea[aria-label*="describe" i]')
          || document.querySelector('textarea[placeholder*="prompt" i]')
          || document.querySelector('div[contenteditable="true"][aria-label*="prompt" i]')
          || document.querySelector('div[contenteditable="true"]')
          || document.querySelector('textarea');
      },
      generateButton: () => {
        return document.querySelector('button[aria-label*="generate" i]')
          || document.querySelector('button[aria-label*="create" i]')
          || findButtonByText(['generate', 'create', 'go']);
      },
      downloadButton: () => {
        return document.querySelector('button[aria-label*="download" i]')
          || document.querySelector('a[aria-label*="download" i]')
          || document.querySelector('a[download]')
          || findButtonByText(['download', 'save']);
      },
      videoElement: () => {
        return document.querySelector('video[src]')
          || document.querySelector('video');
      },
      loadingIndicator: () => {
        return document.querySelector('[role="progressbar"]')
          || document.querySelector('[aria-label*="loading" i]')
          || document.querySelector('[aria-label*="generating" i]');
      },
      errorIndicator: () => {
        return document.querySelector('[role="alert"]')
          || document.querySelector('[aria-label*="error" i]');
      },
    };

    return fallbacks[key]?.() || null;
  }

  function findButtonByText(keywords) {
    const buttons = document.querySelectorAll('button, [role="button"]');
    for (const btn of buttons) {
      const text = btn.textContent.toLowerCase().trim();
      for (const kw of keywords) {
        if (text.includes(kw)) return btn;
      }
    }
    return null;
  }

  function fillPrompt(text) {
    const input = findElement('promptInput');
    if (!input) {
      return { success: false, error: 'Prompt input not found' };
    }

    simulateTyping(input, text);
    return { success: true };
  }

  function clickGenerate() {
    const btn = findElement('generateButton');
    if (!btn) {
      return { success: false, error: 'Generate button not found' };
    }
    simulateClick(btn);
    return { success: true };
  }

  function clickDownload() {
    const btn = findElement('downloadButton');
    if (!btn) {
      const video = findElement('videoElement');
      if (video) {
        const src = video.src || video.querySelector('source')?.src;
        if (src) {
          return { success: true, videoUrl: src };
        }
      }
      return { success: false, error: 'Download button not found' };
    }
    simulateClick(btn);
    return { success: true };
  }

  function getPageStatus() {
    const loading = findElement('loadingIndicator');
    const error = findElement('errorIndicator');
    const video = findElement('videoElement');

    if (error) {
      const msg = error.textContent?.trim() || 'Unknown error';
      return { status: 'error', message: msg };
    }
    if (loading) {
      return { status: 'generating' };
    }
    if (video) {
      const src = video.src || video.querySelector('source')?.src;
      if (src) {
        return { status: 'complete', videoUrl: src };
      }
    }
    return { status: 'idle' };
  }

  function testElement(key) {
    const el = findElement(key);
    if (!el) {
      return { found: false };
    }
    const tag = el.tagName.toLowerCase();
    const label = el.getAttribute('aria-label') || (el.textContent || '').trim().slice(0, 30);
    return { found: true, tag, label };
  }

  // ---- MutationObserver-based completion watcher ----

  let completionWatcher = null;

  function startWatchingCompletion(timeoutMs) {
    return new Promise((resolve) => {
      const deadline = Date.now() + timeoutMs;

      stopWatchingCompletion();

      const check = () => {
        const status = getPageStatus();
        if (status.status === 'complete' || status.status === 'error') {
          stopWatchingCompletion();
          resolve(status);
          return true;
        }
        if (Date.now() > deadline) {
          stopWatchingCompletion();
          resolve({ status: 'timeout' });
          return true;
        }
        return false;
      };

      if (check()) return;

      const observer = new MutationObserver(() => {
        check();
      });

      observer.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['src', 'class', 'style', 'aria-label', 'hidden'],
      });

      let pollInterval = 2000;
      const poll = () => {
        if (check()) return;
        pollInterval = Math.min(pollInterval * 1.2, 10000);
        completionWatcher.timer = setTimeout(poll, pollInterval);
      };

      completionWatcher = { observer, timer: setTimeout(poll, pollInterval) };
    });
  }

  function stopWatchingCompletion() {
    if (completionWatcher) {
      completionWatcher.observer?.disconnect();
      clearTimeout(completionWatcher.timer);
      completionWatcher = null;
    }
  }

  // ============================================================
  // F. Message Handler
  // ============================================================

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    const { action, payload } = message;

    switch (action) {
      case 'fillPrompt':
        sendResponse(fillPrompt(payload.text));
        break;

      case 'clickGenerate':
        sendResponse(clickGenerate());
        break;

      case 'clickDownload':
        sendResponse(clickDownload());
        break;

      case 'getStatus':
        sendResponse(getPageStatus());
        break;

      case 'waitForCompletion': {
        const timeout = payload?.timeout || 300000;
        startWatchingCompletion(timeout).then(sendResponse);
        return true;
      }

      case 'startPicker':
        sendResponse(startPicker(payload.role));
        break;

      case 'stopPicker':
        sendResponse(stopPicker());
        break;

      case 'applyVideoSpecs':
        sendResponse(applyAllVideoSpecs(payload.specs));
        break;

      case 'updatePickedElements':
        pickedElements = { ...pickedElements, ...payload };
        sendResponse({ success: true });
        break;

      case 'testElement':
        sendResponse(testElement(payload.key));
        break;

      case 'ping':
        sendResponse({ alive: true });
        break;

      default:
        sendResponse({ error: `Unknown action: ${action}` });
    }
  });

  console.log('[Veo3 Flow Automator] Content script loaded on', window.location.href);
})();
