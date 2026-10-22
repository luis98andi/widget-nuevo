const textoInput = document.getElementById('texto');
const leerBtn = document.getElementById('leerBtn');
const stopBtn = document.getElementById('stopBtn');
const statusEl = document.getElementById('status');

function setStatus(message) {
  if (statusEl) {
    statusEl.textContent = message;
  }
}

function leer() {
  const texto = (textoInput.value || '').trim();

  if (!texto) {
    setStatus('Sin texto');
    return;
  }

  try {
    var speak = new ActiveXObject('SAPI.SpVoice');
    speak.Volume = 100;
    speak.Rate = 0;
    speak.Speak(texto);
    setStatus('Leyendo al 100%');
  } catch (e) {
    setStatus('TTS no disponible');
  }
}

function detener() {
  try {
    if (window.ActiveXObject || document.all) {
      var speak = new ActiveXObject('SAPI.SpVoice');
      speak.Speak('', 0);
    }
  } catch (e) {
    // no-op
  }
  setStatus('Detenido');
}

if (leerBtn) {
  leerBtn.addEventListener('click', leer);
}

if (stopBtn) {
  stopBtn.addEventListener('click', detener);
}

if (window.io) {
  const socket = io();
  socket.on('connect', () => {
    socket.emit('widget:ready');
    setStatus('Listo');
  });

  socket.on('voice:text', (data) => {
    const text = data && data.text ? String(data.text) : '';
    if (text) {
      textoInput.value = text;
      leer();
    }
  });

  socket.on('disconnect', () => {
    setStatus('Sin conexión');
  });
}
