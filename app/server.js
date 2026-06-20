const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');
const winston = require('winston');
const jwt = require('jsonwebtoken');

const transports = [new winston.transports.Console()];
if (process.env.ELASTICSEARCH_URL) {
  require('winston-elasticsearch');
  transports.push(new winston.transports.Elasticsearch({
    index: 'social-app-logs',
    clientOpts: { node: process.env.ELASTICSEARCH_URL }
  }));
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports
});

const app = express();
const server = http.createServer(app);

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : ['http://localhost:3000'];

const io = socketIo(server, {
  cors: {
    origin: allowedOrigins,
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  }
});

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET && process.env.NODE_ENV === 'production') {
  logger.error('JWT_SECRET env var not set in production — exiting');
  process.exit(1);
}
const jwtSecret = JWT_SECRET || 'dev-only-secret-change-me';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com", "https://cdnjs.cloudflare.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com", "https://cdnjs.cloudflare.com", "data:"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      connectSrc: ["'self'", "ws:", "wss:"],
      imgSrc: ["'self'", "data:", "https:"],
      upgradeInsecureRequests: null,   // disabled — ALB runs HTTP only
    },
  },
}));

app.use(cors({
  origin: allowedOrigins,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  standardHeaders: true,
  legacyHeaders: false
});
app.use(globalLimiter);

const writeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, slow down' }
});

app.use(express.json({ limit: '10kb' }));
app.use(express.static('public'));

const MAX_POSTS = 1000;

let posts = [
  {
    id: '1',
    content: 'Welcome to our amazing social media platform!',
    author: 'Social Team',
    timestamp: new Date(Date.now() - 3600000).toISOString(),
    likes: 42,
    likedBy: new Set(),
    comments: [
      { id: 'c1', author: 'John Doe', content: 'This is awesome!', timestamp: new Date(Date.now() - 1800000).toISOString() },
      { id: 'c2', author: 'Jane Smith', content: 'Love the design!', timestamp: new Date(Date.now() - 900000).toISOString() }
    ],
    image: null
  },
  {
    id: '2',
    content: 'Just deployed our app to AWS! The cloud is amazing',
    author: 'DevOps Engineer',
    timestamp: new Date(Date.now() - 7200000).toISOString(),
    likes: 28,
    likedBy: new Set(),
    comments: [],
    image: null
  }
];

let users = new Map();
let onlineUsers = new Set();

function serializePost(post) {
  const { likedBy, ...rest } = post;
  return rest;
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Authentication required' });
  jwt.verify(token, jwtSecret, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid or expired token' });
    req.user = user;
    next();
  });
}

function validateUsername(username) {
  if (!username || typeof username !== 'string') return 'Username required';
  const trimmed = username.trim();
  if (trimmed.length < 1 || trimmed.length > 30) return 'Username must be 1-30 characters';
  if (!/^[a-zA-Z0-9 _.-]+$/.test(trimmed)) return 'Username contains invalid characters';
  return null;
}

app.post('/api/auth/join', writeLimiter, (req, res) => {
  const error = validateUsername(req.body.username);
  if (error) return res.status(400).json({ error });
  const username = req.body.username.trim();
  const token = jwt.sign({ username }, jwtSecret, { expiresIn: '24h' });
  res.json({ token, username });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    users: onlineUsers.size,
    posts: posts.length
  });
});

app.get('/api/posts', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 20, 50);
  const offset = Math.max(parseInt(req.query.offset) || 0, 0);
  const sorted = [...posts].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  const page = sorted.slice(offset, offset + limit).map(serializePost);
  res.json({ posts: page, total: posts.length, hasMore: offset + limit < posts.length });
});

app.post('/api/posts', authenticateToken, writeLimiter, (req, res) => {
  const { content, image } = req.body;
  if (!content || typeof content !== 'string' || content.trim().length === 0) {
    return res.status(400).json({ error: 'Content is required' });
  }
  if (content.length > 500) {
    return res.status(400).json({ error: 'Content must be 500 characters or less' });
  }

  const post = {
    id: uuidv4(),
    content: content.trim(),
    author: req.user.username,
    timestamp: new Date().toISOString(),
    likes: 0,
    likedBy: new Set(),
    comments: [],
    image: image || null
  };

  posts.unshift(post);
  if (posts.length > MAX_POSTS) posts = posts.slice(0, MAX_POSTS);

  const serialized = serializePost(post);
  io.emit('newPost', serialized);
  logger.info('New post', { author: req.user.username });
  res.status(201).json(serialized);
});

app.post('/api/posts/:id/like', authenticateToken, writeLimiter, (req, res) => {
  const post = posts.find(p => p.id === req.params.id);
  if (!post) return res.status(404).json({ error: 'Post not found' });

  const username = req.user.username;
  if (post.likedBy.has(username)) {
    post.likedBy.delete(username);
    post.likes = Math.max(0, post.likes - 1);
  } else {
    post.likedBy.add(username);
    post.likes++;
  }

  const liked = post.likedBy.has(username);
  io.emit('postLiked', { postId: post.id, likes: post.likes });
  res.json({ likes: post.likes, liked });
});

app.post('/api/posts/:id/comments', authenticateToken, writeLimiter, (req, res) => {
  const post = posts.find(p => p.id === req.params.id);
  if (!post) return res.status(404).json({ error: 'Post not found' });

  const { content } = req.body;
  if (!content || typeof content !== 'string' || content.trim().length === 0) {
    return res.status(400).json({ error: 'Comment content is required' });
  }
  if (content.length > 200) {
    return res.status(400).json({ error: 'Comment must be 200 characters or less' });
  }

  const comment = {
    id: uuidv4(),
    content: content.trim(),
    author: req.user.username,
    timestamp: new Date().toISOString()
  };

  post.comments.push(comment);
  io.emit('newComment', { postId: post.id, comment });
  res.status(201).json(comment);
});

app.delete('/api/posts/:id', authenticateToken, (req, res) => {
  const idx = posts.findIndex(p => p.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'Post not found' });

  if (posts[idx].author !== req.user.username) {
    return res.status(403).json({ error: "Cannot delete another user's post" });
  }

  posts.splice(idx, 1);
  io.emit('postDeleted', { postId: req.params.id });
  logger.info('Post deleted', { postId: req.params.id, author: req.user.username });
  res.status(204).send();
});

app.get('/api/trending', (req, res) => {
  const hashtags = {};
  posts.forEach(post => {
    const matches = post.content.match(/#\w+/g);
    if (matches) {
      matches.forEach(tag => {
        const lower = tag.toLowerCase();
        hashtags[lower] = (hashtags[lower] || 0) + 1;
      });
    }
  });

  const trending = Object.entries(hashtags)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5)
    .map(([tag, count]) => ({ tag, count }));

  res.json(trending);
});

app.get('/api/stats', (req, res) => {
  const totalLikes = posts.reduce((sum, p) => sum + p.likes, 0);
  const totalComments = posts.reduce((sum, p) => sum + p.comments.length, 0);
  res.json({ totalPosts: posts.length, totalLikes, totalComments, onlineUsers: onlineUsers.size });
});

io.on('connection', (socket) => {
  socket.on('joinRoom', (username) => {
    if (!username || typeof username !== 'string') return;
    const safe = username.substring(0, 30);
    users.set(socket.id, safe);
    onlineUsers.add(safe);
    socket.broadcast.emit('userJoined', safe);
    io.emit('userCountUpdate', onlineUsers.size);
  });

  socket.on('userTyping', (data) => {
    if (data && typeof data.username === 'string') {
      socket.broadcast.emit('userTyping', { username: data.username.substring(0, 30) });
    }
  });

  socket.on('disconnect', () => {
    const username = users.get(socket.id);
    if (username) {
      onlineUsers.delete(username);
      socket.broadcast.emit('userLeft', username);
      io.emit('userCountUpdate', onlineUsers.size);
      users.delete(socket.id);
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  logger.info(`Server running on port ${PORT}`);
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});
