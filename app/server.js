// ═══════════════════════════════════════════════════════════════
//  ADMIN FEEDBACK SYSTEM v2.4.1
//  Corporate Feedback Portal — Internal Use Only
//  ─────────────────────────────────────────────────────────────
//  WARNING: This application contains INTENTIONAL vulnerabilities
//  for CTF training purposes. DO NOT deploy in production.
// ═══════════════════════════════════════════════════════════════

const express = require('express');
const cookieParser = require('cookie-parser');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;
const LOG_DIR = process.env.LOG_DIR || '/opt/admin/logs';

// ──────────────────────────────────────────────
//  IN-MEMORY DATA STORES
// ──────────────────────────────────────────────
const sessions = {};
const feedbackStore = [];

// Pre-created admin session (simulates active admin)
// This is the session the "admin" uses — vulnerable to cookie replay
const ADMIN_SESSION_ID = 'adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e';
sessions[ADMIN_SESSION_ID] = {
  user: 'admin',
  authenticated: true,
  mfa_verified: true,
  created: Date.now()
};

// ──────────────────────────────────────────────
//  LOGGING UTILITIES
// ──────────────────────────────────────────────
function ensureLogDir() {
  try {
    if (!fs.existsSync(LOG_DIR)) {
      fs.mkdirSync(LOG_DIR, { recursive: true });
    }
  } catch (e) {
    console.error('Failed to create log directory:', e.message);
  }
}

function logToFile(filename, message) {
  ensureLogDir();
  try {
    fs.appendFileSync(path.join(LOG_DIR, filename), message + '\n');
  } catch (e) {
    console.error('Log write failed:', e.message);
  }
}

function logError(message, level = 'ERROR') {
  const timestamp = new Date().toISOString();
  logToFile('error.log', `[${timestamp}] [${level}] ${message}`);
}

function logSecurity(message, level = 'WARNING') {
  const timestamp = new Date().toISOString();
  logToFile('error.log', `[${timestamp}] [${level}] [SECURITY] ${message}`);
}

// ──────────────────────────────────────────────
//  GLOBAL MIDDLEWARE
// ──────────────────────────────────────────────

// FLAG: SCENARIO75{Node.js}
// Explicitly expose backend technology via X-Powered-By header
app.disable('x-powered-by');  // Remove Express default
app.use((req, res, next) => {
  res.setHeader('X-Powered-By', 'Node.js');
  next();
});

app.use(cookieParser());
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// ──────────────────────────────────────────────
//  SESSION COOKIE INITIALIZATION
// ──────────────────────────────────────────────
// FLAG: SCENARIO75{pre_mfa_session} (cookie name)
// FLAG: SCENARIO75{pending_mfa_verification} (cookie value)
// FLAG: SCENARIO75{False} (HttpOnly is False)
app.use((req, res, next) => {
  if (!req.cookies.pre_mfa_session && !req.cookies.session_id) {
    res.cookie('pre_mfa_session', 'pending_mfa_verification', {
      httpOnly: false,   // VULNERABILITY: HttpOnly = False
      path: '/',
      sameSite: 'Lax'
    });
  }
  next();
});

// ──────────────────────────────────────────────
//  STATIC FILES
// ──────────────────────────────────────────────
app.use('/public', express.static(path.join(__dirname, 'public')));

// FLAG: SCENARIO75{/api/verify-mfa} (disallowed path)
// FLAG: SCENARIO75{/dashboard} (admin area disclosed)
app.get('/robots.txt', (req, res) => {
  res.type('text/plain');
  res.send('User-agent: *\nDisallow: /api/verify-mfa\nDisallow: /dashboard\n');
});

// ──────────────────────────────────────────────
//  WAF MIDDLEWARE (Rudimentary)
// ──────────────────────────────────────────────
// FLAG: SCENARIO75{403} (WAF block status)
// FLAG: SCENARIO75{<svg>} (WAF bypass vector)
// FLAG: SCENARIO75{window['docu'+'ment']['coo'+'kie']} (obfuscation bypass)
function wafCheck(content) {
  if (!content) return { blocked: false };

  const str = typeof content === 'string' ? content : JSON.stringify(content);
  const lower = str.toLowerCase();

  // Block <script> tags — standard XSS prevention
  if (lower.includes('<script')) {
    return { blocked: true, reason: '<script> tag detected' };
  }

  // Block direct document.cookie access (but NOT bracket notation)
  // window['docu'+'ment']['coo'+'kie'] bypasses this check
  if (/document\.cookie/i.test(str)) {
    return { blocked: true, reason: 'document.cookie access detected' };
  }

  // NOTE: <svg>, <img>, <body> with event handlers are NOT blocked
  // This is the intentional WAF bypass vulnerability
  return { blocked: false };
}

// ──────────────────────────────────────────────
//  ROUTES — PUBLIC
// ──────────────────────────────────────────────

// Landing page (feedback submission form)
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

// Login page
app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'login.html'));
});

// Login API
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;

  if (username === 'admin' && password === 'admin_feedback_2024') {
    res.cookie('pre_mfa_session', 'pending_mfa_verification', {
      httpOnly: false,
      path: '/'
    });
    logError(`Successful login for user: ${username} from ${req.ip}`, 'INFO');
    return res.json({
      success: true,
      redirect: '/mfa',
      message: 'Credentials verified. MFA verification required.'
    });
  }

  logError(`Failed login attempt for user: ${username} from ${req.ip}`, 'WARNING');
  res.status(401).json({ success: false, message: 'Invalid credentials' });
});

// MFA page
app.get('/mfa', (req, res) => {
  if (req.cookies.pre_mfa_session !== 'pending_mfa_verification') {
    return res.redirect('/login');
  }
  res.sendFile(path.join(__dirname, 'views', 'mfa.html'));
});

// MFA verification API
// FLAG: SCENARIO75{/api/verify-mfa} (the endpoint that gets skipped)
app.post('/api/verify-mfa', (req, res) => {
  const { mfa_code } = req.body;
  const preMfaSession = req.cookies.pre_mfa_session;

  if (preMfaSession !== 'pending_mfa_verification') {
    logSecurity(`Invalid MFA session state from ${req.ip}`, 'WARNING');
    return res.status(403).json({ success: false, message: 'Invalid session state' });
  }

  // Valid MFA code for the lab
  if (mfa_code === '742856') {
    // FLAG: SCENARIO75{adm_sess} (session prefix)
    const sessionId = `adm_sess_${generateToken()}`;
    sessions[sessionId] = {
      user: 'admin',
      authenticated: true,
      mfa_verified: true,
      created: Date.now()
    };

    res.clearCookie('pre_mfa_session');
    res.cookie('session_id', sessionId, {
      httpOnly: false,   // VULNERABILITY: HttpOnly = False
      path: '/'
    });

    logError(`MFA verification successful for admin from ${req.ip}`, 'INFO');
    return res.json({ success: true, redirect: '/dashboard' });
  }

  logError(`Failed MFA attempt from ${req.ip}`, 'WARNING');
  res.status(401).json({ success: false, message: 'Invalid MFA code' });
});

// ──────────────────────────────────────────────
//  ROUTES — FEEDBACK
// ──────────────────────────────────────────────

// FLAG: SCENARIO75{POST} (required method — POST only, no GET handler)
// FLAG: SCENARIO75{fetch} (exfiltration mechanism)
app.post('/api/feedback', (req, res) => {
  const { message, name } = req.body;

  // WAF check on submitted content
  const wafResult = wafCheck(message);
  if (wafResult.blocked) {
    logSecurity(`WAF_BLOCK: Blocked payload from ${req.ip} - Reason: ${wafResult.reason}`, 'WARNING');
    return res.status(403).json({
      success: false,
      message: 'Forbidden — WAF blocked your request.'
    });
  }

  // VULNERABILITY: No sanitization — stored XSS
  feedbackStore.push({
    id: feedbackStore.length + 1,
    name: name || 'Anonymous',
    content: message,
    timestamp: new Date().toISOString(),
    ip: req.ip
  });

  logError(`Feedback submitted from ${req.ip}`, 'INFO');
  res.json({ success: true, message: 'Feedback submitted successfully. An admin will review it shortly.' });
});

// ──────────────────────────────────────────────
//  ROUTES — DASHBOARD (ADMIN)
// ──────────────────────────────────────────────

// FLAG: SCENARIO75{/dashboard} (admin area)
// FLAG: SCENARIO75{xss-payload} (CSS class for reflected XSS)
// FLAG: SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d} (final red flag)
app.get('/dashboard', (req, res) => {
  const sessionId = req.cookies.session_id;

  // ═══════════════════════════════════════════════
  //  CRITICAL VULNERABILITY: Session Replay / MFA Bypass
  //  ───────────────────────────────────────────────
  //  If the cookie value starts with 'adm_sess', the backend
  //  TRUSTS it entirely and NEVER calls /api/verify-mfa.
  //  This allows an attacker to replay a stolen admin cookie
  //  to gain full dashboard access without MFA.
  // ═══════════════════════════════════════════════
  if (sessionId && sessionId.startsWith('adm_sess')) {
    if (!sessions[sessionId]) {
      // Cookie replay detected — but the app trusts it anyway!
      logSecurity(`Cookie replay detected for session: ${sessionId} from ${req.ip}`, 'CRITICAL');
      logSecurity(`Authentication bypass anomaly - Session ${sessionId} used without MFA verification from ${req.ip}`, 'CRITICAL');

      // Create session from replayed cookie (the flaw)
      sessions[sessionId] = {
        user: 'admin',
        authenticated: true,
        mfa_verified: false,  // MFA was NOT actually verified
        created: Date.now(),
        replayed: true
      };
    }
    return res.sendFile(path.join(__dirname, 'views', 'dashboard.html'));
  }

  // No valid session — redirect to login
  res.redirect('/login');
});

// Dashboard API — returns stored feedback (requires admin session)
app.get('/api/admin/feedback', (req, res) => {
  const sessionId = req.cookies.session_id;

  if (sessionId && sessionId.startsWith('adm_sess')) {
    return res.json(feedbackStore);
  }

  res.status(401).json({ error: 'Unauthorized' });
});

// ──────────────────────────────────────────────
//  ROUTES — EXFILTRATION CATCHER
// ──────────────────────────────────────────────
// This endpoint exists to capture XSS cookie exfiltration attempts
// It simulates a real-world scenario where the attacker sends
// stolen data to a controlled endpoint
app.get('/api/catch', (req, res) => {
  const data = req.query.data;
  if (data) {
    logSecurity(`Exfiltration attempt captured: ${data} from ${req.ip}`, 'CRITICAL');
  }
  // Return 200 silently (attacker gets no useful error info)
  res.status(200).end();
});

// Catch-all for undefined routes
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

// ──────────────────────────────────────────────
//  HELPER FUNCTIONS
// ──────────────────────────────────────────────
function generateToken() {
  return Array.from({ length: 24 }, () =>
    Math.floor(Math.random() * 16).toString(16)
  ).join('');
}

// ──────────────────────────────────────────────
//  START SERVER
// ──────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[*] Admin Feedback System v2.4.1 running on port ${PORT}`);
  console.log(`[*] Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`[*] Log directory: ${LOG_DIR}`);
  logError(`Admin Feedback System started on port ${PORT}`, 'INFO');
});
