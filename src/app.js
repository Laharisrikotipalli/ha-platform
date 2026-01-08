const express = require("express");
const { Pool } = require("pg");

const app = express();
const PORT = 3000;

// PostgreSQL connection using env vars from Kubernetes
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

// Home
app.get("/", (req, res) => {
  res.send("Web App is running 🚀");
});

// Health
app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

// Readiness
app.get("/ready", (req, res) => {
  res.status(200).send("READY");
});

// DB connectivity test
app.get("/db-test", async (req, res) => {
  try {
    const result = await pool.query("SELECT 1");
    res.json({
      message: "Database connected successfully ✅",
      result: result.rows,
    });
  } catch (error) {
    res.status(500).json({
      message: "Database connection failed ❌",
      error: error.message,
    });
  }
});

app.listen(3000, "0.0.0.0", () => {
  console.log("Server running on port 3000");
});

