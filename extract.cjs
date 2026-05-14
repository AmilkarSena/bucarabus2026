const fs = require('fs');
const path = 'C:\\Users\\dlast\\.gemini\\antigravity\\brain\\bdda9da4-ad90-4e5f-bc21-a6fc1a26b34a\\.system_generated\\logs\\overview.txt';
const content = fs.readFileSync(path, 'utf8');

const regex = /File Path: `file:\/\/\/c:\/Users\/dlast\/Documents\/previous_version\/vue-bucarabus\/src\/components\/modals\/RouteModal\.vue`[\s\S]*?The above content shows the entire, complete file contents of the requested file\./g;
let match;
let lastMatch;
while ((match = regex.exec(content)) !== null) {
  lastMatch = match[0];
}

if (lastMatch) {
  let lines = lastMatch.split('\n');
  let cleanLines = [];
  let recording = false;
  for (let line of lines) {
    if (line.includes('The following code has been modified')) {
      recording = true;
      continue;
    }
    if (line.includes('The above content shows the entire')) {
      recording = false;
      break;
    }
    if (recording) {
      // Remove line numbers "123: "
      cleanLines.push(line.replace(/^\d+:\s/, ''));
    }
  }
  fs.writeFileSync('src/components/modals/RouteModal.vue', cleanLines.join('\n'));
  console.log('Extracted successfully!');
} else {
  console.log('No complete dump found in log.');
}
