---
NPM-StatusList:
  - toProcess
Publish:
---
# Metadata
grok.com
[gitmoji \| An emoji guide for your commit messages](https://gitmoji.dev/)
[[opencommit]]
# Inhalt
## short input
```
Generate commit messages in Conventional Commits format: <gitmoji> <type>[scope]: <description>. Use these types and gitmojis: feat: ✨ (new feature), fix: 🐛 (bug fix), docs: 📝 (docs), style: 🧹 (style), refactor: ♻️ (refactor), test: ✅ (tests), chore: 🚧 (other). Scope is optional, lowercase or camelCase. Description: concise, present-tense, <50 chars, lowercase start unless proper noun. body: why, issue refs, verification steps, breaking changes; wrap at 72 chars, use bullets. Keep clear, professional, no vague terms like 'Update code' or code snippets. Examples: ✨ feat: add user login, 🐛 fix(ui): fix button alignment.
```
## long input
```
Generate commit messages in the Conventional Commits format, including a gitmoji, type, scope, and description. The format should be:\n\n<gitmoji> <type> scope: <description>\n\nFollowed by an body with more details.\n\nUse the following types and their corresponding gitmojis:\n\n- feat: ✨ (new feature)\n- fix: 🐛 (bug fix)\n- docs: 📝 (documentation changes)\n- style: 🧹 (code style changes)\n- refactor: ♻️ (code refactoring)\n- test: ✅ (adding tests)\n- chore: 🚧 (other changes, e.g., build, CI)\n\nInclude a scope in parentheses after the type if the change is specific to a particular module or feature. The scope should be lowercase or camelCase, depending on the project's convention.\n\nThe description should be a concise, present-tense summary of the change, less than 50 characters, starting with a lowercase letter unless it's a proper noun or acronym.\n\nThe body should provide additional details, such as:\n\n- Why the change was made\n- Any relevant issue numbers or references\n- Steps to verify the change or test the new functionality\n- Any breaking changes or backwards-incompatible changes\n- For complex changes, a step-by-step reasoning of the approach taken, any challenges faced, and how they were overcome\n\nEach line in the body should be wrapped at 72 characters. Use bullet points for clarity.\n\nEnsure that the commit message is clear, informative, and professional, using proper English and avoiding any sensitive information or informal language.\n\nAvoid common mistakes:\n\n- Vague descriptions like 'Update code' or 'Make changes'\n- Including full diff or code snippets in the commit message\n- Typos or grammatical errors\n\nExamples:\n\n- ✨ feat: Add user registration\n- 🐛 fix(login): Fix password validation\n- 📝 docs: Update README with new features\n- 🧹 style: Format code with Prettier\n- ♻️ refactor: Simplify user authentication logic\n- ✅ test: Add unit tests for login functionality\n- 🚧 chore: Update build scripts
```

