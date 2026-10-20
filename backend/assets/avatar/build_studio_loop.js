const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs');

const avatarDir = 'd:\\latest_status_goo\\backend\\assets\\avatar';
const outLoop = path.join(avatarDir, 'studio_anchor_60s.mp4');

const f0 = path.join(avatarDir, 'studio_clean_0_closed.jpg').replace(/\\/g, '/');
const f1 = path.join(avatarDir, 'studio_clean_1_mid.jpg').replace(/\\/g, '/');
const f2 = path.join(avatarDir, 'studio_clean_2_open.jpg').replace(/\\/g, '/');

// Seamless speaking rhythm: closed -> mid -> open -> mid -> closed
const concatText = [
  `file '${f0}'\nduration 0.14`,
  `file '${f1}'\nduration 0.12`,
  `file '${f2}'\nduration 0.18`,
  `file '${f1}'\nduration 0.12`,
  `file '${f0}'\nduration 0.10`,
  `file '${f1}'\nduration 0.14`,
  `file '${f2}'\nduration 0.22`,
  `file '${f1}'\nduration 0.14`,
  `file '${f0}'\nduration 0.10`,
].join('\n') + `\nfile '${f0}'\n`;

const concatFile = path.join(avatarDir, 'studio_clean_concat.txt');
fs.writeFileSync(concatFile, concatText);

const args = [
  '-y', '-hide_banner', '-loglevel', 'error',
  '-f', 'concat', '-safe', '0', '-stream_loop', '55', '-i', concatFile,
  '-vf', 'scale=1080:1920:flags=lanczos',
  '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-pix_fmt', 'yuv420p', '-r', '25', '-t', '60',
  outLoop
];

console.log('Generating 60s clean full-bleed studio anchor video...');
execFile('D:/tools/ffmpeg/ffmpeg.exe', args, (err) => {
  if (err) {
    console.error('Failed:', err);
    process.exit(1);
  }
  console.log('Success! Clean full-screen studio anchor video created at:', outLoop);
});
