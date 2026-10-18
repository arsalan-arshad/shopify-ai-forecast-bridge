import { Readable } from 'node:stream';

/**
 * Executes a simulated HTTP request against an Express app without opening network sockets.
 * Fully compatible with sandboxed execution and CI.
 */
export function simulateRequest(app, method, url, { headers = {}, body = null } = {}) {
  return new Promise((resolve, reject) => {
    let bodyBuffer = null;
    const reqHeaders = { ...headers };

    if (body !== null) {
      const bodyStr = typeof body === 'string' ? body : JSON.stringify(body);
      bodyBuffer = Buffer.from(bodyStr, 'utf8');
      if (!reqHeaders['content-type'] && !reqHeaders['Content-Type']) {
        reqHeaders['content-type'] = 'application/json';
      }
      reqHeaders['content-length'] = String(bodyBuffer.length);
    }

    // Create readable stream for request
    const req = new Readable({
      read() {
        if (bodyBuffer) {
          this.push(bodyBuffer);
          bodyBuffer = null;
        } else {
          this.push(null);
        }
      }
    });

    const mockSocket = {
      remoteAddress: '127.0.0.1',
      destroy() {},
      end() {},
      write() {},
      on() {},
      once() {},
      emit() {}
    };

    Object.assign(req, {
      method: method.toUpperCase(),
      url,
      headers: reqHeaders,
      connection: mockSocket,
      socket: mockSocket
    });

    let chunks = [];
    const resHeaders = {};

    const res = {
      statusCode: 200,
      headersSent: false,
      setHeader(name, val) {
        resHeaders[name.toLowerCase()] = val;
      },
      getHeader(name) {
        return resHeaders[name.toLowerCase()];
      },
      write(chunk) {
        if (chunk) chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
        return true;
      },
      end(chunk) {
        if (chunk) chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
        this.headersSent = true;
        const rawBody = Buffer.concat(chunks).toString('utf8');
        let json = null;
        try {
          json = JSON.parse(rawBody);
        } catch (_e) {
          // not json
        }

        resolve({
          status: this.statusCode,
          headers: resHeaders,
          body: rawBody,
          json
        });
      }
    };

    try {
      app.handle(req, res, (err) => {
        if (err) reject(err);
      });
    } catch (err) {
      reject(err);
    }
  });
}
