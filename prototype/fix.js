// Quick fix script: read FACING_ACTIONS section
const fs = require('fs');
const content = fs.readFileSync('C:\\Users\\michaellhao\\CodeBuddy\\DPoker\\prototype\\index.html', 'utf8');
const idx = content.indexOf('FACING_ACTIONS');
if (idx >= 0) {
  console.log("FOUND at index " + idx);
  console.log(JSON.stringify(content.substring(idx, 400)));
} else {
  console.log("NOT FOUND");
}
