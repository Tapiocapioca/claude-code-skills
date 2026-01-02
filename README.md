# Claude Code Skills

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Skills](https://img.shields.io/badge/skills-1-blue.svg)](https://github.com/Tapiocapioca/claude-code-skills)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-purple.svg)](https://claude.com/code)

**Production-ready skills for Claude Code**

[Installation](#installation) | [Available Skills](#available-skills) | [Contributing](#contributing)

</div>

---

## Installation

### Option 1: Plugin Marketplace (Recommended)

```bash
/plugin marketplace add Tapiocapioca/claude-code-skills
```

### Option 2: Manual Clone

```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/Tapiocapioca/claude-code-skills.git
```

### Option 3: Single Skill

```bash
git clone https://github.com/Tapiocapioca/claude-code-skills.git
cp -r claude-code-skills/skills/web-to-rag ~/.claude/skills/
```

---

## Available Skills

| Skill | Description | Documentation |
|-------|-------------|---------------|
| **<a href="skills/web-to-rag/" target="_blank">web-to-rag</a>** | Scrape websites, YouTube, PDFs into local RAG | <a href="skills/web-to-rag/README.md" target="_blank">README</a> • <a href="skills/web-to-rag/PREREQUISITES.md" target="_blank">Prerequisites</a> |

> **Free to test!** Try `web-to-rag` without cost using <a href="https://platform.iflow.cn/en/models" target="_blank">iFlow Platform</a> (free tier). <a href="https://iflow.cn/oauth?redirect=https%3A%2F%2Fvibex.iflow.cn%2Fsession%2Fsso_login" target="_blank">Sign up here</a>. Get API key: <a href="https://platform.iflow.cn/profile?tab=apiKey" target="_blank">direct link</a>.
>
> ⚠️ **Tip:** If the site displays in English, the user menu may be hidden. Use the direct link above.

Each skill is **self-contained** with its own prerequisites, infrastructure, and documentation.

---

## Repository Structure

```
claude-code-skills/
├── .claude-plugin/
│   └── marketplace.json         # Plugin registry
├── skills/
│   └── web-to-rag/              # Self-contained skill
│       ├── SKILL.md             # Skill definition
│       ├── README.md            # Documentation
│       ├── install-prerequisites.ps1
│       ├── install-prerequisites.sh
│       ├── infrastructure/      # Docker containers
│       ├── references/          # Supporting docs
│       └── scripts/             # Utilities
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Adding New Skills

1. Create folder under `skills/`
2. Add `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill-name
   description: |
     What the skill does and when to use it.
     Include trigger keywords.
   allowed-tools: Tool1 Tool2 Tool3
   ---
   ```
3. Add `README.md`
4. Include installer if needed
5. Update `marketplace.json`
6. Submit pull request

---

## Contributing

Contributions welcome! See <a href="CONTRIBUTING.md" target="_blank">CONTRIBUTING.md</a>.

### Ideas for New Skills

- Database query assistant
- API documentation generator
- Code review automation
- Log analysis
- Test generation

---

## License

<a href="LICENSE" target="_blank">MIT License</a>

---

## Author

Created by <a href="https://github.com/Tapiocapioca" target="_blank">Tapiocapioca</a> with Claude Code.

*Last updated: January 2026*
