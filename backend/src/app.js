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
app.use(cors());
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
