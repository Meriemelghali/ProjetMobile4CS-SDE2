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

// CORS : autorise Flutter web (localhost sur n'importe quel port) + app mobile
app.use(cors({
  origin: (origin, callback) => {
    // Autorise les requêtes sans origin (apps mobiles, Postman)
    if (!origin) return callback(null, true);
    // Autorise tout ce qui vient de localhost (Flutter web)
    if (origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1')) {
      return callback(null, true);
    }
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
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
