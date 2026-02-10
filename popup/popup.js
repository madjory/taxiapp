// Popup logic — manages prompt queue, controls, settings, picker UI, and status display.

document.addEventListener('DOMContentLoaded', init);

async function init() {
  setupTabs();
  await loadSettings();
  await loadVideoSpecs();
  await loadDownloadFolder();
  await loadPickedElementsUI();
  await renderQueue();
  await renderLogs();
  await syncPipelineStatus();
  bindEvents();
  listenForStatusUpdates();
}

// ---- Tabs ----

function setupTabs() {
  document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach((t) => t.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
    });
  });
}

// ---- Queue ----

async function renderQueue() {
  const queue = await Storage.getQueue();
  const list = document.getElementById('queueList');

  if (queue.length === 0) {
    list.innerHTML = '<p class="empty-msg">No prompts in queue</p>';
    return;
  }

  list.innerHTML = queue
    .map((item, i) => `
      <div class="queue-item" data-index="${i}">
        <span class="index">${i + 1}</span>
        <span class="text" title="${escapeHtml(item.text)}">${escapeHtml(item.text)}</span>
        <span class="badge ${item.status || 'pending'}">${item.status || 'pending'}</span>
        <button class="remove-btn" data-index="${i}" title="Remove">&times;</button>
      </div>
    `)
    .join('');

  list.querySelectorAll('.remove-btn').forEach((btn) => {
    btn.addEventListener('click', async (e) => {
      const idx = parseInt(e.target.dataset.index);
      const q = await Storage.getQueue();
      q.splice(idx, 1);
      await Storage.setQueue(q);
      await renderQueue();
    });
  });
}

async function addPrompt(text) {
  const trimmed = text.trim();
  if (!trimmed) return;
  const queue = await Storage.getQueue();
  queue.push({ text: trimmed, status: 'pending' });
  await Storage.setQueue(queue);
  await renderQueue();
}

async function addPromptsFromFile(file) {
  const text = await file.text();
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const queue = await Storage.getQueue();
  for (const line of lines) {
    queue.push({ text: line, status: 'pending' });
  }
  await Storage.setQueue(queue);
  await renderQueue();
}

// ---- Settings ----

async function loadSettings() {
  const s = await Storage.getSettings();
  document.getElementById('delayBetween').value = s.delayBetween;
  document.getElementById('autoDownload').checked = s.autoDownload;
  document.getElementById('maxRetries').value = s.maxRetries;
  document.getElementById('completionTimeout').value = s.completionTimeout;
}

async function loadVideoSpecs() {
  const specs = await Storage.getVideoSpecs();
  document.getElementById('specAspectRatio').value = specs.aspectRatio || '';
  document.getElementById('specDuration').value = specs.duration || '';
  document.getElementById('specStyle').value = specs.style || '';
}

async function loadDownloadFolder() {
  const folder = await Storage.getDownloadFolder();
  document.getElementById('downloadFolder').value = folder || '';
}

async function saveSettings() {
  await Storage.setSettings({
    delayBetween: parseInt(document.getElementById('delayBetween').value) || 5,
    autoDownload: document.getElementById('autoDownload').checked,
    maxRetries: parseInt(document.getElementById('maxRetries').value) || 2,
    completionTimeout: parseInt(document.getElementById('completionTimeout').value) || 300,
  });

  await Storage.setVideoSpecs({
    aspectRatio: document.getElementById('specAspectRatio').value,
    duration: document.getElementById('specDuration').value,
    style: document.getElementById('specStyle').value,
  });

  await Storage.setDownloadFolder(document.getElementById('downloadFolder').value.trim());
}

// ---- Picker UI ----

async function loadPickedElementsUI() {
  const elements = await Storage.getPickedElements();

  document.querySelectorAll('[data-role-status]').forEach((statusEl) => {
    const role = statusEl.getAttribute('data-role-status');
    const descriptor = elements[role];

    if (descriptor && descriptor.displayLabel) {
      statusEl.textContent = descriptor.displayLabel;
      statusEl.className = 'picker-status set';
    } else {
      statusEl.textContent = 'Not set';
      statusEl.className = 'picker-status not-set';
    }
  });
}

async function startPickerForRole(role) {
  const tabs = await chrome.tabs.query({ url: 'https://labs.google/fx/tools/flow/*' });
  if (tabs.length === 0) {
    const statusEl = document.querySelector(`[data-role-status="${role}"]`);
    if (statusEl) {
      statusEl.textContent = 'No Flow tab found!';
      statusEl.className = 'picker-status test-fail';
    }
    return;
  }

  // Show picking state
  const statusEl = document.querySelector(`[data-role-status="${role}"]`);
  if (statusEl) {
    statusEl.textContent = 'Picking... (click element on Flow page)';
    statusEl.className = 'picker-status picking';
  }

  // Send startPicker to content script — popup will close when user clicks Flow page
  try {
    await chrome.tabs.sendMessage(tabs[0].id, { action: 'startPicker', payload: { role } });
  } catch (err) {
    if (statusEl) {
      statusEl.textContent = `Error: ${err.message}`;
      statusEl.className = 'picker-status test-fail';
    }
  }
}

async function testAllElements() {
  const tabs = await chrome.tabs.query({ url: 'https://labs.google/fx/tools/flow/*' });
  if (tabs.length === 0) return;

  const tabId = tabs[0].id;
  const elements = await Storage.getPickedElements();
  const roles = Object.keys(elements);

  // Also test standard roles even if not picked (they have fallbacks)
  const allRoles = new Set([
    ...roles,
    'promptInput', 'generateButton', 'downloadButton',
    'videoElement', 'loadingIndicator', 'errorIndicator',
  ]);

  for (const role of allRoles) {
    const statusEl = document.querySelector(`[data-role-status="${role}"]`);
    if (!statusEl) continue;

    try {
      const result = await chrome.tabs.sendMessage(tabId, { action: 'testElement', payload: { key: role } });
      if (result.found) {
        statusEl.textContent = `Found: ${result.tag} ${result.label || ''}`.trim();
        statusEl.className = 'picker-status test-pass';
      } else {
        statusEl.textContent = 'Not found on page';
        statusEl.className = 'picker-status test-fail';
      }
    } catch (err) {
      statusEl.textContent = `Error: ${err.message}`;
      statusEl.className = 'picker-status test-fail';
    }
  }
}

async function clearAllPicks() {
  // Clear all picked elements by overwriting with empty object
  const elements = await Storage.getPickedElements();
  for (const key of Object.keys(elements)) {
    await Storage.clearPickedElement(key);
  }
  await loadPickedElementsUI();

  // Also clear content script cache
  const tabs = await chrome.tabs.query({ url: 'https://labs.google/fx/tools/flow/*' });
  if (tabs.length > 0) {
    chrome.tabs.sendMessage(tabs[0].id, { action: 'updatePickedElements', payload: {} }).catch(() => {});
  }
}

// ---- Logs ----

async function renderLogs() {
  const logs = await Storage.getLogs();
  const list = document.getElementById('logList');

  if (logs.length === 0) {
    list.innerHTML = '<p class="empty-msg">No logs yet</p>';
    return;
  }

  list.innerHTML = logs
    .slice()
    .reverse()
    .map((entry) => {
      const time = new Date(entry.timestamp).toLocaleTimeString();
      return `<div class="log-entry ${entry.type}">[${time}] ${escapeHtml(entry.message)}</div>`;
    })
    .join('');

  list.scrollTop = 0;
}

// ---- Controls ----

async function syncPipelineStatus() {
  try {
    const resp = await chrome.runtime.sendMessage({ type: 'getPipelineRunning' });
    updateControlButtons(resp.running, resp.paused);
  } catch {
    updateControlButtons(false, false);
  }
}

function updateControlButtons(running, paused) {
  const startBtn = document.getElementById('startBtn');
  const pauseBtn = document.getElementById('pauseBtn');
  const stopBtn = document.getElementById('stopBtn');

  startBtn.disabled = running && !paused;
  pauseBtn.disabled = !running || paused;
  stopBtn.disabled = !running;

  if (paused) {
    startBtn.textContent = 'Resume';
    startBtn.disabled = false;
  } else {
    startBtn.textContent = 'Start';
  }
}

function updateStatusBar(status, detail) {
  const bar = document.getElementById('statusBar');
  bar.className = 'status ' + status;

  const labels = {
    idle: 'Idle',
    running: 'Running',
    generating: 'Generating',
    waiting: 'Waiting for completion',
    waiting_delay: 'Waiting (delay)',
    downloading: 'Downloading',
    paused: 'Paused',
    error: 'Error',
  };

  let text = labels[status] || status;
  if (detail) text += `: ${detail.slice(0, 40)}`;
  bar.textContent = text;
}

// ---- Event Binding ----

function bindEvents() {
  // Add prompt
  document.getElementById('addPromptBtn').addEventListener('click', async () => {
    const input = document.getElementById('promptInput');
    await addPrompt(input.value);
    input.value = '';
  });

  // Allow Enter (with Ctrl/Cmd) to add prompt
  document.getElementById('promptInput').addEventListener('keydown', async (e) => {
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      const input = document.getElementById('promptInput');
      await addPrompt(input.value);
      input.value = '';
    }
  });

  // File upload
  document.getElementById('fileUpload').addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (file) {
      await addPromptsFromFile(file);
      e.target.value = '';
    }
  });

  // Clear queue
  document.getElementById('clearQueueBtn').addEventListener('click', async () => {
    await Storage.clearQueue();
    await Storage.resetPipelineState();
    await renderQueue();
  });

  // Save settings
  document.getElementById('saveSettingsBtn').addEventListener('click', async () => {
    await saveSettings();
    document.getElementById('saveSettingsBtn').textContent = 'Saved!';
    setTimeout(() => {
      document.getElementById('saveSettingsBtn').textContent = 'Save Settings';
    }, 1500);
  });

  // Picker: pick buttons (event delegation)
  document.querySelectorAll('.pick-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      const role = btn.getAttribute('data-role');
      startPickerForRole(role);
    });
  });

  // Picker: test all
  document.getElementById('testAllBtn').addEventListener('click', testAllElements);

  // Picker: clear all
  document.getElementById('clearAllPicksBtn').addEventListener('click', clearAllPicks);

  // Logs
  document.getElementById('clearLogsBtn').addEventListener('click', async () => {
    await Storage.clearLogs();
    await renderLogs();
  });

  // Pipeline controls
  document.getElementById('startBtn').addEventListener('click', async () => {
    const resp = await chrome.runtime.sendMessage({ type: 'getPipelineRunning' });
    if (resp.paused) {
      await chrome.runtime.sendMessage({ type: 'resumePipeline' });
    } else {
      await Storage.resetPipelineState();
      const queue = await Storage.getQueue();
      const reset = queue.map((item) =>
        item.status === 'failed' || item.status === 'pending'
          ? { ...item, status: 'pending' }
          : item
      );
      await Storage.setQueue(reset);
      await renderQueue();
      await chrome.runtime.sendMessage({ type: 'startPipeline' });
    }
    updateControlButtons(true, false);
    updateStatusBar('running');
  });

  document.getElementById('pauseBtn').addEventListener('click', async () => {
    await chrome.runtime.sendMessage({ type: 'pausePipeline' });
    updateControlButtons(true, true);
    updateStatusBar('paused');
  });

  document.getElementById('stopBtn').addEventListener('click', async () => {
    await chrome.runtime.sendMessage({ type: 'stopPipeline' });
    updateControlButtons(false, false);
    updateStatusBar('idle');
  });
}

// ---- Status Updates ----

function listenForStatusUpdates() {
  chrome.runtime.onMessage.addListener((message) => {
    if (message.type === 'statusUpdate') {
      updateStatusBar(message.status, message.detail);

      if (message.status === 'idle') {
        updateControlButtons(false, false);
      }

      renderQueue();
      renderLogs();
    }

    // Refresh picker UI when an element is picked (background sends this)
    if (message.type === 'elementPickedConfirm') {
      loadPickedElementsUI();
    }
  });

  // Periodic refresh while popup is open
  setInterval(async () => {
    await renderQueue();
    await renderLogs();
    await syncPipelineStatus();
  }, 3000);
}

// ---- Utility ----

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
