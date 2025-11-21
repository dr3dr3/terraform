# GitHub Copilot Instructions

## Markdown Formatting Rules

When creating or editing Markdown files, follow these linting rules to ensure consistency and avoid common errors:

### Fenced Code Blocks

1. **Always surround fenced code blocks with blank lines** (MD031)
   - Add a blank line before the opening fence (\`\`\`)
   - Add a blank line after the closing fence (\`\`\`)
   
   ✅ Good:
   ```markdown
   Some text here.
   
   ```bash
   echo "hello"
   ```
   
   More text here.
   ```
   
   ❌ Bad:
   ```markdown
   Some text here.
   ```bash
   echo "hello"
   ```
   More text here.
   ```

2. **Always specify a language for fenced code blocks** (MD040)
   - Use appropriate language identifiers: `bash`, `python`, `javascript`, `text`, `json`, etc.
   - For plain text or pseudocode, use `text`
   
   ✅ Good:
   ````markdown
   ```bash
   npm install
   ```
   ````
   
   ❌ Bad:
   ````markdown
   ```
   npm install
   ```
   ````

### Lists

3. **Surround lists with blank lines** (MD032)
   - Add a blank line before the first list item
   - Add a blank line after the last list item
   
   ✅ Good:
   ```markdown
   Here are the steps:
   
   - First step
   - Second step
   - Third step
   
   Now continue with...
   ```
   
   ❌ Bad:
   ```markdown
   Here are the steps:
   - First step
   - Second step
   - Third step
   Now continue with...
   ```

### File Structure

4. **End files with a single newline character** (MD047)
   - Ensure the last line of the file is followed by exactly one newline
   - Most editors handle this automatically, but verify for generated content

### Nested Code Blocks in Lists

When including code blocks within numbered or bulleted lists, maintain proper indentation and blank lines:

✅ Good:
```markdown
1. First step description:

   ```bash
   command here
   ```

2. Second step description:
```

❌ Bad:
```markdown
1. First step description:
   ```bash
   command here
   ```

2. Second step description:
```

### Summary Checklist

When writing Markdown:

- [ ] Blank line before opening code fence
- [ ] Blank line after closing code fence
- [ ] Language specified for all code blocks
- [ ] Blank line before lists
- [ ] Blank line after lists
- [ ] File ends with single newline

### Quick Reference Table

| Rule | Code | What to Do |
|------|------|------------|
| Blank lines around fences | MD031 | Add blank lines before and after \`\`\` |
| Specify code language | MD040 | Add language after opening \`\`\` (bash, text, etc.) |
| Blank lines around lists | MD032 | Add blank lines before and after list blocks |
| Single trailing newline | MD047 | Ensure file ends with one newline |

These rules ensure markdown files are properly formatted and pass standard linting tools like markdownlint.
