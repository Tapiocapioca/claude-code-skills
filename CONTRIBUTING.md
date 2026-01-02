# Contributing to Claude Code Skills

Thank you for your interest in contributing!

## How to Contribute

### Adding a New Skill

1. **Fork** this repository
2. **Create** a new folder under `skills/` with your skill name
3. **Add** a `SKILL.md` file with the required YAML frontmatter:
   ```yaml
   ---
   name: your-skill-name
   description: |
     Brief description of what your skill does and when it should activate.
   ---

   # Your Skill Name

   Documentation for your skill...
   ```
4. **Add** any scripts, references, or assets needed
5. **Update** `.claude-plugin/marketplace.json` to register your skill
6. **Submit** a Pull Request

### Skill Structure

```
skills/
└── your-skill-name/
    ├── SKILL.md           # Required: Skill definition
    ├── scripts/           # Optional: Python/shell scripts
    ├── references/        # Optional: Documentation files
    └── assets/            # Optional: Images, configs, etc.
```

### Guidelines

- **Clear naming**: Use lowercase, hyphen-separated names (`my-cool-skill`)
- **Good documentation**: Explain what the skill does and how to use it
- **No hardcoded secrets**: Use environment variables or config files
- **Test your skill**: Make sure it works before submitting

## Reporting Issues

Open an issue if you find bugs or have suggestions for improvements.

## Questions?

Feel free to open a discussion or issue if you need help.
