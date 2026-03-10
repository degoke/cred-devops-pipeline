const request = require('supertest');
const app = require('../src/app');

jest.mock('../src/db', () => ({
  getClient: jest.fn().mockResolvedValue({
    query: jest.fn().mockResolvedValue({ rows: [{ '?column?': 1 }] }),
    release: jest.fn(),
  }),
  query: jest.fn().mockResolvedValue({ rows: [] }),
}));

describe('API endpoints', () => {
  it('GET /health should return healthy', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'healthy' });
  });

  it('GET /status should return ok with db info', async () => {
    const res = await request(app).get('/status');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.db).toBeDefined();
  });

  it('POST /process should validate payload', async () => {
    const res = await request(app).post('/process').send({});
    expect(res.statusCode).toBe(400);
  });

  it('POST /process should process payload', async () => {
    const res = await request(app).post('/process').send({ payload: 'hello' });
    expect(res.statusCode).toBe(200);
    expect(res.body.result).toBeDefined();
    expect(res.body.result.length).toBe(5);
  });
});
