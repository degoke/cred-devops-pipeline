const { Pool } = require('pg');

let pool;

function getPool() {
  if (!pool) {
    const connectionString = process.env.DATABASE_URL;

    pool = new Pool({
      connectionString,
      max: 5,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });
  }
  return pool;
}

async function getClient() {
  return getPool().connect();
}

async function query(text, params) {
  return getPool().query(text, params);
}

module.exports = {
  getClient,
  query,
};
