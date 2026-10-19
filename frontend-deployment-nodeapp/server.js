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
const MAX_ACTIVE_UPGRADE_JOBS = 1;
const activeUpgradeJobs = new Set();

function tryAcquireUpgradeJob() {
  if (activeUpgradeJobs.size >= MAX_ACTIVE_UPGRADE_JOBS) {
    return false;
  }
  activeUpgradeJobs.add("frontend-upgrade");
  return true;
}

function releaseUpgradeJob() {
  activeUpgradeJobs.delete("frontend-upgrade");
}

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
const terminalExecutions = new Map();
const TERMINAL_EXECUTION_TTL_MS = 5 * 60 * 1000;

function pruneTerminalExecutions() {
  const now = Date.now();
  for (const [executionId, metadata] of terminalExecutions.entries()) {
    if (!metadata.expiresAt || now >= metadata.expiresAt) {
      terminalExecutions.delete(executionId);
    }
  }
}

function scheduleTerminalExecutionCleanup(executionId) {
  const timeout = setTimeout(() => {
    terminalExecutions.delete(executionId);
  }, TERMINAL_EXECUTION_TTL_MS);

  timeout.unref();
  return timeout;
}

function writeSseEvent(res, eventName, payload) {
  if (!res || res.destroyed || res.writableEnded) {
    return;
  }

  res.write(`event: ${eventName}\ndata: ${JSON.stringify(payload)}\n\n`);
}

function enqueueExecutionEvent(metadata, eventName, payload) {
  metadata.outputBuffer = metadata.outputBuffer || [];
  metadata.outputBuffer.push({ event: eventName, payload });

  if (!metadata.subscribers) {
    metadata.subscribers = new Set();
  }

  metadata.subscribers.forEach((subscriber) => {
    writeSseEvent(subscriber, eventName, payload);
  });
}

function isProcessGroupAlive(pid) {
  if (!pid) {
    return false;
  }

  try {
    if (process.platform === "win32") {
      process.kill(pid, 0);
      return true;
    }

    process.kill(-pid, 0);
    return true;
  } catch (error) {
    if (error && error.code === "ESRCH") {
      return false;
    }
    return true;
  }
}

async function terminateBuildProcessGroup(metadata, signal = "SIGTERM") {
  const child = metadata && metadata.process;
  if (!child) {
    return true;
  }

  if (!isProcessGroupAlive(child.pid)) {
    return true;
  }

  try {
    const targetPid = process.platform === "win32" ? child.pid : -child.pid;
    process.kill(targetPid, signal);
  } catch (error) {
    if (error && error.code !== "ESRCH") {
      console.warn(
        "Could not terminate Angular build process group:",
        error.message,
      );
    }
  }

  const startedAt = Date.now();
  while (Date.now() - startedAt < 5000) {
    if (!isProcessGroupAlive(child.pid)) {
      return true;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  try {
    const targetPid = process.platform === "win32" ? child.pid : -child.pid;
    process.kill(targetPid, "SIGKILL");
  } catch (error) {
    if (error && error.code !== "ESRCH") {
      console.warn(
        "Could not force terminate Angular build process group:",
        error.message,
      );
    }
  }

  await new Promise((resolve) => setTimeout(resolve, 250));
  return !isProcessGroupAlive(child.pid);
}

async function finalizeBuildExecution(executionId, metadata, outcome) {
  if (!metadata || metadata.finalized) {
    return;
  }

  metadata.finalized = true;
  metadata.finished = false;
  metadata.expiresAt = Date.now() + TERMINAL_EXECUTION_TTL_MS;

  const terminated = await terminateBuildProcessGroup(metadata, "SIGTERM");

  if (!terminated) {
    metadata.status = "FAILED";
    metadata.terminationFailed = true;
    metadata.finished = true;
    const failureNote = {
      status: "ERROR",
      message:
        "Angular build process group did not terminate cleanly; release slot kept locked",
    };
    if (outcome && outcome.error) {
      outcome.error = failureNote;
    }
    if (!outcome || !outcome.complete) {
      outcome = { ...outcome, error: failureNote };
    }
    console.error(failureNote.message);
    return;
  }

  if (metadata.logStream && !metadata.logStream.closed) {
    try {
      metadata.logStream.end();
    } catch (error) {
      console.warn("Could not close Angular build log stream:", error.message);
    }
  }

  const subscribers = metadata.subscribers
    ? Array.from(metadata.subscribers)
    : [];

  const terminalEvents = [];
  if (outcome && outcome.error) {
    terminalEvents.push({ event: "error", payload: outcome.error });
  }

  if (outcome && outcome.complete) {
    terminalEvents.push({ event: "complete", payload: outcome.complete });
  }

  metadata.outputBuffer = metadata.outputBuffer || [];
  terminalEvents.forEach(({ event, payload }) => {
    metadata.outputBuffer.push({ event, payload });
    subscribers.forEach((subscriber) => {
      writeSseEvent(subscriber, event, payload);
    });
  });

  subscribers.forEach((subscriber) => subscriber.end());
  metadata.subscribers.clear();
  metadata.finished = true;
  releaseUpgradeJob();
  buildExecutions.delete(executionId);
  terminalExecutions.set(executionId, metadata);
  if (!metadata.cleanupTimer) {
    metadata.cleanupTimer = scheduleTerminalExecutionCleanup(executionId);
  }
  pruneTerminalExecutions();
}

function startAngularBuildExecution(executionId, metadata) {
  if (metadata.process) {
    return metadata.process;
  }

  metadata.outputBuffer = metadata.outputBuffer || [];
  metadata.subscribers = metadata.subscribers || new Set();

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
    metadata.status = "FAILED";
    const payload = {
      status: "ERROR",
      message: "Build generation script not found",
    };
    finalizeBuildExecution(executionId, metadata, {
      error: payload,
      complete: {
        ...payload,
        exitCode: 127,
        releaseTag: metadata.releaseTag,
      },
    });
    return null;
  }

  const logDir = "/mnt/AngularBuild/logs";
  fs.mkdirSync(logDir, { recursive: true });
  const logTimestamp = new Date()
    .toISOString()
    .replace(/[:T]/g, "_")
    .split(".")[0];
  const logFilePath = path.join(logDir, `${logTimestamp}_AngularBuild.log`);
  const logStream = fs.createWriteStream(logFilePath, { flags: "a" });
  metadata.logStream = logStream;

  logStream.on("error", (err) => {
    console.error(`[ERROR] Angular build log stream error: ${err.message}`);
    metadata.status = "FAILED";
    finalizeBuildExecution(executionId, metadata, {
      error: {
        status: "ERROR",
        message: `Build log write failed: ${err.message}`,
      },
      complete: {
        status: "FAILED",
        exitCode: 1,
        message:
          "Angular build generation failed because the log stream could not be written",
        releaseTag: metadata.releaseTag,
      },
    });
  });

  const child = spawn(
    "bash",
    [
      scriptPath,
      metadata.releaseTag,
      metadata.upgradeDir,
      metadata.apiUrl || "",
      metadata.nodeApiUrl || "",
      metadata.workDir || path.join("/mnt/AngularBuild", "fallback-build"),
    ],
    {
      cwd: path.dirname(scriptPath),
      detached: process.platform !== "win32",
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

  metadata.process = child;
  metadata.processGroupId = child.pid;
  let stdoutBuffer = "";
  let stderrBuffer = "";

  function emitLogLine(line) {
    if (!line || !line.trim()) {
      return;
    }

    enqueueExecutionEvent(metadata, "log", { message: line });
    logStream.write(line + "\n");
  }

  child.stdout.on("data", (data) => {
    stdoutBuffer += data.toString();
    const lines = stdoutBuffer.split("\n");
    stdoutBuffer = lines.pop();
    lines.forEach((line) => emitLogLine(line));
  });

  child.stderr.on("data", (data) => {
    stderrBuffer += data.toString();
    const lines = stderrBuffer.split("\n");
    stderrBuffer = lines.pop();
    lines.forEach((line) => emitLogLine(line));
  });

  child.on("close", (exitCode) => {
    if (metadata.finalized) {
      return;
    }

    if (stdoutBuffer.trim()) {
      emitLogLine(stdoutBuffer.trim());
    }
    if (stderrBuffer.trim()) {
      emitLogLine(stderrBuffer.trim());
    }

    metadata.status = exitCode === 0 ? "COMPLETED" : "FAILED";
    const completionPayload = {
      status: exitCode === 0 ? "SUCCESS" : "FAILED",
      exitCode,
      message:
        exitCode === 0
          ? "Angular build generation completed successfully"
          : `Angular build generation failed with exit code: ${exitCode}`,
      releaseTag: metadata.releaseTag,
      ...(exitCode === 0 ? { upgradeDir: metadata.upgradeDir } : {}),
    };

    finalizeBuildExecution(executionId, metadata, {
      complete: completionPayload,
    });
  });

  child.on("error", (err) => {
    if (metadata.finalized) {
      return;
    }

    console.error(`[ERROR] Build generation process error: ${err.message}`);
    metadata.status = "FAILED";
    finalizeBuildExecution(executionId, metadata, {
      error: { status: "ERROR", message: err.message },
      complete: {
        status: "FAILED",
        exitCode: 1,
        message: `Angular build generation failed: ${err.message}`,
        releaseTag: metadata.releaseTag,
      },
    });
  });

  return child;
}

app.post("/tdkUIUpgrade/angularBuildGeneration", async (req, res) => {
  const rawReleaseTag = req.query.releaseTag;

  if (typeof rawReleaseTag !== "string" || rawReleaseTag.trim() === "") {
    return res
      .status(400)
      .json({ error: "Release tag or branch name is required" });
  }

  if (!tryAcquireUpgradeJob()) {
    return res.status(429).json({
      error: `Another deployment job is already running. Please wait for it to finish.`,
    });
  }

  const releaseTag = rawReleaseTag.trim();

  const executionId =
    Date.now().toString(36) + "-" + Math.random().toString(36).substr(2, 9);
  const timestamp = new Date()
    .toISOString()
    .replace(/[:T]/g, "_")
    .split(".")[0];
  const upgradeDir = `/mnt/appUpgrade/AngularBuild_${timestamp}`;

  let metadata = null;

  try {
    const buildRoot = "/mnt/AngularBuild";
    fs.mkdirSync(buildRoot, { recursive: true });
    const workDir = fs.mkdtempSync(path.join(buildRoot, "build-"));

    const apiUrl = process.env.BACKEND_URL || "";
    const configuredNodeApiUrl =
      process.env.NODE_API_URL || process.env.PUBLIC_APPUPGRADE_URL || "";
    const nodeApiUrl = configuredNodeApiUrl
      ? configuredNodeApiUrl.replace(/\/$/, "") + "/"
      : `${req.protocol}://${req.get("host")}/appupgrade/`;

    metadata = {
      executionId,
      releaseTag,
      upgradeDir,
      workDir,
      apiUrl,
      nodeApiUrl,
      status: "RUNNING",
      process: null,
      createdAt: new Date(),
      outputBuffer: [],
      subscribers: new Set(),
    };

    buildExecutions.set(executionId, metadata);

    const child = startAngularBuildExecution(executionId, metadata);
    if (!child) {
      return res.status(500).json({
        error: "Angular build generation could not be started",
      });
    }

    res.json({
      data: {
        executionId,
        status: "RUNNING",
        message: "Angular build generation started",
      },
      message: "Angular build generation started successfully",
    });
  } catch (error) {
    const startupError =
      error && error.message ? error.message : "Unknown startup error";

    if (metadata && !metadata.finalized) {
      await finalizeBuildExecution(executionId, metadata, {
        error: {
          status: "ERROR",
          message: `Angular build generation startup failed: ${startupError}`,
        },
        complete: {
          status: "FAILED",
          exitCode: 1,
          message: `Angular build generation startup failed: ${startupError}`,
          releaseTag,
        },
      });
    } else if (!metadata) {
      releaseUpgradeJob();
    }

    return res.status(500).json({
      error: "Angular build generation could not be started",
      details: startupError,
    });
  }
});

// ========== ✅ API 5: Stream Angular Build Generation Logs (SSE) ==========
app.get("/tdkUIUpgrade/angularBuildGeneration/logs", (req, res) => {
  const executionId = req.query.executionId;
  const activeMetadata = buildExecutions.get(executionId);
  const terminalMetadata = !activeMetadata
    ? terminalExecutions.get(executionId)
    : null;

  if (!executionId || (!activeMetadata && !terminalMetadata)) {
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.write(
      `event: error\ndata: ${JSON.stringify({ message: "Execution not found" })}\n\n`,
    );
    res.end();
    return;
  }

  const metadata = activeMetadata || terminalMetadata;

  if (
    metadata &&
    metadata.finalized &&
    metadata.finished &&
    metadata.expiresAt &&
    Date.now() >= metadata.expiresAt
  ) {
    terminalExecutions.delete(executionId);
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.write(
      `event: error\ndata: ${JSON.stringify({ message: "Execution not found" })}\n\n`,
    );
    res.end();
    return;
  }

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders();

  metadata.subscribers = metadata.subscribers || new Set();
  metadata.outputBuffer = metadata.outputBuffer || [];

  if (!metadata.finished) {
    res.write(
      `event: status\ndata: ${JSON.stringify({ message: "Starting Angular build generation for release: " + metadata.releaseTag })}\n\n`,
    );
    metadata.subscribers.add(res);
    metadata.outputBuffer.forEach((entry) => {
      writeSseEvent(res, entry.event, entry.payload);
    });

    res.on("close", () => {
      metadata.subscribers.delete(res);
    });
    return;
  }

  metadata.outputBuffer.forEach((entry) => {
    writeSseEvent(res, entry.event, entry.payload);
  });
  res.end();
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
