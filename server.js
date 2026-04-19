/**
 * V2C Project — 后端服务主入口
 * 平台：Jetson Orin Nano Super 8G + JetPack 6.1
 *
 * 功能：
 *   - 提供健康检查接口 GET /api/health
 *   - 提供 GPIO 触发接口 POST /api/trigger
 *   - 接收视觉端目标坐标（UDP 端口 9000）
 *   - 将控制指令转发给机器人控制端（TCP，端口 8888）
 *
 * 启动方式：
 *   node server.js
 *   或通过 systemd：sudo systemctl start v2c-backend
 */

'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const dgram = require('dgram');

// -------------------------------------------------------
// 从环境变量读取配置（中文键名，与 .env.example 一致）
// -------------------------------------------------------
const PORT        = parseInt(process.env['服务端口']    || process.env.PORT || '3000', 10);
const NODE_ENV    = process.env['运行环境']              || process.env.NODE_ENV || 'development';
const VISION_PORT = parseInt(process.env['Jetson数据端口'] || '9000', 10);
const CTRL_HOST   = process.env['控制端地址']            || '192.168.1.60';
const CTRL_PORT   = parseInt(process.env['控制端口']     || '8888', 10);
const LOG_LEVEL   = process.env['日志级别']              || 'info';

// -------------------------------------------------------
// 简易日志工具
// -------------------------------------------------------
function log(level, msg) {
  const levels = { error: 0, warn: 1, info: 2, debug: 3 };
  const configLevel = levels[LOG_LEVEL] !== undefined ? levels[LOG_LEVEL] : 2;
  if (levels[level] !== undefined && levels[level] <= configLevel) {
    const ts = new Date().toLocaleString('zh-CN', { hour12: false });
    console.log(`[${ts}] [${level.toUpperCase()}] ${msg}`);
  }
}

// -------------------------------------------------------
// 最近接收到的视觉数据（内存缓存，供 API 查询）
// -------------------------------------------------------
let latestVisionData = null;
let triggerCount     = 0;
const startTime      = Date.now();

// -------------------------------------------------------
// HTTP 请求路由
// -------------------------------------------------------
function handleRequest(req, res) {
  const url    = req.url.split('?')[0];
  const method = req.method.toUpperCase();

  log('debug', `${method} ${url}`);

  // CORS 头（允许局域网内任意来源访问）
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // --- GET / 返回前端展示页 ---
  if (method === 'GET' && (url === '/' || url === '/index.html')) {
    const htmlPath = path.join(__dirname, 'index.html');
    if (fs.existsSync(htmlPath)) {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.writeHead(200);
      fs.createReadStream(htmlPath).pipe(res);
    } else {
      sendJSON(res, 200, { name: 'V2C Project', status: 'running' });
    }
    return;
  }

  // --- GET /api/health 健康检查 ---
  if (method === 'GET' && url === '/api/health') {
    sendJSON(res, 200, {
      status:      'ok',
      message:     '服务运行正常',
      uptime_sec:  Math.floor((Date.now() - startTime) / 1000),
      env:         NODE_ENV,
      vision_port: VISION_PORT,
      ctrl_host:   CTRL_HOST,
      ctrl_port:   CTRL_PORT,
      latest_vision: latestVisionData,
    });
    return;
  }

  // --- GET /api/status 服务状态（同 health） ---
  if (method === 'GET' && url === '/api/status') {
    sendJSON(res, 200, {
      status:        'ok',
      trigger_count: triggerCount,
      latest_vision: latestVisionData,
    });
    return;
  }

  // --- POST /api/trigger GPIO 按键触发 ---
  if (method === 'POST' && url === '/api/trigger') {
    readBody(req, (body) => {
      triggerCount++;
      log('info', `GPIO 触发 #${triggerCount}，来源：${JSON.stringify(body)}`);
      // 此处可扩展：将触发指令转发给机器人控制端
      sendJSON(res, 200, {
        status:        'ok',
        message:       '触发成功',
        trigger_count: triggerCount,
        received:      body,
      });
    });
    return;
  }

  // --- POST /api/vision 视觉端数据上报（HTTP 备用，主路径为 UDP） ---
  if (method === 'POST' && url === '/api/vision') {
    readBody(req, (body) => {
      latestVisionData = { ...body, received_at: new Date().toISOString() };
      log('debug', `视觉数据更新：${JSON.stringify(latestVisionData)}`);
      sendJSON(res, 200, { status: 'ok' });
    });
    return;
  }

  // --- 404 ---
  sendJSON(res, 404, { status: 'error', message: `路径不存在：${url}` });
}

function sendJSON(res, code, obj) {
  const body = JSON.stringify(obj);
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.writeHead(code);
  res.end(body);
}

function readBody(req, cb) {
  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => {
    try {
      cb(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'));
    } catch (_) {
      cb({});
    }
  });
}

// -------------------------------------------------------
// UDP 服务器：接收视觉端目标坐标
// -------------------------------------------------------
const udpServer = dgram.createSocket('udp4');

udpServer.on('message', (msg, rinfo) => {
  try {
    const data = JSON.parse(msg.toString('utf8'));
    latestVisionData = { ...data, received_at: new Date().toISOString(), from: rinfo.address };
    log('debug', `UDP 视觉数据 from ${rinfo.address}:${rinfo.port} — ${JSON.stringify(data)}`);
    // 此处可扩展：根据视觉数据生成控制指令并发往机器人控制端
  } catch (_) {
    log('warn', `UDP 消息解析失败，原始内容：${msg.toString('utf8').substring(0, 80)}`);
  }
});

udpServer.on('error', (err) => {
  log('error', `UDP 服务器错误：${err.message}`);
});

udpServer.bind(VISION_PORT, () => {
  log('info', `UDP 视觉数据接收端口已就绪：${VISION_PORT}`);
});

// -------------------------------------------------------
// HTTP 服务器
// -------------------------------------------------------
const httpServer = http.createServer(handleRequest);

httpServer.listen(PORT, () => {
  log('info', '========================================');
  log('info', '  V2C Project 后端服务已启动');
  log('info', `  HTTP 端口：${PORT}`);
  log('info', `  UDP  端口：${VISION_PORT}（接收视觉数据）`);
  log('info', `  控制端：   ${CTRL_HOST}:${CTRL_PORT}`);
  log('info', `  运行环境：  ${NODE_ENV}`);
  log('info', `  健康检查：  http://127.0.0.1:${PORT}/api/health`);
  log('info', '========================================');
});

// -------------------------------------------------------
// 优雅退出
// -------------------------------------------------------
function shutdown(signal) {
  log('info', `收到 ${signal}，正在停止服务...`);
  httpServer.close(() => {
    udpServer.close(() => {
      log('info', '服务已安全退出');
      process.exit(0);
    });
  });
  setTimeout(() => process.exit(1), 8000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
