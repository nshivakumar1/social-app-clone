const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const winston = require('winston');
require('winston-elasticsearch');

// Configure Winston with Elasticsearch transport
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.Elasticsearch({
      index: 'social-app-logs',
      clientOpts: {
        node: process.env.ELASTICSEARCH_URL || 'http://elasticsearch.monitoring.svc.cluster.local:9200'
      }
    })
  ]
});

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"]
  }
});

console.log('🚀 Starting Social Media App Clone...');

// Security middleware
app.use(helmet({
  contentSecurityPolicy: false // Allow inline scripts for demo
}));
app.use(cors());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000 // Increased for demo
});
app.use(limiter);

app.use(express.json());
app.use(express.static('public'));

// In-memory storage (replace with database in production)
let posts = [
  {
    id: '1',
    content: 'Welcome to our amazing social media platform! 🎉',
    author: 'Social Team',
    timestamp: new Date(Date.now() - 3600000).toISOString(),
    likes: 42,
    comments: [
      {
        id: 'c1',
        author: 'John Doe',
        content: 'This is awesome!',
        timestamp: new Date(Date.now() - 1800000).toISOString()
      },
      {
        id: 'c2',
        author: 'Jane Smith',
        content: 'Love the design! 💖',
        timestamp: new Date(Date.now() - 900000).toISOString()
      }
    ],
    image: null
  },
  {
    id: '2',
    content: 'Just deployed our app to AWS! The cloud is amazing ☁️',
    author: 'DevOps Engineer',
    timestamp: new Date(Date.now() - 7200000).toISOString(),
    likes: 28,
    comments: [],
    image: null
  }
];

let users = new Map();
let onlineUsers = new Set();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    users: onlineUsers.size,
    posts: posts.length
  });
});

// API Routes
app.get('/api/posts', (req, res) => {
  // Sort posts by timestamp (newest first)
  const sortedPosts = posts.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  res.json(sortedPosts);
});

app.post('/api/posts', (req, res) => {
  const { content, author, image } = req.body;
  
  if (!content || !author) {
    return res.status(400).json({ error: 'Content and author are required' });
  }

  const post = {
    id: uuidv4(),
    content,
    author,
    timestamp: new Date().toISOString(),
    likes: 0,
    comments: [],
    image: image || null
  };

  posts.unshift(post); // Add to beginning
  io.emit('newPost', post);
  
  console.log(`📝 New post by ${author}: ${content.substring(0, 50)}...`);
  res.status(201).json(post);
});

app.post('/api/posts/:id/like', (req, res) => {
  const postId = req.params.id;
  const post = posts.find(p => p.id === postId);
  
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }

  post.likes++;
  io.emit('postLiked', { postId, likes: post.likes });
  
  console.log(`👍 Post ${postId} liked! Total: ${post.likes}`);
  res.json({ likes: post.likes });
});

app.post('/api/posts/:id/comments', (req, res) => {
  const postId = req.params.id;
  const { content, author } = req.body;
  const post = posts.find(p => p.id === postId);
  
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }

  if (!content || !author) {
    return res.status(400).json({ error: 'Content and author are required' });
  }

  const comment = {
    id: uuidv4(),
    content,
    author,
    timestamp: new Date().toISOString()
  };

  post.comments.push(comment);
  io.emit('newComment', { postId, comment });
  
  console.log(`💬 New comment by ${author} on post ${postId}`);
  res.status(201).json(comment);
});

app.delete('/api/posts/:id', (req, res) => {
  const postId = req.params.id;
  const postIndex = posts.findIndex(p => p.id === postId);
  
  if (postIndex === -1) {
    return res.status(404).json({ error: 'Post not found' });
  }

  posts.splice(postIndex, 1);
  io.emit('postDeleted', { postId });
  
  console.log(`🗑️ Post ${postId} deleted`);
  res.status(204).send();
});

// Get trending topics/hashtags
app.get('/api/trending', (req, res) => {
  const hashtags = {};
  posts.forEach(post => {
    const matches = post.content.match(/#\w+/g);
    if (matches) {
      matches.forEach(tag => {
        hashtags[tag] = (hashtags[tag] || 0) + 1;
      });
    }
  });
  
  const trending = Object.entries(hashtags)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 5)
    .map(([tag, count]) => ({ tag, count }));
    
  res.json(trending);
});

// User stats
app.get('/api/stats', (req, res) => {
  const totalLikes = posts.reduce((sum, post) => sum + post.likes, 0);
  const totalComments = posts.reduce((sum, post) => sum + post.comments.length, 0);
  
  res.json({
    totalPosts: posts.length,
    totalLikes,
    totalComments,
    onlineUsers: onlineUsers.size
  });
});

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log(`👤 User connected: ${socket.id}`);
  
  socket.on('joinRoom', (username) => {
    users.set(socket.id, username);
    onlineUsers.add(username);
    socket.broadcast.emit('userJoined', username);
    io.emit('userCountUpdate', onlineUsers.size);
    console.log(`✅ ${username} joined the chat`);
  });

  socket.on('userTyping', (data) => {
    socket.broadcast.emit('userTyping', data);
  });

  socket.on('disconnect', () => {
    const username = users.get(socket.id);
    if (username) {
      onlineUsers.delete(username);
      socket.broadcast.emit('userLeft', username);
      io.emit('userCountUpdate', onlineUsers.size);
      users.delete(socket.id);
      console.log(`👋 ${username} left the chat`);
    }
    console.log(`📱 User disconnected: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Social Media App running on port ${PORT}`);
  console.log(`📋 Health check: http://0.0.0.0:${PORT}/health`);
  console.log(`🌐 App: http://0.0.0.0:${PORT}`);
  console.log(`📊 Posts: ${posts.length}, Online: ${onlineUsers.size}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});