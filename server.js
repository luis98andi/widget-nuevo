const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const PORT = process.env.PORT || 3000;
let lastMessage = null;

app.use(express.json({ limit: '1mb' }));
app.use(express.static(path.join(__dirname)));

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'widget-voz',
    status: 'online'
  });
});

app.get('/mobile', (req, res) => {
  res.sendFile(path.join(__dirname, 'mobile.html'));
});

app.get('/gadget', (req, res) => {
  res.sendFile(path.join(__dirname, 'gadget.html'));
});

app.get('/api/last-message', (req, res) => {
  res.json({
    ok: true,
    text: lastMessage
  });
});

app.post('/api/message', (req, res) => {
  const text = String(req.body?.text || '').trim();

  if (!text) {
    return res.status(400).json({ ok: false, message: 'No se recibió texto válido.' });
  }

  lastMessage = text;
  io.emit('voice:text', { text });

  return res.json({
    ok: true,
    message: 'Texto enviado correctamente.',
    chars: text.length
  });
});

io.on('connection', (socket) => {
  console.log('Cliente conectado:', socket.id);

  socket.on('widget:ready', () => {
    socket.emit('status', {
      ok: true,
      message: 'Widget listo para escuchar mensajes.'
    });
  });
});

server.listen(PORT, () => {
  console.log(`Servidor escuchando en http://localhost:${PORT}`);
  console.log(`Abre tu móvil en: http://<IP-DE-TU-PC>:${PORT}/mobile`);
  console.log(`8Gadget puede usar: http://localhost:${PORT}/gadget`);
});
