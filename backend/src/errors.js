class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
  }
}

function notFound(_req, res) {
  res.status(404).json({ error: { message: 'Route not found.' } });
}

function errorHandler(error, _req, res, _next) {
  if (res.headersSent) return;

  if (error.name === 'ValidationError') {
    return res.status(400).json({ error: { message: error.message } });
  }
  if (error.code === 11000) {
    return res.status(409).json({
      error: { message: 'A record with that value already exists.' },
    });
  }
  if (error.name === 'CastError') {
    return res.status(400).json({ error: { message: 'Invalid identifier or value.' } });
  }

  const status = Number.isInteger(error.status) ? error.status : 500;
  if (status >= 500) console.error(error);
  return res.status(status).json({
    error: { message: status >= 500 ? 'Internal server error.' : error.message },
  });
}

module.exports = { HttpError, notFound, errorHandler };
