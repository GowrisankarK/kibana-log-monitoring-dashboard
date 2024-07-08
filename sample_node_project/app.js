const http = require('http');
const winston = require('winston');

// Create a logger with a file transport
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.simple(),
  transports: [
    new winston.transports.File({ filename: 'app.log' }),
  ],
});

// Create a simple HTTP server
const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello, World!\n');

  // Log the request details
  logger.info(`Request received for ${req.url}`);
});

// Start the server and listen on port 3000
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logger.info(`Server is running on http://localhost:${PORT}`);
});
