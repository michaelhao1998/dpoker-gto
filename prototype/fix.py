import os, json

filepath = r'C:\Users\michaellhao\CodeBuddy\DPoker\prototype\index.html'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

idx = content.find('FACING_ACTIONS')
if idx >= 0:
    print(f"FOUND at index {idx}")
    print(repr(content[idx:idx+500]))
else:
    print("NOT FOUND")
