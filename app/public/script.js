class SocialApp {
    constructor() {
        this.socket = io();
        this.username = '';
        this.posts = [];
        this.isTyping = false;
        
        this.init();
    }

    init() {
        this.setupSocketListeners();
        this.setupEventListeners();
        this.showWelcomeModal();
        this.updateStats();
        this.loadTrending();
    }

    setupSocketListeners() {
        // Connection events
        this.socket.on('connect', () => {
            console.log('✅ Connected to server');
            this.showToast('Connected to server', 'success');
        });

        this.socket.on('disconnect', () => {
            console.log('❌ Disconnected from server');
            this.showToast('Disconnected from server', 'error');
        });

        // Real-time events
        this.socket.on('newPost', (post) => {
            this.addPostToFeed(post, true);
            this.updateStats();
            this.addActivity(`📝 ${post.author} shared a new post`);
        });

        this.socket.on('postLiked', (data) => {
            this.updatePostLikes(data.postId, data.likes);
        });

        this.socket.on('newComment', (data) => {
            this.addCommentToPost(data.postId, data.comment);
            this.addActivity(`💬 ${data.comment.author} commented on a post`);
        });

        this.socket.on('userJoined', (username) => {
            this.addActivity(`👋 ${username} joined the community`);
            this.showToast(`${username} joined!`, 'info');
        });

        this.socket.on('userLeft', (username) => {
            this.addActivity(`👋 ${username} left the community`);
        });

        this.socket.on('userCountUpdate', (count) => {
            document.getElementById('online-users').textContent = count;
        });

        this.socket.on('userTyping', (data) => {
            this.showTypingIndicator(data.username);
        });
    }

    setupEventListeners() {
        // Welcome modal
        document.getElementById('join-btn').addEventListener('click', () => this.joinCommunity());
        document.getElementById('username-input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.joinCommunity();
        });

        // Post creation
        const postContent = document.getElementById('post-content');
        const postBtn = document.getElementById('post-btn');
        
        postContent.addEventListener('input', () => {
            this.updateCharCount();
            this.handleTyping();
        });
        
        postBtn.addEventListener('click', () => this.createPost());
        
        postContent.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
                this.createPost();
            }
        });

        // Auto-refresh data
        setInterval(() => {
            this.updateStats();
            this.loadTrending();
        }, 30000); // Every 30 seconds
    }

    showWelcomeModal() {
        document.getElementById('welcome-modal').style.display = 'flex';
    }

    joinCommunity() {
        const usernameInput = document.getElementById('username-input');
        const username = usernameInput.value.trim();
        
        if (!username) {
            this.showToast('Please enter your name', 'error');
            return;
        }

        if (username.length > 30) {
            this.showToast('Name must be 30 characters or less', 'error');
            return;
        }

        this.username = username;
        
        // Hide modal and show app
        document.getElementById('welcome-modal').style.display = 'none';
        document.querySelector('.post-creator').style.display = 'block';
        document.getElementById('username-display').textContent = username;
        
        // Join socket room
        this.socket.emit('joinRoom', username);
        
        // Load initial data
        this.loadPosts();
        
        this.showToast(`Welcome, ${username}!`, 'success');
    }

    async loadPosts() {
        try {
            const response = await fetch('/api/posts');
            if (!response.ok) throw new Error('Failed to load posts');
            
            this.posts = await response.json();
            this.renderPosts();
            this.hideLoading();
        } catch (error) {
            console.error('Error loading posts:', error);
            this.showToast('Failed to load posts', 'error');
            this.hideLoading();
        }
    }

    renderPosts() {
        const feed = document.getElementById('posts-feed');
        feed.innerHTML = '';
        
        if (this.posts.length === 0) {
            feed.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-comments fa-3x" style="color: var(--text-muted); margin-bottom: 16px;"></i>
                    <h3>No posts yet</h3>
                    <p>Be the first to share something!</p>
                </div>
            `;
            return;
        }

        this.posts.forEach(post => this.addPostToFeed(post, false));
    }

    addPostToFeed(post, prepend = false) {
        const feed = document.getElementById('posts-feed');
        const postElement = this.createPostElement(post);
        
        if (prepend) {
            feed.insertBefore(postElement, feed.firstChild);
        } else {
            feed.appendChild(postElement);
        }
    }

    createPostElement(post) {
        const postDiv = document.createElement('div');
        postDiv.className = 'post';
        postDiv.setAttribute('data-post-id', post.id);
        
        const timeAgo = this.formatTimeAgo(new Date(post.timestamp));
        const isMyPost = post.author === this.username;
        
        postDiv.innerHTML = `
            <div class="post-header">
                <div class="post-author-info">
                    <div class="post-author">${this.escapeHtml(post.author)}</div>
                    <div class="post-time">${timeAgo}</div>
                </div>
                ${isMyPost ? `<button class="post-menu" onclick="socialApp.deletePost('${post.id}')"><i class="fas fa-trash"></i></button>` : ''}
            </div>
            <div class="post-content">${this.formatPostContent(post.content)}</div>
            <div class="post-actions">
                <button class="action-btn like-btn" onclick="socialApp.likePost('${post.id}')">
                    <i class="fas fa-heart"></i>
                    <span class="like-count">${post.likes}</span>
                </button>
                <button class="action-btn" onclick="socialApp.toggleComments('${post.id}')">
                    <i class="fas fa-comment"></i>
                    <span>${post.comments.length}</span>
                </button>
                <button class="action-btn">
                    <i class="fas fa-share"></i>
                    Share
                </button>
            </div>
            <div class="comments-section" id="comments-${post.id}" style="display: none;">
                <div class="comments-list">
                    ${post.comments.map(comment => this.createCommentHTML(comment)).join('')}
                </div>
                <div class="comment-form">
                    <input type="text" class="comment-input" placeholder="Write a comment..." maxlength="200">
                    <button class="comment-btn" onclick="socialApp.addComment('${post.id}', this)">Post</button>
                </div>
            </div>
        `;
        
        // Add enter key listener for comment input
        const commentInput = postDiv.querySelector('.comment-input');
        commentInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.addComment(post.id, e.target.nextElementSibling);
            }
        });
        
        return postDiv;
    }

    createCommentHTML(comment) {
        const timeAgo = this.formatTimeAgo(new Date(comment.timestamp));
        return `
            <div class="comment">
                <div class="comment-header">
                    <span class="comment-author">${this.escapeHtml(comment.author)}</span>
                    <span class="comment-time">${timeAgo}</span>
                </div>
                <div class="comment-content">${this.escapeHtml(comment.content)}</div>
            </div>
        `;
    }

    async createPost() {
        const content = document.getElementById('post-content').value.trim();
        
        if (!content) {
            this.showToast('Please write something!', 'error');
            return;
        }

        if (!this.username) {
            this.showToast('Please join the community first', 'error');
            return;
        }

        try {
            const response = await fetch('/api/posts', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    content,
                    author: this.username
                })
            });

            if (!response.ok) throw new Error('Failed to create post');

            document.getElementById('post-content').value = '';
            this.updateCharCount();
            this.showToast('Post shared!', 'success');
            
        } catch (error) {
            console.error('Error creating post:', error);
            this.showToast('Failed to create post', 'error');
        }
    }

    async likePost(postId) {
        try {
            const response = await fetch(`/api/posts/${postId}/like`, {
                method: 'POST'
            });

            if (!response.ok) throw new Error('Failed to like post');
            
        } catch (error) {
            console.error('Error liking post:', error);
            this.showToast('Failed to like post', 'error');
        }
    }

    updatePostLikes(postId, likes) {
        const post = document.querySelector(`[data-post-id="${postId}"]`);
        if (post) {
            const likeCount = post.querySelector('.like-count');
            const likeBtn = post.querySelector('.like-btn');
            if (likeCount) {
                likeCount.textContent = likes;
                likeBtn.classList.add('liked');
                setTimeout(() => likeBtn.classList.remove('liked'), 300);
            }
        }
    }

    toggleComments(postId) {
        const commentsSection = document.getElementById(`comments-${postId}`);
        const isVisible = commentsSection.style.display !== 'none';
        commentsSection.style.display = isVisible ? 'none' : 'block';
    }

    async addComment(postId, buttonElement) {
        const input = buttonElement.previousElementSibling;
        const content = input.value.trim();
        
        if (!content) return;

        try {
            const response = await fetch(`/api/posts/${postId}/comments`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    content,
                    author: this.username
                })
            });

            if (!response.ok) throw new Error('Failed to add comment');

            input.value = '';
            
        } catch (error) {
            console.error('Error adding comment:', error);
            this.showToast('Failed to add comment', 'error');
        }
    }

    addCommentToPost(postId, comment) {
        const commentsSection = document.getElementById(`comments-${postId}`);
        if (commentsSection) {
            const commentsList = commentsSection.querySelector('.comments-list');
            const commentElement = document.createElement('div');
            commentElement.innerHTML = this.createCommentHTML(comment);
            commentsList.appendChild(commentElement.firstElementChild);
            
            // Update comment count
            const post = document.querySelector(`[data-post-id="${postId}"]`);
            const commentBtn = post.querySelector('.action-btn:nth-child(2) span');
            const currentCount = parseInt(commentBtn.textContent);
            commentBtn.textContent = currentCount + 1;
        }
    }

    async deletePost(postId) {
        if (!confirm('Are you sure you want to delete this post?')) return;

        try {
            const response = await fetch(`/api/posts/${postId}`, {
                method: 'DELETE'
            });

            if (!response.ok) throw new Error('Failed to delete post');

            const postElement = document.querySelector(`[data-post-id="${postId}"]`);
            if (postElement) {
                postElement.style.animation = 'fadeOut 0.3s ease-out';
                setTimeout(() => postElement.remove(), 300);
            }
            
            this.showToast('Post deleted', 'success');
            
        } catch (error) {
            console.error('Error deleting post:', error);
            this.showToast('Failed to delete post', 'error');
        }
    }

    async updateStats() {
        try {
            const response = await fetch('/api/stats');
            if (!response.ok) return;
            
            const stats = await response.json();
            
            document.getElementById('total-posts').textContent = stats.totalPosts;
            document.getElementById('total-likes').textContent = stats.totalLikes;
            document.getElementById('total-comments').textContent = stats.totalComments;
            document.getElementById('online-users').textContent = stats.onlineUsers;
            
        } catch (error) {
            console.error('Error updating stats:', error);
        }
    }

    async loadTrending() {
        try {
            const response = await fetch('/api/trending');
            if (!response.ok) return;
            
            const trending = await response.json();
            const container = document.getElementById('trending-topics');
            
            if (trending.length === 0) {
                container.innerHTML = '<div class="text-muted">No trending topics yet</div>';
                return;
            }
            
            container.innerHTML = trending.map(item => `
                <div class="trending-item">
                    <span class="hashtag">${item.tag}</span>
                    <span class="count">${item.count} posts</span>
                </div>
            `).join('');
            
        } catch (error) {
            console.error('Error loading trending:', error);
        }
    }

    updateCharCount() {
        const content = document.getElementById('post-content').value;
        const charCount = document.getElementById('char-count');
        const postBtn = document.getElementById('post-btn');
        
        charCount.textContent = `${content.length}/500`;
        postBtn.disabled = content.trim().length === 0 || content.length > 500;
        
        if (content.length > 450) {
            charCount.style.color = 'var(--warning-color)';
        } else if (content.length > 480) {
            charCount.style.color = 'var(--danger-color)';
        } else {
            charCount.style.color = 'var(--text-muted)';
        }
    }

    handleTyping() {
        if (!this.isTyping) {
            this.isTyping = true;
            this.socket.emit('userTyping', { username: this.username });
            
            setTimeout(() => {
                this.isTyping = false;
            }, 3000);
        }
    }

    showTypingIndicator(username) {
        this.addActivity(`✏️ ${username} is typing...`);
    }

    addActivity(message) {
        const feed = document.getElementById('activity-feed');
        const item = document.createElement('div');
        item.className = 'activity-item';
        item.textContent = message;
        
        feed.insertBefore(item, feed.firstChild);
        
        // Remove old items (keep last 10)
        while (feed.children.length > 10) {
            feed.removeChild(feed.lastChild);
        }
        
        // Auto-remove typing indicators
        if (message.includes('typing')) {
            setTimeout(() => {
                if (item.parentNode) {
                    item.remove();
                }
            }, 3000);
        }
    }

    hideLoading() {
        const loading = document.getElementById('loading');
        if (loading) loading.style.display = 'none';
    }

    showToast(message, type = 'info') {
        const container = document.getElementById('toast-container');
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        
        container.appendChild(toast);
        
        setTimeout(() => {
            toast.style.animation = 'toastSlideOut 0.3s ease-out';
            setTimeout(() => {
                if (toast.parentNode) {
                    container.removeChild(toast);
                }
            }, 300);
        }, 3000);
    }

    formatTimeAgo(date) {
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);
        
        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;
        
        return date.toLocaleDateString();
    }

    formatPostContent(content) {
        // Format hashtags
        content = content.replace(/#(\w+)/g, '<span class="hashtag">#$1</span>');
        
        // Format mentions
        content = content.replace(/@(\w+)/g, '<span class="mention">@$1</span>');
        
        // Format line breaks
        content = content.replace(/\n/g, '<br>');
        
        return content;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Add CSS for toast slide out animation
const style = document.createElement('style');
style.textContent = `
    @keyframes toastSlideOut {
        from { opacity: 1; transform: translateX(0); }
        to { opacity: 0; transform: translateX(100%); }
    }
    
    @keyframes fadeOut {
        from { opacity: 1; transform: scale(1); }
        to { opacity: 0; transform: scale(0.9); }
    }
    
    .hashtag { color: var(--primary-color); font-weight: 500; }
    .mention { color: var(--secondary-color); font-weight: 500; }
    
    .empty-state {
        text-align: center;
        padding: 60px 20px;
        color: var(--text-muted);
    }
`;
document.head.appendChild(style);

// Initialize the app
const socialApp = new SocialApp();

// Make it globally available for onclick handlers
window.socialApp = socialApp;