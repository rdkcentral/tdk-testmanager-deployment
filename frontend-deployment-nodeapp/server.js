/*
* If not stated otherwise in this file or this component's Licenses.txt file the
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
const express = require('express');
const multer = require('multer');
const path = require('path');
const { exec } = require('child_process');
const fs = require('fs');
 
const app = express();
const port = 3000;
 
// Middleware
app.use(express.json());
 
// Upload directory
const uploadDir = '/tmp/uploads';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}
 
// Allowed file extensions
const allowedExtensions = ['.zip', '.tar.gz', '.tgz'];
 
// Multer storage + limits
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});
 
const upload = multer({
  storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 🔐 10MB
    files: 1,                   // 🔐 Only one file
    fields: 10                  // 🔐 Limit number of text fields
  },
  fileFilter: (req, file, cb) => {
    const ext = file.originalname;
    const isValid = allowedExtensions.some(e => ext.endsWith(e));
    if (!isValid) return cb(new Error('Invalid file format'));
    cb(null, true);
  }
});
 
// ========== ✅ API 1: Upload and Extract Build ==========
app.post('/tdkUIUpgrade/uploadBuild', upload.single('build'), (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'No file uploaded.' });
 
  const originalName = req.file.originalname;
  const ext = originalName.endsWith('.tar.gz') ? '.tar.gz' :
              originalName.endsWith('.tgz') ? '.tgz' :
              path.extname(originalName);
 
  const timestamp = new Date().toISOString().replace(/[:T]/g, '_').split('.')[0];
  const buildFolder = `/mnt/appUpgrade/NewRelease_${timestamp}`;
  const targetPath = path.join(buildFolder, originalName);
 
  fs.mkdirSync(buildFolder, { recursive: true });
  fs.renameSync(req.file.path, targetPath);
 
  let extractCmd = ext === '.zip'
    ? `unzip -o "${targetPath}" -d "${buildFolder}"`
    : `tar -xzf "${targetPath}" -C "${buildFolder}"`;
 
  exec(extractCmd, (err, stdout, stderr) => {
    if (err) {
      console.error(stderr);
      return res.status(500).json({ message: 'Extraction failed', error: stderr });
    }
 
    try {
      fs.unlinkSync(targetPath); // Clean archive
    } catch (e) {
      console.warn(`Warning: Could not delete archive: ${e.message}`);
    }
 
    const extractedPath = path.join(buildFolder, 'browser');
    if (!fs.existsSync(extractedPath) || !fs.statSync(extractedPath).isDirectory()) {
      return res.status(400).json({
        message: 'Build extracted, but required "browser" folder not found'
      });
    }
 
    res.json({
      message: 'The build uploaded and extracted successfully',
      buildlocation: extractedPath
    });
  });
});
 
// ========== ✅ API 2: Trigger Deployment ==========
app.post('/tdkUIUpgrade/upGradeApplication', (req, res) => {
  const uploadLocation = req.query.uploadLocation;
  const backupBasePath = req.query.backupPath || '/mnt/appUpgrade';
  const deployPath = '/var/www/html/';
 
  if (!uploadLocation || !fs.existsSync(uploadLocation)) {
    return res.status(400).json({ error: 'Invalid upload location' });
  }
 
  const timestamp = new Date().toISOString().replace(/[:T]/g, '_').split('.')[0];
  const backupPath = path.join(backupBasePath, `Backup_${timestamp}`);
 
  const deployScript = path.resolve('./deploy.sh');
  const cmd = `${deployScript} "${backupPath}" "${deployPath}" "${uploadLocation}"`;
 
  exec(cmd, (err, stdout, stderr) => {
    if (err) {
      console.error(`[ERROR]: ${stderr}`);
      return res.status(500).json({ status: 'Upgrade failed', error: stderr });
    }
 
    console.log(stdout);
    res.json({ status: 'App upgraded successfully' });
  });
});
 
// ========== ✅ API 3: View Latest Deployment Log ==========
app.get('/tdkUIUpgrade/deploymentLog', (req, res) => {
  const logPath = req.query.path;
  if (!logPath || !fs.existsSync(logPath)) {
    return res.status(400).json({ error: 'Invalid or missing path query parameter' });
  }
 
  try {
    const files = fs.readdirSync(logPath)
      .filter(f => f.startsWith('deploy_') && f.endsWith('.log'))
      .sort();
 
    if (files.length === 0) {
      return res.status(404).json({ message: 'No log file found in the directory' });
    }
 
    const latestLogFile = path.join(logPath, files[files.length - 1]);
    const content = fs.readFileSync(latestLogFile, 'utf8');
 
    res.json({
      logFile: latestLogFile,
      content
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to read log file', details: err.message });
  }
});
 
// ========== 🔐 Global Error Handling for Multer ==========
app.use((err, req, res, next) => {
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: 'File too large. Max 10MB allowed.' });
  }
  if (err.code === 'LIMIT_FILE_COUNT') {
    return res.status(400).json({ error: 'Too many files. Only 1 file allowed.' });
  }
  if (err.code === 'LIMIT_FIELD_COUNT') {
    return res.status(400).json({ error: 'Too many fields. Limit is 10.' });
  }
  if (err.message === 'Invalid file format') {
    return res.status(400).json({ error: 'Invalid file format' });
  }
 
  console.error(err);
  res.status(500).json({ error: 'Internal server error', details: err.message });
});
 
// ========== ✅ Start Server ==========
app.listen(port, () => {
  console.log(`API server listening on port ${port}`);
});