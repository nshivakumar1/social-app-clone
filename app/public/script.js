class SocialApp {
    constructor() {
        this.socket = io();
        this.username = '';
        this.token = null;
        this.posts = [];
        this.isTyping = false;
        this.offset = 0;
        this.hasMore = true;
        this.loadingMore = false;

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
        this.socket.on('connect', () => {
            this.showToast('Connected to server', 'success');
        });

        this.socket.on('disconnect', () => {
            this.showToast('Disconnected from server', 'error');
        });

        this.socket.on('newPost', (post) => {
            this.posts.unshift(post);
            this.addPostToFeed(post, true);
            this.updateStats();
            this.addActivity(`${post.author} shared a new post`);
        });

        this.socket.on('postLiked', (data) => {
            const post = this.posts.find(p => p.id === data.postId);
            if (post) post.likes = data.likes;
            this.syncLikeCount(data.postId, data.likes);
        });

        this.socket.on('newComment', (data) => {
            const post = this.posts.find(p => p.id === data.postId);
            if (post) post.comments.push(data.comment);
            this.appendCommentToDOM(data.postId, data.comment);
            this.addActivity(`${data.comment.author} commented on a post`);
        });

        this.socket.on('userJoined', (username) => {
            this.addActivity(`${username} joined the community`);
            this.showToast(`${username} joined!`, 'info');
        });

        this.socket.on('userLeft', (username) => {
            this.addActivity(`${username} left the community`);
        });

        this.socket.on('userCountUpdate', (count) => {
            document.getElementById('online-users').textContent = count;
        });

        this.socket.on('userTyping', (data) => {
            this.showTypingIndicator(data.username);
        });

        this.socket.on('postDeleted', (data) => {
            this.posts = this.posts.filter(p => p.id !== data.postId);
            const el = document.querySelector(`[data-post-id="${data.postId}"]`);
            if (el) el.remove();
        });
    }

    setupEventListeners() {
        document.getElementById('join-btn').addEventListener('click', () => this.joinCommunity());
        document.getElementById('username-input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.joinCommunity();
        });

        const postContent = document.getElementById('post-content');
        postContent.addEventListener('input', () => {
            this.updateCharCount();
            this.handleTyping();
        });

        document.getElementById('post-btn').addEventListener('click', () => this.createPost());
        postContent.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) this.createPost();
        });

        // Event delegation — no more inline onclick handlers
        const feed = document.getElementById('posts-feed');
        feed.addEventListener('click', (e) => {
            const likeBtn = e.target.closest('.like-btn');
            const toggleBtn = e.target.closest('.comment-toggle-btn');
            const deleteBtn = e.target.closest('.delete-btn');
            const commentSubmit = e.target.closest('.comment-btn');

            if (likeBtn) this.likePost(likeBtn.dataset.postId);
            if (toggleBtn) this.toggleComments(toggleBtn.dataset.postId);
            if (deleteBtn) this.deletePost(deleteBtn.dataset.postId);
            if (commentSubmit) this.addComment(commentSubmit.dataset.postId, commentSubmit);
        });

        feed.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && e.target.classList.contains('comment-input')) {
                const postId = e.target.dataset.postId;
                const btn = e.target.nextElementSibling;
                this.addComment(postId, btn);
            }
        });

        document.getElementById('load-more-btn').addEventListener('click', () => {
            this.loadPosts(this.offset, true);
        });

        setInterval(() => {
            this.updateStats();
            this.loadTrending();
        }, 30000);
    }

    showWelcomeModal() {
        document.getElementById('welcome-modal').style.display = 'flex';
    }

    async joinCommunity() {
        const usernameInput = document.getElementById('username-input');
        const username = usernameInput.value.trim();

        if (!username) {
            this.showToast('Please enter your name', 'error');
            return;
        }

        try {
            const res = await fetch('/api/auth/join', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username })
            });

            if (!res.ok) {
                const err = await res.json();
                this.showToast(err.error || 'Failed to join', 'error');
                return;
            }

            const data = await res.json();
            this.token = data.token;
            this.username = data.username;

            document.getElementById('welcome-modal').style.display = 'none';
            document.querySelector('.post-creator').style.display = 'block';
            document.getElementById('username-display').textContent = this.username;
            const avatarEl = document.getElementById('creator-avatar');
            if (avatarEl) avatarEl.textContent = this.username[0].toUpperCase();

            this.socket.emit('joinRoom', this.username);
            this.loadPosts(0, false);
            this.showToast(`Welcome, ${this.username}!`, 'success');
        } catch {
            this.showToast('Failed to join — server error', 'error');
        }
    }

    authHeaders() {
        return {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.token}`
        };
    }

    async loadPosts(offset = 0, append = false) {
        if (this.loadingMore) return;
        this.loadingMore = true;

        try {
            const res = await fetch(`/api/posts?limit=20&offset=${offset}`);
            if (!res.ok) throw new Error('Failed to load posts');

            const data = await res.json();
            this.hasMore = data.hasMore;
            this.offset = offset + data.posts.length;

            const loadMoreBtn = document.getElementById('load-more-btn');
            loadMoreBtn.style.display = data.hasMore ? 'block' : 'none';

            if (append) {
                data.posts.forEach(post => this.addPostToFeed(post, false));
            } else {
                this.posts = data.posts;
                this.renderPosts();
            }

            this.hideLoading();
        } catch {
            this.showToast('Failed to load posts', 'error');
            this.hideLoading();
        } finally {
            this.loadingMore = false;
        }
    }

    renderPosts() {
        const feed = document.getElementById('posts-feed');
        feed.innerHTML = '';

        if (this.posts.length === 0) {
            feed.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-comments fa-3x"></i>
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
            const empty = feed.querySelector('.empty-state');
            if (empty) empty.remove();
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
                <div class="post-author-row">
                    <div class="avatar">${this.escapeHtml(post.author)[0].toUpperCase()}</div>
                    <div class="post-author-info">
                        <div class="post-author">${this.escapeHtml(post.author)}</div>
                        <div class="post-time">${timeAgo}</div>
                    </div>
                </div>
                ${isMyPost ? `<button class="post-menu delete-btn" data-post-id="${post.id}" aria-label="Delete post"><i class="fas fa-trash-can"></i></button>` : ''}
            </div>
            <div class="post-content">${this.formatPostContent(post.content)}</div>
            <div class="post-actions">
                <button class="action-btn like-btn" data-post-id="${post.id}" aria-label="Like post">
                    <i class="fas fa-heart"></i>
                    <span class="like-count">${post.likes}</span>
                </button>
                <button class="action-btn comment-toggle-btn" data-post-id="${post.id}" aria-label="Toggle comments">
                    <i class="fas fa-comment"></i>
                    <span class="comment-count">${post.comments.length}</span>
                </button>
            </div>
            <div class="comments-section" id="comments-${post.id}" style="display: none;">
                <div class="comments-list">
                    ${post.comments.map(c => this.createCommentHTML(c)).join('')}
                </div>
                <div class="comment-form">
                    <input type="text" class="comment-input" data-post-id="${post.id}" placeholder="Write a comment..." maxlength="200">
                    <button class="comment-btn" data-post-id="${post.id}">Post</button>
                </div>
            </div>
        `;

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

        const btn = document.getElementById('post-btn');
        btn.disabled = true;

        try {
            const res = await fetch('/api/posts', {
                method: 'POST',
                headers: this.authHeaders(),
                body: JSON.stringify({ content })
            });

            if (!res.ok) {
                const err = await res.json();
                this.showToast(err.error || 'Failed to create post', 'error');
                return;
            }

            document.getElementById('post-content').value = '';
            this.updateCharCount();
            this.showToast('Post shared!', 'success');
        } catch {
            this.showToast('Failed to create post', 'error');
        } finally {
            btn.disabled = false;
        }
    }

    async likePost(postId) {
        // Optimistic update
        const postEl = document.querySelector(`[data-post-id="${postId}"]`);
        const likeBtn = postEl && postEl.querySelector('.like-btn');
        const likeCount = postEl && postEl.querySelector('.like-count');
        const currentLikes = parseInt(likeCount && likeCount.textContent) || 0;
        const wasLiked = likeBtn && likeBtn.classList.contains('liked');

        if (likeCount) likeCount.textContent = wasLiked ? currentLikes - 1 : currentLikes + 1;
        if (likeBtn) likeBtn.classList.toggle('liked');

        try {
            const res = await fetch(`/api/posts/${postId}/like`, {
                method: 'POST',
                headers: this.authHeaders()
            });

            if (!res.ok) throw new Error('Like failed');

            const data = await res.json();
            if (likeCount) likeCount.textContent = data.likes;
            if (likeBtn) {
                likeBtn.classList.toggle('liked', data.liked);
            }
        } catch {
            // Revert on error
            if (likeCount) likeCount.textContent = currentLikes;
            if (likeBtn) likeBtn.classList.toggle('liked', wasLiked);
            this.showToast('Failed to like post', 'error');
        }
    }

    syncLikeCount(postId, likes) {
        const postEl = document.querySelector(`[data-post-id="${postId}"]`);
        if (!postEl) return;
        const likeCount = postEl.querySelector('.like-count');
        if (likeCount) likeCount.textContent = likes;
    }

    toggleComments(postId) {
        const section = document.getElementById(`comments-${postId}`);
        if (section) section.style.display = section.style.display !== 'none' ? 'none' : 'block';
    }

    async addComment(postId, buttonElement) {
        const form = buttonElement.closest('.comment-form');
        const input = form && form.querySelector('.comment-input');
        const content = input && input.value.trim();
        if (!content) return;

        buttonElement.disabled = true;

        try {
            const res = await fetch(`/api/posts/${postId}/comments`, {
                method: 'POST',
                headers: this.authHeaders(),
                body: JSON.stringify({ content })
            });

            if (!res.ok) {
                const err = await res.json();
                this.showToast(err.error || 'Failed to add comment', 'error');
                return;
            }

            input.value = '';
        } catch {
            this.showToast('Failed to add comment', 'error');
        } finally {
            buttonElement.disabled = false;
        }
    }

    appendCommentToDOM(postId, comment) {
        const section = document.getElementById(`comments-${postId}`);
        if (!section) return;

        const list = section.querySelector('.comments-list');
        const el = document.createElement('div');
        el.innerHTML = this.createCommentHTML(comment);
        list.appendChild(el.firstElementChild);

        const postEl = document.querySelector(`[data-post-id="${postId}"]`);
        const countEl = postEl && postEl.querySelector('.comment-count');
        if (countEl) countEl.textContent = parseInt(countEl.textContent) + 1;
    }

    async deletePost(postId) {
        if (!confirm('Delete this post?')) return;

        try {
            const res = await fetch(`/api/posts/${postId}`, {
                method: 'DELETE',
                headers: this.authHeaders()
            });

            if (!res.ok) {
                const err = await res.json();
                this.showToast(err.error || 'Failed to delete post', 'error');
                return;
            }

            this.posts = this.posts.filter(p => p.id !== postId);
            const el = document.querySelector(`[data-post-id="${postId}"]`);
            if (el) {
                el.style.animation = 'fadeOut 0.3s ease-out';
                setTimeout(() => el.remove(), 300);
            }
            this.showToast('Post deleted', 'success');
        } catch {
            this.showToast('Failed to delete post', 'error');
        }
    }

    async updateStats() {
        try {
            const res = await fetch('/api/stats');
            if (!res.ok) return;
            const stats = await res.json();
            document.getElementById('total-posts').textContent = stats.totalPosts;
            document.getElementById('total-likes').textContent = stats.totalLikes;
            document.getElementById('total-comments').textContent = stats.totalComments;
            document.getElementById('online-users').textContent = stats.onlineUsers;
        } catch { /* silent */ }
    }

    async loadTrending() {
        try {
            const res = await fetch('/api/trending');
            if (!res.ok) return;
            const trending = await res.json();
            const container = document.getElementById('trending-topics');

            if (trending.length === 0) {
                container.innerHTML = '<div class="text-muted">No trending topics yet</div>';
                return;
            }

            container.innerHTML = trending.map(item => `
                <div class="trending-item">
                    <span class="hashtag">${this.escapeHtml(item.tag)}</span>
                    <span class="count">${item.count} posts</span>
                </div>
            `).join('');
        } catch { /* silent */ }
    }

    updateCharCount() {
        const content = document.getElementById('post-content').value;
        const charCount = document.getElementById('char-count');
        const postBtn = document.getElementById('post-btn');

        charCount.textContent = `${content.length}/500`;
        postBtn.disabled = content.trim().length === 0 || content.length > 500;

        // Order matters: check higher threshold first
        if (content.length > 480) {
            charCount.style.color = 'var(--danger-color)';
        } else if (content.length > 450) {
            charCount.style.color = 'var(--warning-color)';
        } else {
            charCount.style.color = 'var(--text-muted)';
        }
    }

    handleTyping() {
        if (!this.isTyping) {
            this.isTyping = true;
            this.socket.emit('userTyping', { username: this.username });
            setTimeout(() => { this.isTyping = false; }, 3000);
        }
    }

    showTypingIndicator(username) {
        this.addActivity(`${this.escapeHtml(username)} is typing...`);
    }

    addActivity(message) {
        const feed = document.getElementById('activity-feed');
        const item = document.createElement('div');
        item.className = 'activity-item';
        item.textContent = message;

        feed.insertBefore(item, feed.firstChild);

        while (feed.children.length > 10) {
            feed.removeChild(feed.lastChild);
        }

        if (message.includes('typing')) {
            setTimeout(() => { if (item.parentNode) item.remove(); }, 3000);
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
            setTimeout(() => { if (toast.parentNode) container.removeChild(toast); }, 300);
        }, 3000);
    }

    formatTimeAgo(date) {
        const diffMs = Date.now() - date;
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
        // Escape first — then safe to inject span tags
        const escaped = this.escapeHtml(content);
        return escaped
            .replace(/#(\w+)/g, '<span class="hashtag">#$1</span>')
            .replace(/@(\w+)/g, '<span class="mention">@$1</span>')
            .replace(/\n/g, '<br>');
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

const style = document.createElement('style');
style.textContent = `
    @keyframes toastSlideOut {
        from { opacity: 1; transform: translateX(0); }
        to   { opacity: 0; transform: translateX(120%) scale(0.9); }
    }
    @keyframes fadeOut {
        from { opacity: 1; transform: translateY(0) scale(1); }
        to   { opacity: 0; transform: translateY(-8px) scale(0.95); }
    }
`;
document.head.appendChild(style);

const socialApp = new SocialApp();
