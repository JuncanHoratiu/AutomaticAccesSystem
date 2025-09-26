const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { createConnection, hashPassword, comparePassword } = require("./test");

const app = express();
const PORT = process.env.PORT || 3002;
const JWT_SECRET = "your_jwt_secret_key";

app.use(cors({
  origin: ['http://localhost', 'http://192.168.43.192'],
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

let dbConnection;

// Middleware global pentru injectarea conexiunii
app.use((req, res, next) => {
  req.db = dbConnection;
  next();
});

const initializeDatabase = async () => {
  try {
    dbConnection = await createConnection();
    console.log("✓ Connected to MySQL database");

    // Verifică și actualizează structura tabelului users
    await dbConnection.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL,
        password VARCHAR(255) NOT NULL,
        reset_code VARCHAR(6),
        reset_code_expires DATETIME,
        UNIQUE(email),
        UNIQUE(username)
      )
    `);

    // Verifică existența coloanelor pentru resetare parolă
    try {
      await dbConnection.query("SELECT reset_code, reset_code_expires FROM users LIMIT 1");
    } catch (e) {
      if (e.code === 'ER_BAD_FIELD_ERROR') {
        console.log("Adding missing password reset columns...");
        await dbConnection.query("ALTER TABLE users ADD COLUMN reset_code VARCHAR(6)");
        await dbConnection.query("ALTER TABLE users ADD COLUMN reset_code_expires DATETIME");
        console.log("✓ Added password reset columns");
      }
    }

    console.log("✓ Verified/updated database structure");
  } catch (error) {
    console.error("❌ Database connection failed:", error);
    process.exit(1);
  }
};

// Health Check
app.get("/health", (req, res) => {
  res.status(200).json({ status: "healthy", timestamp: new Date().toISOString() });
});

// Autentificare
app.post("/login", async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({
      error: "Username și parola sunt necesare",
      fields: { username: "string", password: "string" }
    });
  }

  try {
    const [users] = await req.db.query(
      "SELECT id, username, password FROM users WHERE username = ?",
      [username]
    );

    if (users.length === 0) {
      return res.status(401).json({ success: false, error: "Credentialele sunt invalide" });
    }

    const isPasswordValid = await comparePassword(password, users[0].password);
    if (!isPasswordValid) {
      return res.status(401).json({ success: false, error: "Credentialele sunt invalide" });
    }

    const token = jwt.sign({ id: users[0].id, username: users[0].username }, JWT_SECRET, { expiresIn: '1h' });

    res.json({ success: true, message: "Autentificare reușită", token });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ success: false, error: "Eroare server" });
  }
});

// Protejare endpoint
function authenticateJWT(req, res, next) {
  const token = req.headers["authorization"]?.split(" ")[1];

  if (!token) {
    return res.status(403).json({ message: "Acces interzis" });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ message: "Token invalid sau expirat" });
    }
    req.user = user;
    next();
  });
}

// Endpoint protejat
app.get("/protected", authenticateJWT, (req, res) => {
  res.status(200).json({ message: "Acces permis", user: req.user });
});

// Înregistrare utilizator
app.post("/users", async (req, res) => {
  const { username, password, email } = req.body;

  if (!username || !password || !email) {
    return res.status(400).json({
      error: "Toate câmpurile sunt necesare",
      fields: { username: "string", email: "string", password: "string" }
    });
  }

  try {
    const hashedPassword = await hashPassword(password);
    const [result] = await req.db.query(
      "INSERT INTO users (username, email, password) VALUES (?, ?, ?)",
      [username, email, hashedPassword]
    );

    res.status(201).json({
      id: result.insertId,
      username,
      email,
      message: "Utilizator creat cu succes"
    });
  } catch (error) {
    console.error("User creation error:", error);

    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: "Username-ul sau email-ul există deja" });
    }

    res.status(500).json({ error: "Crearea utilizatorului a eșuat" });
  }
});

// Cerere cod resetare parolă
app.post("/request-reset-code", async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email-ul este necesar"
      });
    }

    const resetCode = crypto.randomBytes(3).toString("hex").toUpperCase();
    const expirationTime = new Date(Date.now() + 15 * 60 * 1000); // 15 minute

    const [result] = await req.db.query(
      "UPDATE users SET reset_code = ?, reset_code_expires = ? WHERE email = ?",
      [resetCode, expirationTime, email]
    );

    if (result.affectedRows === 0) {
      return res.status(200).json({
        success: true,
        message: "Dacă acest email există în sistem, vei primi un cod de resetare"
      });
    }

    console.log(`Cod resetare generat pentru ${email}: ${resetCode}`);
    return res.status(200).json({
      success: true,
      message: "Codul de resetare a fost trimis pe email"
    });
  } catch (err) {
    console.error("Eroare la generarea codului:", err);
    return res.status(500).json({
      success: false,
      message: "Eroare server la generarea codului"
    });
  }
});

// Resetare parolă
app.post("/reset-password", async (req, res) => {
  try {
    const { email, code, newPassword } = req.body;
    if (!email || !code || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Toate câmpurile sunt necesare"
      });
    }

    const [resetCheck] = await req.db.query(
      "SELECT reset_code, reset_code_expires FROM users WHERE email = ?",
      [email]
    );

    if (resetCheck.length === 0) {
      return res.status(200).json({
        success: false,
        message: "Cod invalid sau expirat"
      });
    }

    const userToReset = resetCheck[0];
    const now = new Date();
    const expiresAt = new Date(userToReset.reset_code_expires);

    if (!userToReset.reset_code || userToReset.reset_code !== code.toUpperCase() || expiresAt < now) {
      return res.status(200).json({
        success: false,
        message: "Cod invalid sau expirat"
      });
    }

    const hashedPassword = await hashPassword(newPassword);
    await req.db.query(
      "UPDATE users SET password = ?, reset_code = NULL, reset_code_expires = NULL WHERE email = ?",
      [hashedPassword, email]
    );

    const [updatedUsers] = await req.db.query(
      "SELECT id, username FROM users WHERE email = ?",
      [email]
    );

    if (updatedUsers.length === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found"
      });
    }

    const updatedUser = updatedUsers[0];
    const token = jwt.sign({ id: updatedUser.id, username: updatedUser.username }, JWT_SECRET, { expiresIn: '1h' });

    return res.status(200).json({
      success: true,
      message: "Parola a fost resetată cu succes",
      token: token
    });

  } catch (err) {
    console.error("Eroare resetare parolă:", err);
    return res.status(500).json({
      success: false,
      message: "Eroare server"
    });
  }
});


// Pornire server
const startServer = async () => {
  await initializeDatabase();

  const server = app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📄 API Documentation: http://localhost:${PORT}`);
  });

  process.on("SIGINT", async () => {
    console.log("\nShutting down server...");
    await dbConnection.end();
    server.close(() => {
      console.log("✓ Server shutdown complete");
      process.exit(0);
    });
  });
};

startServer().catch(error => {
  console.error("Failed to start server:", error);
  process.exit(1);
});