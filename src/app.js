const express = require('express');
const db = require('./db');
const logger = require('./logger');

const app = express();

app.use(express.json());

const startedAt = Date.now();

app.get('/health', (_req, res) => {
  logger.debug('Health check requested');
  res.status(200).json({ status: 'healthy' });
});

app.get('/status', async (_req, res) => {
  const uptimeMs = Date.now() - startedAt;
  const status = {
    status: 'ok',
    uptimeMs,
    version: process.env.APP_VERSION || '1.0.0',
    db: {
      connected: false,
    },
  };

  try {
    const client = await db.getClient();
    await client.query('SELECT 1');
    client.release();
    status.db.connected = true;
  } catch (err) {
    logger.error('Status check database connectivity failed', { error: err.message });
    status.db.connected = false;
    status.db.error = 'Database connection failed';
  }

  res.status(200).json(status);
});

app.post('/process', async (req, res) => {
  const { payload } = req.body || {};

  if (!payload) {
    logger.warn('Process called without payload');
    return res.status(400).json({ error: 'payload is required' });
  }

  const processed = {
    original: payload,
    length: String(payload).length,
    processedAt: new Date().toISOString(),
  };

  try {
    await db.query(
      'CREATE TABLE IF NOT EXISTS processed_items (id SERIAL PRIMARY KEY, payload TEXT NOT NULL, length INT NOT NULL, processed_at TIMESTAMPTZ NOT NULL)',
    );

    await db.query(
      'INSERT INTO processed_items (payload, length, processed_at) VALUES ($1, $2, $3)',
      [String(payload), processed.length, processed.processedAt],
    );
  } catch (err) {
    logger.error('Failed to persist processed item', { error: err.message });
    return res.status(500).json({ error: 'Failed to persist data' });
  }

  return res.status(200).json({ result: processed });
});

module.exports = app;
