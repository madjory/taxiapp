// Background service worker — orchestrates the video generation pipeline.

importScripts('../utils/storage.js');

// ---- State ----
let pipelineRunning = false;
let pipelinePaused = false;
let abortController = null;

// ---- Helpers ----

function sleep(ms, signal) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, ms);
    signal?.addEventListener('abort', () => {
      clearTimeout(timer);
      reject(new DOMException('Aborted', 'AbortError'));
    });
  });
}

async function getFlowTabId() {
  const tabs = await chrome.tabs.query({ url: 'https://labs.google/fx/tools/flow/*' });
  return tabs.length > 0 ? tabs[0].id : null;
}

async function sendToContent(tabId, action, payload = {}) {
  try {
    return await chrome.tabs.sendMessage(tabId, { action, payload });
  } catch (err) {
    return { success: false, error: `Message failed: ${err.message}` };
  }
}

function sanitizeFilename(text, maxLen = 60) {
  return text
    .replace(/[^a-zA-Z0-9 _-]/g, '')
    .trim()
    .replace(/\s+/g, '_')
    .slice(0, maxLen) || 'video';
}

// ---- Pipeline ----

async function runPipeline() {
  if (pipelineRunning) return;
  pipelineRunning = true;
  pipelinePaused = false;
  abortController = new AbortController();
  const signal = abortController.signal;

  const settings = await Storage.getSettings();
  let queue = await Storage.getQueue();
  let state = await Storage.getPipelineState();
  let currentIndex = state.currentIndex || 0;

  await Storage.setPipelineState({ status: 'running', currentIndex });
  broadcastStatus('running');

  try {
    while (currentIndex < queue.length) {
      if (signal.aborted) break;

      // Check for pause
      if (pipelinePaused) {
        await Storage.setPipelineState({ status: 'paused', currentIndex });
        broadcastStatus('paused');
        await new Promise((resolve) => {
          const check = setInterval(() => {
            if (!pipelinePaused || signal.aborted) {
              clearInterval(check);
              resolve();
            }
          }, 500);
        });
        if (signal.aborted) break;
        await Storage.setPipelineState({ status: 'running', currentIndex });
        broadcastStatus('running');
      }

      const prompt = queue[currentIndex];
      if (!prompt || prompt.status === 'done') {
        currentIndex++;
        await Storage.setPipelineState({ currentIndex });
        continue;
      }

      const tabId = await getFlowTabId();
      if (!tabId) {
        await Storage.addLog({ type: 'error', message: 'No Flow tab found. Open labs.google/fx/tools/flow first.' });
        broadcastStatus('error', 'No Flow tab found');
        break;
      }

      // Update prompt status
      queue[currentIndex] = { ...prompt, status: 'generating' };
      await Storage.setQueue(queue);
      broadcastStatus('generating', prompt.text);
      await Storage.addLog({ type: 'info', message: `Starting prompt ${currentIndex + 1}: "${prompt.text.slice(0, 50)}..."` });

      let retries = 0;
      let success = false;

      while (retries <= settings.maxRetries && !signal.aborted) {
        // Step 0: Apply video specs before generating
        const videoSpecs = await Storage.getVideoSpecs();
        const hasSpecs = videoSpecs.aspectRatio || videoSpecs.duration || videoSpecs.style;
        if (hasSpecs) {
          const specResult = await sendToContent(tabId, 'applyVideoSpecs', { specs: videoSpecs });
          if (specResult) {
            for (const [key, res] of Object.entries(specResult)) {
              if (res && !res.success && !res.skipped) {
                await Storage.addLog({ type: 'info', message: `Video spec "${key}": ${res.error || 'failed'}` });
              }
            }
          }
          await sleep(500, signal).catch(() => {});
        }

        // Step 1: Fill prompt
        const fillResult = await sendToContent(tabId, 'fillPrompt', { text: prompt.text });
        if (!fillResult.success) {
          await Storage.addLog({ type: 'error', message: `Fill failed: ${fillResult.error}` });
          retries++;
          await sleep(2000, signal).catch(() => {});
          continue;
        }

        // Small delay before clicking generate
        await sleep(800, signal).catch(() => {});

        // Step 2: Click generate
        const genResult = await sendToContent(tabId, 'clickGenerate');
        if (!genResult.success) {
          await Storage.addLog({ type: 'error', message: `Generate click failed: ${genResult.error}` });
          retries++;
          await sleep(2000, signal).catch(() => {});
          continue;
        }

        broadcastStatus('waiting', prompt.text);

        // Step 3: Wait for completion
        const timeout = (settings.completionTimeout || 300) * 1000;
        const completionResult = await sendToContent(tabId, 'waitForCompletion', { timeout });

        if (completionResult.status === 'complete') {
          await Storage.addLog({ type: 'success', message: `Prompt ${currentIndex + 1} completed` });

          // Step 4: Download if enabled
          if (settings.autoDownload) {
            broadcastStatus('downloading', prompt.text);
            await handleDownload(tabId, prompt.text, completionResult.videoUrl);
          }

          queue[currentIndex] = { ...prompt, status: 'done' };
          await Storage.setQueue(queue);
          success = true;
          break;
        } else if (completionResult.status === 'error') {
          await Storage.addLog({ type: 'error', message: `Generation error: ${completionResult.message}` });
          retries++;
        } else if (completionResult.status === 'timeout') {
          await Storage.addLog({ type: 'error', message: `Timeout waiting for prompt ${currentIndex + 1}` });
          retries++;
        } else {
          await Storage.addLog({ type: 'error', message: `Unexpected status: ${JSON.stringify(completionResult)}` });
          retries++;
        }

        if (retries <= settings.maxRetries) {
          await Storage.addLog({ type: 'info', message: `Retrying (${retries}/${settings.maxRetries})...` });
          await sleep(3000, signal).catch(() => {});
        }
      }

      if (!success) {
        queue[currentIndex] = { ...prompt, status: 'failed' };
        await Storage.setQueue(queue);
        await Storage.addLog({ type: 'error', message: `Prompt ${currentIndex + 1} failed after ${retries} retries` });
      }

      currentIndex++;
      await Storage.setPipelineState({ currentIndex });

      // Delay between generations
      if (currentIndex < queue.length && !signal.aborted) {
        broadcastStatus('waiting_delay');
        await sleep(settings.delayBetween * 1000, signal).catch(() => {});
      }

      // Reload queue in case it was modified
      queue = await Storage.getQueue();
    }
  } catch (err) {
    if (err.name !== 'AbortError') {
      await Storage.addLog({ type: 'error', message: `Pipeline error: ${err.message}` });
    }
  }

  pipelineRunning = false;
  await Storage.setPipelineState({ status: 'idle', currentIndex });
  broadcastStatus('idle');
}

async function handleDownload(tabId, promptText, videoUrl) {
  // Try the download button on the page first
  const dlResult = await sendToContent(tabId, 'clickDownload');

  // If content script returned a video URL, download it via chrome.downloads
  const url = videoUrl || dlResult?.videoUrl;
  if (url) {
    try {
      const baseName = `flow_${sanitizeFilename(promptText)}_${Date.now()}.mp4`;

      // Prepend download subfolder if configured
      const folder = await Storage.getDownloadFolder();
      const filename = folder ? `${folder}/${baseName}` : baseName;

      await chrome.downloads.download({ url, filename, saveAs: false });
      await Storage.addLog({ type: 'success', message: `Downloaded: ${filename}` });
    } catch (err) {
      await Storage.addLog({ type: 'error', message: `Download failed: ${err.message}` });
    }
  } else if (!dlResult?.success) {
    await Storage.addLog({ type: 'error', message: `Download button not found and no video URL available` });
  }
}

function broadcastStatus(status, detail) {
  chrome.runtime.sendMessage({ type: 'statusUpdate', status, detail }).catch(() => {});
}

// ---- Message handler from popup and content scripts ----

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const { type, payload } = message;

  switch (type) {
    case 'startPipeline':
      runPipeline();
      sendResponse({ ok: true });
      break;

    case 'pausePipeline':
      pipelinePaused = true;
      sendResponse({ ok: true });
      break;

    case 'resumePipeline':
      pipelinePaused = false;
      sendResponse({ ok: true });
      break;

    case 'stopPipeline':
      pipelinePaused = false;
      if (abortController) abortController.abort();
      pipelineRunning = false;
      Storage.setPipelineState({ status: 'idle' }).then(() => {
        broadcastStatus('idle');
      });
      sendResponse({ ok: true });
      break;

    case 'getPipelineRunning':
      sendResponse({ running: pipelineRunning, paused: pipelinePaused });
      break;

    case 'elementPicked': {
      // Content script picked an element — store descriptor and notify popup
      const { role, descriptor } = payload;
      Storage.setPickedElements({ [role]: descriptor }).then(async () => {
        // Update the content script's cache too
        const tabId = sender.tab?.id;
        if (tabId) {
          const all = await Storage.getPickedElements();
          sendToContent(tabId, 'updatePickedElements', all);
        }
        // Notify popup to refresh
        chrome.runtime.sendMessage({ type: 'elementPickedConfirm', role, descriptor }).catch(() => {});
      });
      sendResponse({ ok: true });
      break;
    }

    case 'pickerCancelled':
      // User pressed Escape in picker mode — notify popup
      chrome.runtime.sendMessage({ type: 'elementPickedConfirm' }).catch(() => {});
      sendResponse({ ok: true });
      break;

    default:
      break;
  }
});

console.log('[Veo3 Flow Automator] Background service worker started');
