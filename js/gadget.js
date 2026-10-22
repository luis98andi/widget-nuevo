const textoInput = document.getElementById('texto');
const leerBtn = document.getElementById('leerBtn');
const statusEl = document.getElementById('status');

function setStatus(message) {
  statusEl.textContent = message;
}

function speakAtFullVolume(text) {
  try {
    if (window.ActiveXObject || document.all) {
      const voice = new ActiveXObject('SAPI.SpVoice');
      voice.Volume = 100;
      voice.Rate = 0;
      voice.Speak(text);
      setStatus('Leyendo al 100% de volumen.');
      return true;
    }
  } catch (error) {
    console.warn('SAPI no disponible:', error);
  }

  if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'es-ES';
    utterance.volume = 1;
    utterance.rate = 1;
    utterance.onstart = () => setStatus('Leyendo al 100% de volumen.');
    utterance.onend = () => setStatus('Lista.');
    utterance.onerror = () => setStatus('No se pudo reproducir.');
    window.speechSynthesis.speak(utterance);
    return true;
  }

  setStatus('No hay voz disponible en este entorno.');
  return false;
}

async function cargarUltimoTexto() {
  try {
    const respuesta = await fetch('http://localhost:3000/api/last-message', { cache: 'no-store' });
    const data = await respuesta.json();
    if (data && data.text) {
      textoInput.value = data.text;
      speakAtFullVolume(data.text);
      setStatus('Mensaje recibido y leído.');
    }
  } catch (error) {
    setStatus('Esperando mensajes...');
  }
}

leerBtn.addEventListener('click', () => {
  const texto = textoInput.value.trim();
  if (!texto) {
    setStatus('No hay texto para leer.');
    return;
  }
  speakAtFullVolume(texto);
});

setInterval(cargarUltimoTexto, 1500);
cargarUltimoTexto();
