import express from "express";
import cors from "cors";
import helmet from "helmet";
import pg from "pg";
import admin from "firebase-admin";

const { Pool } = pg;
const app = express();
const port = Number(process.env.PORT || 8080);
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: process.env.PGSSLMODE === "require" ? { rejectUnauthorized: true } : undefined });

if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}

app.disable("x-powered-by");
app.use(helmet());
const origins = (process.env.CORS_ORIGINS || "*").split(",").map(value => value.trim());
app.use(cors({ origin: origins.includes("*") ? true : origins }));
app.use(express.json({ limit: "256kb" }));

const schema = `
CREATE TABLE IF NOT EXISTS profiles (
  user_id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  bio TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  book TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  post_type TEXT NOT NULL DEFAULT 'note' CHECK (post_type IN ('note','review')),
  rating SMALLINT CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS posts_created_at_idx ON posts(created_at DESC);
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS comments_post_created_idx ON comments(post_id, created_at);
CREATE TABLE IF NOT EXISTS post_likes (
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(post_id, user_id)
);
`;
await pool.query(schema);

async function requireUser(req, res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : "";
    if (!token || !admin.apps.length) return res.status(401).json({ error: "Sign-in required." });
    req.user = await admin.auth().verifyIdToken(token);
    next();
  } catch {
    res.status(401).json({ error: "Your sign-in has expired. Please sign in again." });
  }
}

function text(value, max) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}
async function ensureProfile(user) {
  const name = text(user.name || user.displayName || user.email?.split("@")[0] || "Reader", 60);
  await pool.query(
    "INSERT INTO profiles(user_id,name) VALUES($1,$2) ON CONFLICT(user_id) DO NOTHING",
    [user.uid, name]
  );
}

app.get("/healthz", async (_req, res) => {
  try { await pool.query("SELECT 1"); res.json({ ok: true, service: "folio-api" }); }
  catch { res.status(503).json({ ok: false }); }
});

app.get("/v1/posts", async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT p.id, p.title, p.book, p.body, p.post_type AS "postType", p.rating,
             p.created_at AS "createdAt", pr.name, '@' || regexp_replace(lower(pr.name), '[^a-z0-9]', '', 'g') AS handle,
             (SELECT COUNT(*)::int FROM post_likes l WHERE l.post_id=p.id) AS likes,
             LEFT(pr.name,1) AS mark
      FROM posts p JOIN profiles pr ON pr.user_id=p.author_id
      ORDER BY p.created_at DESC LIMIT 60`);
    res.json({ posts: result.rows });
  } catch { res.status(500).json({ error: "Couldn't load the reading room." }); }
});

app.post("/v1/posts", requireUser, async (req, res) => {
  const title = text(req.body?.title, 120);
  const book = text(req.body?.book, 180);
  const body = text(req.body?.body, 4000);
  const postType = req.body?.postType === "review" ? "review" : "note";
  const rating = postType === "review" ? Number(req.body?.rating) : null;
  if (!body || (postType === "review" && (!Number.isInteger(rating) || rating < 1 || rating > 5))) {
    return res.status(400).json({ error: "Add a note and a valid review rating." });
  }
  try {
    await ensureProfile({ ...req.user, name: text(req.body?.name, 60) || req.user.name });
    const result = await pool.query(
      "INSERT INTO posts(author_id,title,book,body,post_type,rating) VALUES($1,$2,$3,$4,$5,$6) RETURNING id",
      [req.user.uid, title || (postType === "review" ? "A reader's review" : "A reading note"), book, body, postType, rating]
    );
    res.status(201).json({ id: result.rows[0].id });
  } catch { res.status(500).json({ error: "Couldn't publish your note." }); }
});

app.get("/v1/posts/:id/comments", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT c.id,c.body,c.created_at AS "createdAt",p.name AS "displayName"
       FROM comments c JOIN profiles p ON p.user_id=c.author_id
       WHERE c.post_id=$1 ORDER BY c.created_at ASC LIMIT 100`, [req.params.id]);
    res.json({ comments: result.rows });
  } catch { res.status(404).json({ error: "Conversation not found." }); }
});

app.post("/v1/posts/:id/comments", requireUser, async (req, res) => {
  const body = text(req.body?.body, 2000);
  if (!body) return res.status(400).json({ error: "Write a comment first." });
  try {
    await ensureProfile(req.user);
    const result = await pool.query(
      "INSERT INTO comments(post_id,author_id,body) VALUES($1,$2,$3) RETURNING id",
      [req.params.id, req.user.uid, body]);
    res.status(201).json({ id: result.rows[0].id });
  } catch { res.status(404).json({ error: "Couldn't add a comment to that post." }); }
});

app.put("/v1/posts/:id/like", requireUser, async (req, res) => {
  try {
    await ensureProfile(req.user);
    await pool.query("INSERT INTO post_likes(post_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING", [req.params.id, req.user.uid]);
    const count = await pool.query("SELECT COUNT(*)::int AS likes FROM post_likes WHERE post_id=$1", [req.params.id]);
    res.json({ liked: true, likes: count.rows[0].likes });
  } catch { res.status(404).json({ error: "Post not found." }); }
});

app.delete("/v1/posts/:id/like", requireUser, async (req, res) => {
  try {
    await pool.query("DELETE FROM post_likes WHERE post_id=$1 AND user_id=$2", [req.params.id, req.user.uid]);
    const count = await pool.query("SELECT COUNT(*)::int AS likes FROM post_likes WHERE post_id=$1", [req.params.id]);
    res.json({ liked: false, likes: count.rows[0].likes });
  } catch { res.status(404).json({ error: "Post not found." }); }
});

app.get("/v1/profiles/:id", async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT name,bio,avatar_url AS "avatarURL" FROM profiles WHERE user_id=$1', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: "Reader not found." });
    res.json({ profile: result.rows[0] });
  } catch { res.status(500).json({ error: "Couldn't load this profile." }); }
});

app.put("/v1/me/profile", requireUser, async (req, res) => {
  const name = text(req.body?.name, 60);
  const bio = text(req.body?.bio, 240);
  const avatarURL = text(req.body?.avatarURL, 2048) || null;
  if (!name) return res.status(400).json({ error: "Add a reader name." });
  try {
    const result = await pool.query(
      `INSERT INTO profiles(user_id,name,bio,avatar_url,updated_at) VALUES($1,$2,$3,$4,NOW())
       ON CONFLICT(user_id) DO UPDATE SET name=EXCLUDED.name,bio=EXCLUDED.bio,avatar_url=EXCLUDED.avatar_url,updated_at=NOW()
       RETURNING name,bio`, [req.user.uid, name, bio, avatarURL]);
    res.json({ profile: result.rows[0] });
  } catch { res.status(500).json({ error: "Couldn't save your profile." }); }
});

app.listen(port, "0.0.0.0", () => console.log(`Folio API listening on :${port}`));
