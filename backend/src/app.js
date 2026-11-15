const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { errorHandler, notFound } = require('./errors');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const serviceRoutes = require('./routes/serviceRoutes');
const shiftRoutes = require('./routes/shiftRoutes');
const handoverRoutes = require('./routes/handoverRoutes');

const app = express();

app.disable('x-powered-by');

// CORS : autorise Flutter web (tous les ports localhost) + apps mobiles + Postman
app.use(cors({
  origin: (origin, callback) => {
    // Autorise les requêtes sans origin (apps mobiles natives, Postman, curl)
    if (!origin) return callback(null, true);
    // Autorise TOUT localhost (peu importe le port) — nécessaire pour Flutter web
    if (
      origin.startsWith('http://localhost') ||
      origin.startsWith('http://127.0.0.1') ||
      origin.startsWith('http://10.0.2.2')
    ) {
      return callback(null, true);
    }
    // En développement : autorise aussi les IPs locales (192.168.x.x)
    if (origin.match(/^http:\/\/192\.168\.\d+\.\d+/)) {
      return callback(null, true);
    }
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ limit: '32kb' }));
app.use(morgan('dev'));
app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/auth', authRoutes);
app.use('/users', userRoutes);
app.use('/services', serviceRoutes);
app.use('/shifts', shiftRoutes);
app.use('/handovers', handoverRoutes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;
