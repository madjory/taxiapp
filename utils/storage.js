// Storage utility helpers for Chrome extension storage API

const Storage = {
  // ---- Prompt Queue ----

  async getQueue() {
    const { promptQueue } = await chrome.storage.local.get('promptQueue');
    return promptQueue || [];
  },

  async setQueue(queue) {
    await chrome.storage.local.set({ promptQueue: queue });
  },

  async clearQueue() {
    await chrome.storage.local.set({ promptQueue: [] });
  },

  // ---- Settings ----

  async getSettings() {
    const { settings } = await chrome.storage.local.get('settings');
    return {
      delayBetween: 5,
      autoDownload: true,
      maxRetries: 2,
      completionTimeout: 300,
      ...settings,
    };
  },

  async setSettings(settings) {
    const current = await Storage.getSettings();
    await chrome.storage.local.set({ settings: { ...current, ...settings } });
  },

  // ---- Picked Elements (replaces CSS selectors) ----

  async getPickedElements() {
    const { pickedElements } = await chrome.storage.local.get('pickedElements');
    return pickedElements || {};
  },

  async setPickedElements(elements) {
    const current = await Storage.getPickedElements();
    await chrome.storage.local.set({ pickedElements: { ...current, ...elements } });
  },

  async clearPickedElement(key) {
    const current = await Storage.getPickedElements();
    delete current[key];
    await chrome.storage.local.set({ pickedElements: current });
  },

  // ---- Video Specifications ----

  async getVideoSpecs() {
    const { videoSpecs } = await chrome.storage.local.get('videoSpecs');
    return {
      aspectRatio: '',
      duration: '',
      style: '',
      ...videoSpecs,
    };
  },

  async setVideoSpecs(specs) {
    const current = await Storage.getVideoSpecs();
    await chrome.storage.local.set({ videoSpecs: { ...current, ...specs } });
  },

  // ---- Download Folder ----

  async getDownloadFolder() {
    const { downloadFolder } = await chrome.storage.local.get('downloadFolder');
    return downloadFolder || '';
  },

  async setDownloadFolder(folder) {
    await chrome.storage.local.set({ downloadFolder: folder });
  },

  // ---- Pipeline State ----

  async getPipelineState() {
    const { pipelineState } = await chrome.storage.local.get('pipelineState');
    return {
      status: 'idle',
      currentIndex: 0,
      retryCount: 0,
      ...pipelineState,
    };
  },

  async setPipelineState(state) {
    const current = await Storage.getPipelineState();
    await chrome.storage.local.set({ pipelineState: { ...current, ...state } });
  },

  async resetPipelineState() {
    await chrome.storage.local.set({
      pipelineState: { status: 'idle', currentIndex: 0, retryCount: 0 },
    });
  },

  // ---- Log ----

  async addLog(entry) {
    const { logs } = await chrome.storage.local.get('logs');
    const current = logs || [];
    current.push({ ...entry, timestamp: Date.now() });
    if (current.length > 200) current.splice(0, current.length - 200);
    await chrome.storage.local.set({ logs: current });
  },

  async getLogs() {
    const { logs } = await chrome.storage.local.get('logs');
    return logs || [];
  },

  async clearLogs() {
    await chrome.storage.local.set({ logs: [] });
  },
};

// Make available in both content script and module contexts
if (typeof globalThis !== 'undefined') {
  globalThis.Storage = Storage;
}
