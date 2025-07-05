# Claude Code Native Commands - Implementation Plan

## Overview
This plan details the step-by-step implementation of native Claude Code commands and hooks, designed for git commits and self-testing.

## Project Setup

### Initial Directory Structure
```bash
# Create base structure in your home directory
mkdir -p ~/.claude/{commands,hooks,lib,config,cache}

# Add cache and logs to gitignore (dotfiles tracks from $HOME)
echo ".claude/cache/" >> ~/.gitignore
echo ".claude/*.log" >> ~/.gitignore
```

## Milestone 1: Foundation & First Command
**Target: Day 1-2**

### Deliverables:
```
~/.claude/
├── commands/
│   └── analyze.md          # First working command
├── hooks/
│   ├── pre-bash.sh        # Basic validation hook
│   └── post-edit.sh       # Format hook
├── lib/
│   └── common.sh          # Shared functions
├── config/
│   └── patterns.json      # Initial patterns
└── README.md              # Documentation
```

### Implementation Steps:

#### 1.1 Create analyze.md
```markdown
---
name: analyze
description: Analyze code structure and patterns using ripgrep
author: SuperClaude Integration
version: 1.0.0
parameters:
  - name: path
    description: Path to analyze
    required: true
    default: "."
  - name: pattern
    description: Analysis pattern (security/performance/quality)
    required: false
    default: "quality"
tools:
  - Task
  - Bash
  - Read
---

# Analyze Command

Comprehensive code analysis using modern tools.

## Usage
\`\`\`
/analyze path=./src pattern=security
\`\`\`

## Implementation

Analyze the codebase for the specified pattern using ripgrep and provide insights.
```

#### 1.2 Create pre-bash.sh
```bash
#!/bin/bash
# Pre-bash hook: Validate and modernize commands

TOOL_INPUT="$1"

# Replace grep with rg
if echo "$TOOL_INPUT" | grep -qE '\bgrep\b'; then
    echo "🔄 Converting grep to ripgrep (rg)..."
    TOOL_INPUT=$(echo "$TOOL_INPUT" | sed -E 's/\bgrep\b/rg/g')
fi

# Replace find with fd
if echo "$TOOL_INPUT" | grep -qE '\bfind\s+\.|find\s+/'; then
    echo "🔄 Converting find to fd..."
    # Basic conversion rules
    TOOL_INPUT=$(echo "$TOOL_INPUT" | sed -E 's/find\s+(\S+)\s+-name/fd -p/g')
fi

echo "$TOOL_INPUT"
```

#### 1.3 Create Test Script
```bash
#!/bin/bash
# test-milestone-1.sh

echo "Testing Milestone 1: Foundation"

# Test analyze command exists
if [ -f ~/.claude/commands/analyze.md ]; then
    echo "✅ analyze.md exists"
else
    echo "❌ analyze.md missing"
    exit 1
fi

# Test hooks are executable
if [ -x ~/.claude/hooks/pre-bash.sh ]; then
    echo "✅ pre-bash.sh is executable"
else
    echo "❌ pre-bash.sh not executable"
    exit 1
fi

# Test grep/find conversion
TEST_OUTPUT=$(~/.claude/hooks/pre-bash.sh "grep -r TODO .")
if echo "$TEST_OUTPUT" | grep -q "rg"; then
    echo "✅ grep converted to rg"
else
    echo "❌ grep conversion failed"
    exit 1
fi

echo "🎉 Milestone 1 tests passed!"
```

### Dotfiles Commit:
```bash
# No need to cd ~ since dotfiles works from anywhere
dotfiles add .claude/commands/analyze.md
dotfiles add .claude/hooks/pre-bash.sh .claude/hooks/post-edit.sh
dotfiles add .claude/lib/common.sh
dotfiles add .claude/config/patterns.json
dotfiles add .claude/README.md
dotfiles commit -m "✨ feat(claude): Add analyze command and basic hooks

- Implement first native command: /analyze
- Add pre-bash hook for grep→rg conversion
- Add post-edit hook for formatting
- Create shared library structure

This establishes the foundation for Claude Code native commands
with modern tool usage (ripgrep, fd-find)."
dotfiles push
```

## Milestone 2: Core Commands Set
**Target: Day 3-5**

### Deliverables:
```
commands/
├── analyze.md     # ✓ (from M1)
├── build.md       # Smart build orchestration
├── test.md        # Intelligent test runner
├── search.md      # Advanced rg search
├── find.md        # fd-based file finding
└── chain.md       # Command composition
```

### Implementation Example - search.md:
```markdown
---
name: search
description: Advanced code search using ripgrep patterns
author: SuperClaude Integration
version: 1.0.0
parameters:
  - name: pattern
    description: Search pattern (regex supported)
    required: true
  - name: path
    description: Path to search
    default: "."
  - name: type
    description: File type filter
    required: false
tools:
  - Bash
  - Task
---

# Search Command

Powerful code search with ripgrep.

## Usage
\`\`\`
/search pattern="TODO|FIXME" type=py
/search pattern="console\.log" path=./src
\`\`\`

## Features
- Regex support
- Type filtering
- Context display
- Performance optimization
```

### Test Script:
```bash
#!/bin/bash
# test-milestone-2.sh

COMMANDS="analyze build test search find chain"
FAILED=0

for cmd in $COMMANDS; do
    if [ -f ~/.claude/commands/${cmd}.md ]; then
        echo "✅ ${cmd}.md exists"
    else
        echo "❌ ${cmd}.md missing"
        FAILED=$((FAILED + 1))
    fi
done

if [ $FAILED -eq 0 ]; then
    echo "🎉 All core commands present!"
else
    echo "❌ $FAILED commands missing"
    exit 1
fi
```

### Dotfiles Commit:
```bash
dotfiles add .claude/commands/build.md
dotfiles add .claude/commands/test.md
dotfiles add .claude/commands/search.md
dotfiles add .claude/commands/find.md
dotfiles add .claude/commands/chain.md
dotfiles commit -m "✨ feat(claude): Add core command set

- build: Smart build orchestration with dependency detection
- test: Intelligent test runner with affected file detection  
- search: Advanced ripgrep integration with patterns
- find: fd-based file discovery with filters
- chain: Command composition with context preservation

All commands use modern tools (rg, fd) and support chaining."
dotfiles push
```

## Milestone 3: Advanced Hooks
**Target: Day 6-7**

### Deliverables:
```
hooks/
├── pre-bash.sh         # ✓ Enhanced
├── post-bash.sh        # Result formatting
├── pre-edit.sh         # Edit validation
├── post-edit.sh        # ✓ Enhanced with biome/ruff
├── pre-read.sh         # Security checks
├── git-commit-msg.sh   # Conventional commits
└── notification.sh     # Status updates
```

### Implementation - git-commit-msg.sh:
```bash
#!/bin/bash
# Git commit message generator hook

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

# Only generate for new commits
if [ "$COMMIT_SOURCE" != "message" ]; then
    # Get staged diff
    DIFF=$(git diff --cached)
    
    # Escape for JSON
    DIFF_ESCAPED=$(echo "$DIFF" | jq -Rs .)
    
    # Create prompt
    PROMPT="Generate a conventional commit message with gitmoji based on these changes: $DIFF_ESCAPED

Use format: <emoji> <type>(<scope>): <description>

Types: feat(✨), fix(🐛), docs(📝), style(🧹), refactor(♻️), test(✅), chore(🚧)"

    # Call Claude
    claude-code ask "$PROMPT" > "$COMMIT_MSG_FILE"
fi
```

### Test Script:
```bash
#!/bin/bash
# test-milestone-3.sh

# Test all hooks exist and are executable
HOOKS="pre-bash post-bash pre-edit post-edit pre-read git-commit-msg notification"
for hook in $HOOKS; do
    if [ -x ~/.claude/hooks/${hook}.sh ]; then
        echo "✅ ${hook}.sh is executable"
    else
        echo "❌ ${hook}.sh missing or not executable"
        exit 1
    fi
done

# Test git commit hook
cd /tmp && git init test-repo && cd test-repo
ln -s ~/.claude/hooks/git-commit-msg.sh .git/hooks/prepare-commit-msg
echo "test" > file.txt
git add file.txt
git commit --dry-run

echo "🎉 Advanced hooks ready!"
```

### Dotfiles Commit:
```bash
dotfiles add .claude/hooks/
dotfiles commit -m "✨ feat(claude): Add advanced hook system

- Enhanced pre-bash with better grep/find conversion
- Post-bash for result formatting and caching
- Pre/post-edit with validation and auto-formatting
- Git commit message generation with conventional commits
- Security validation in pre-read hook

Hooks provide deterministic behavior across all operations."
dotfiles push
```

## Milestone 4: Pattern Library & Config
**Target: Day 8-9**

### Deliverables:
```
config/
├── patterns.json       # Comprehensive pattern library
├── defaults.json       # Command defaults
└── hooks.json         # Hook configuration

lib/
├── patterns.sh        # Pattern utilities
├── filters.sh         # fd filters
├── validators.sh      # Input validation
└── formatters.sh      # Output formatting
```

### Implementation - patterns.json:
```json
{
  "version": "1.0.0",
  "patterns": {
    "security": {
      "description": "Security vulnerability patterns",
      "patterns": {
        "secrets": {
          "regex": "(?i)(api[_-]?key|secret|token|password|pwd|auth)\\s*[:=]\\s*['\"][^'\"]+['\"]",
          "severity": "high",
          "message": "Potential hardcoded secret found"
        },
        "sql_injection": {
          "regex": "\\$_(GET|POST|REQUEST).*\\b(query|execute)\\b",
          "severity": "critical",
          "message": "Potential SQL injection vulnerability"
        }
      }
    },
    "performance": {
      "description": "Performance anti-patterns",
      "patterns": {
        "n_plus_one": {
          "regex": "\\.each.*\\.where|\\.map.*\\.find",
          "severity": "medium",
          "message": "Potential N+1 query pattern"
        }
      }
    }
  }
}
```

### Test Script:
```bash
#!/bin/bash
# test-milestone-4.sh

# Test pattern loading
if python3 -c "import json; json.load(open('$HOME/.claude/config/patterns.json'))"; then
    echo "✅ patterns.json is valid JSON"
else
    echo "❌ patterns.json invalid"
    exit 1
fi

# Test pattern usage
source ~/.claude/lib/patterns.sh
if load_patterns "security"; then
    echo "✅ Pattern loading works"
else
    echo "❌ Pattern loading failed"
    exit 1
fi

echo "🎉 Pattern library operational!"
```

## Milestone 5: Remaining Commands
**Target: Day 10-12**

### Deliverables:
All 19 commands implemented:
```
commands/
├── refactor.md    # Code refactoring
├── debug.md       # Debug assistance
├── document.md    # Documentation generation
├── review.md      # Code review
├── optimize.md    # Performance optimization
├── security.md    # Security scanning
├── migrate.md     # Code migration
├── scaffold.md    # Project scaffolding
├── clean.md       # Code cleanup
├── deploy.md      # Deployment help
├── monitor.md     # Monitoring setup
├── backup.md      # Backup management
└── restore.md     # Restore operations
```

## Milestone 6: Integration & Testing
**Target: Day 13-14**

### Complete Test Suite:
```bash
#!/bin/bash
# test-all.sh

echo "Running complete test suite..."

# Test all commands
./tests/test-commands.sh

# Test all hooks
./tests/test-hooks.sh

# Test integration scenarios
./tests/test-integration.sh

# Test performance
./tests/test-performance.sh

echo "🎉 All tests passed!"
```

### Integration with Claude Code:
```bash
# Update settings.json
cat << EOF > ~/.claude/settings.json
{
  "model": "opus",
  "env": {
    "CLAUDE_COMMANDS_PATH": "$HOME/.claude/commands",
    "CLAUDE_HOOKS_PATH": "$HOME/.claude/hooks"
  },
  "hooks": {
    "preToolUse": ["$HOME/.claude/hooks/pre-*.sh"],
    "postToolUse": ["$HOME/.claude/hooks/post-*.sh"]
  }
}
EOF
```

## Milestone 7: Documentation & Release
**Target: Day 15**

### Deliverables:
```
docs/
├── README.md           # Main documentation
├── COMMANDS.md         # Command reference
├── HOOKS.md           # Hook documentation
├── PATTERNS.md        # Pattern guide
├── EXAMPLES.md        # Usage examples
└── CONTRIBUTING.md    # Contribution guide
```

## Final Dotfiles Integration

### Setup Script:
```bash
#!/bin/bash
# setup-claude-commands.sh

echo "Setting up Claude Code native commands..."

# Add to dotfiles (bare repo, works from anywhere)
dotfiles add .claude/
dotfiles commit -m "✨ feat: Add Claude Code native commands and hooks

Complete integration of SuperClaude functionality into Claude Code:
- 19 native slash commands with modern tool usage
- Advanced hook system for deterministic behavior  
- Git commit message generation
- Comprehensive pattern library
- Full test coverage

Ready for daily development workflow!"
dotfiles push

# Link git hooks globally
git config --global core.hooksPath ~/.claude/hooks

echo "✅ Setup complete! Try: /analyze or /search"
```

## Success Criteria

### Each Milestone Must:
1. **Pass all tests** before commit
2. **Include documentation** updates
3. **Maintain backwards compatibility**
4. **Use semantic commits** with gitmoji
5. **Be independently deployable**

### Performance Targets:
- Command response: < 500ms
- Pattern matching: > 10K files/sec
- Memory usage: < 100MB
- Cache hit rate: > 80%

## Rollback Plan

Each milestone can be reverted:
```bash
# Revert to previous milestone
dotfiles revert HEAD
dotfiles push

# Or remove specific files
dotfiles rm .claude/commands/problematic-command.md
dotfiles commit -m "⏪ revert: Remove problematic command"
dotfiles push
```

## Next Steps After Implementation

1. **Community Patterns**: Share and collect patterns
2. **Tool Integration**: VSCode, Vim, Emacs plugins
3. **Advanced Features**: AI-powered pattern generation
4. **Performance Tuning**: Optimize for large codebases

This implementation plan provides a clear, testable path to integrating SuperClaude's capabilities into Claude Code's native ecosystem.