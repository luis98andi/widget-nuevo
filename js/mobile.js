const form = document.getElementById('mobileText');
const sendBtn = document.getElementById('sendBtn');
const status = document.getElementById('mobileStatus');

async function enviarTexto() {
  const text = (form.value || '').trim();

  if (!text) {
    status.textContent = 'Escribe algo antes de enviar.';
    form.focus();
    return;
  }

  sendBtn.disabled = true;
  status.textContent = 'Enviando...';

  try {
    const response = await fetch('/api/message', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ text })
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'No se pudo enviar el texto.');
    }

    status.textContent = 'Mensaje enviado correctamente.';
    form.value = '';
  } catch (error) {
    status.textContent = error.message || 'Error al enviar el texto.';
  } finally {
    sendBtn.disabled = false;
  }
}

sendBtn.addEventListener('click', enviarTexto);
form.addEventListener('keydown', (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    enviarTexto();
  }
});
