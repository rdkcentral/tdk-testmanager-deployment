/*
* If not stated otherwise in this file or this component's LICENSE file the
* following copyright and licenses apply:
*
* Copyright 2025 RDK Management
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*
http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

/**
 * API server for TDK UI Upgrade
 *
 * Provides endpoints to upload, extract, and deploy new UI builds,
 * as well as view deployment logs.
 */
const express = require("express");
const multer = require("multer");
const path = require("path");
const { exec, spawn } = require("child_process");
const fs = require("fs");

const app = express();
const port = 3000;

// CORS Middleware - Allow requests from Angular frontend
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.header(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization, X-Requested-With",
  );
  res.header("Access-Control-Allow-Credentials", "true");

  // Handle preflight requests
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});

// Middleware
app.use(express.json());

// Upload directory
const uploadDir = "/tmp/uploads";
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Allowed file extensions
const allowedExtensions = [".zip", ".tar.gz", ".tgz"];

// Multer storage + limits
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => cb(null, Date.now() + "-" + file.originalname),
});

const upload = multer({
  storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 🔐 10MB
    files: 1, // 🔐 Only one file
    fields: 10, // 🔐 Limit number of text fields
  },
  fileFilter: (req, file, cb) => {
    const ext = file.originalname;
    const isValid = allowedExtensions.some((e) => ext.endsWith(e));
    if (!isValid) return cb(new Error("Invalid file format"));
    cb(null, true);
  },
});

// ========== ✅ API 1: Upload and Extract Build ==========
app.post("/tdkUIUpgrade/uploadBuild", upload.single("build"), (req, res) => {
  if (!req.file) return res.status(400).json({ message: "No file uploaded." });

  const originalName = req.file.originalname;
  const ext = originalName.endsWith(".tar.gz")
    ? ".tar.gz"
    : originalName.endsWith(".tgz")
      ? ".tgz"
      : path.extname(originalName);

  const timestamp = new Date()
    .toISOString()
    .replace(/[:T]/g, "_")
    .split(".")[0];
  const buildFolder = `/mnt/appUpgrade/NewRelease_${timestamp}`;
  const targetPath = path.join(buildFolder, originalName);

  fs.mkdirSync(buildFolder, { recursive: true });
  fs.renameSync(req.file.path, targetPath);

  let extractCmd =
    ext === ".zip"
      ? `unzip -o "${targetPath}" -d "${buildFolder}"`
      : `tar -xzf "${targetPath}" -C "${buildFolder}"`;

  exec(extractCmd, (err, stdout, stderr) => {
    if (err) {
      console.error(stderr);
      return res
        .status(500)
        .json({ message: "Extraction failed", error: stderr });
    }

    try {
      fs.unlinkSync(targetPath); // Clean archive
    } catch (e) {
      console.warn(`Warning: Could not delete archive: ${e.message}`);
    }

    const extractedPath = path.join(buildFolder, "browser");
    if (
      !fs.existsSync(extractedPath) ||
      !fs.statSync(extractedPath).isDirectory()
    ) {
      return res.status(400).json({
        message: 'Build extracted, but required "browser" folder not found',
      });
    }

    res.json({
      message: "The build uploaded and extracted successfully",
      buildlocation: extractedPath,
    });
  });
});

// ========== ✅ API 2: Trigger Deployment ==========
app.post("/tdkUIUpgrade/upGradeApplication", (req, res) => {
  const uploadLocation = req.query.uploadLocation;
  const backupBasePath = req.query.backupPath || "/mnt/appUpgrade";
  const deployPath = "/var/www/html/";

  if (!uploadLocation || !fs.existsSync(uploadLocation)) {
    return res.status(400).json({ error: "Invalid upload location" });
  }

  const timestamp = new Date()
    .toISOString()
    .replace(/[:T]/g, "_")
    .split(".")[0];
  const backupPath = path.join(backupBasePath, `Backup_${timestamp}`);

  const deployScript = path.resolve("./deploy.sh");
  const cmd = `${deployScript} "${backupPath}" "${deployPath}" "${uploadLocation}"`;

  exec(cmd, (err, stdout, stderr) => {
    if (err) {
      console.error(`[ERROR]: ${stderr}`);
      return res.status(500).json({ status: "Upgrade failed", error: stderr });
    }

    console.log(stdout);
    res.json({ status: "App upgraded successfully" });
  });
});

// ========== ✅ API 3: View Latest Deployment Log ==========
app.get("/tdkUIUpgrade/deploymentLog", (req, res) => {
  const logPath = req.query.path;
  if (!logPath || !fs.existsSync(logPath)) {
    return res
      .status(400)
      .json({ error: "Invalid or missing path query parameter" });
  }

  try {
    const files = fs
      .readdirSync(logPath)
      .filter((f) => f.startsWith("deploy_") && f.endsWith(".log"))
      .sort();

    if (files.length === 0) {
      return res
        .status(404)
        .json({ message: "No log file found in the directory" });
    }

    const latestLogFile = path.join(logPath, files[files.length - 1]);
    const content = fs.readFileSync(latestLogFile, "utf8");

    res.json({
      logFile: latestLogFile,
      content,
    });
  } catch (err) {
    console.error(err);
    res
      .status(500)
      .json({ error: "Failed to read log file", details: err.message });
  }
});

// ========== ✅ API 4: Start Angular Build Generation ==========
// In-memory store for active build generation executions
const buildExecutions = new Map();

app.post("/tdkUIUpgrade/angularBuildGeneration", (req, res) => {
  const releaseTag = req.query.releaseTag;

  if (!releaseTag || releaseTag.trim() === "") {
    return res
      .status(400)
      .json({ error: "Release tag or branch name is required" });
  }

  const executionId =
    Date.now().toString(36) + "-" + Math.random().toString(36).substr(2, 9);
  const timestamp = new Date()
    .toISOString()
    .replace(/[:T]/g, "_")
    .split(".")[0];
  const upgradeDir = `/mnt/appUpgrade/AngularBuild_${timestamp}`;

  // Derive the correct backend/API URL and Node API URL so the built app
  // points to this deployment's actual host instead of the repo defaults.
  const apiUrl = process.env.BACKEND_URL || "";
  const nodeApiUrl = `${req.protocol}://${req.get("host")}/`;

  // Store execution metadata
  buildExecutions.set(executionId, {
    executionId,
    releaseTag,
    upgradeDir,
    apiUrl,
    nodeApiUrl,
    status: "RUNNING",
    process: null,
    createdAt: new Date(),
  });

  res.json({
    data: {
      executionId,
      status: "RUNNING",
      message: "Angular build generation started",
    },
    message: "Angular build generation started successfully",
  });
});

// ========== ✅ API 5: Stream Angular Build Generation Logs (SSE) ==========
app.get("/tdkUIUpgrade/angularBuildGeneration/logs", (req, res) => {
  const executionId = req.query.executionId;

  if (!executionId || !buildExecutions.has(executionId)) {
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.write(
      `event: error\ndata: ${JSON.stringify({ message: "Execution not found" })}\n\n`,
    );
    res.end();
    return;
  }

  const metadata = buildExecutions.get(executionId);

  // Set SSE headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders();

  // Send initial status
  res.write(
    `event: status\ndata: ${JSON.stringify({ message: "Starting Angular build generation for release: " + metadata.releaseTag })}\n\n`,
  );

  // Resolve script path - prefer the Node app directory so the runtime
  // can find the script immediately after deployment.
  let scriptPath = "";
  const possiblePaths = [
    path.resolve(__dirname, "angular_build_generation.sh"),
    path.resolve("./angular_build_generation.sh"),
    "/opt/tomcat/webapps/tdkservice/fileStore/angular_build_generation.sh",
  ];

  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      scriptPath = p;
      break;
    }
  }

  if (!scriptPath) {
    res.write(
      `event: error\ndata: ${JSON.stringify({ status: "ERROR", message: "Build generation script not found" })}\n\n`,
    );
    res.end();
    buildExecutions.delete(executionId);
    return;
  }

  // Create log directory
  const logDir = "/mnt/AngularBuild/logs";
  fs.mkdirSync(logDir, { recursive: true });
  const logTimestamp = new Date()
    .toISOString()
    .replace(/[:T]/g, "_")
    .split(".")[0];
  const logFilePath = path.join(logDir, `${logTimestamp}_AngularBuild.log`);
  const logStream = fs.createWriteStream(logFilePath, { flags: "a" });

  // Spawn the build script
  const child = spawn(
    "bash",
    [
      scriptPath,
      metadata.releaseTag,
      metadata.upgradeDir,
      metadata.apiUrl || "",
      metadata.nodeApiUrl || "",
    ],
    {
      cwd: path.dirname(scriptPath),
    },
  );

  metadata.process = child;

  // Stream stdout line by line
  let stdoutBuffer = "";
  child.stdout.on("data", (data) => {
    stdoutBuffer += data.toString();
    const lines = stdoutBuffer.split("\n");
    stdoutBuffer = lines.pop(); // Keep incomplete line in buffer
    lines.forEach((line) => {
      if (line.trim()) {
        res.write(`event: log\ndata: ${JSON.stringify({ message: line })}\n\n`);
        logStream.write(line + "\n");
      }
    });
  });

  // Stream stderr as log lines
  let stderrBuffer = "";
  child.stderr.on("data", (data) => {
    stderrBuffer += data.toString();
    const lines = stderrBuffer.split("\n");
    stderrBuffer = lines.pop();
    lines.forEach((line) => {
      if (line.trim()) {
        res.write(`event: log\ndata: ${JSON.stringify({ message: line })}\n\n`);
        logStream.write(line + "\n");
      }
    });
  });

  child.on("close", (exitCode) => {
    // Flush remaining buffer
    if (stdoutBuffer.trim()) {
      res.write(
        `event: log\ndata: ${JSON.stringify({ message: stdoutBuffer })}\n\n`,
      );
      logStream.write(stdoutBuffer + "\n");
    }
    if (stderrBuffer.trim()) {
      res.write(
        `event: log\ndata: ${JSON.stringify({ message: stderrBuffer })}\n\n`,
      );
      logStream.write(stderrBuffer + "\n");
    }

    logStream.end();

    if (exitCode === 0) {
      metadata.status = "COMPLETED";
      res.write(
        `event: complete\ndata: ${JSON.stringify({
          status: "SUCCESS",
          exitCode: exitCode,
          message: "Angular build generation completed successfully",
          releaseTag: metadata.releaseTag,
          upgradeDir: metadata.upgradeDir,
        })}\n\n`,
      );
    } else {
      metadata.status = "FAILED";
      res.write(
        `event: complete\ndata: ${JSON.stringify({
          status: "FAILED",
          exitCode: exitCode,
          message:
            "Angular build generation failed with exit code: " + exitCode,
          releaseTag: metadata.releaseTag,
        })}\n\n`,
      );
    }

    res.end();
    buildExecutions.delete(executionId);
  });

  child.on("error", (err) => {
    console.error(`[ERROR] Build generation process error: ${err.message}`);
    res.write(
      `event: error\ndata: ${JSON.stringify({ status: "ERROR", message: err.message })}\n\n`,
    );
    res.end();
    logStream.end();
    buildExecutions.delete(executionId);
  });

  // Handle client disconnect
  req.on("close", () => {
    if (child && !child.killed) {
      child.kill("SIGTERM");
      setTimeout(() => {
        if (!child.killed) child.kill("SIGKILL");
      }, 5000);
    }
    logStream.end();
  });
});

// ========== 🔐 Global Error Handling for Multer ==========
app.use((err, req, res, next) => {
  if (err.code === "LIMIT_FILE_SIZE") {
    return res.status(413).json({ error: "File too large. Max 10MB allowed." });
  }
  if (err.code === "LIMIT_FILE_COUNT") {
    return res
      .status(400)
      .json({ error: "Too many files. Only 1 file allowed." });
  }
  if (err.code === "LIMIT_FIELD_COUNT") {
    return res.status(400).json({ error: "Too many fields. Limit is 10." });
  }
  if (err.message === "Invalid file format") {
    return res.status(400).json({ error: "Invalid file format" });
  }

  console.error(err);
  res
    .status(500)
    .json({ error: "Internal server error", details: err.message });
});

// ========== ✅ Start Server ==========
app.listen(port, () => {
  console.log(`API server listening on port ${port}`);
});
