### Configuration switcher script with context tracking

_Install_
```
curl -fsSL https://raw.githubusercontent.com/riizeron/ctx/refs/heads/main/install.sh | bash
```

_Help_
```
Usage: ctx <command> [<category> [<config_name>]]

Commands:
    list <category>         - List all categories or configurations in category
    use <category> [config] - Activate specific config or interactive select
    show [category]         - Show current context for category or all categories

Examples:
    ctx list              - List all categories
    ctx list abc          - List configurations in 'abc'
    ctx use abc cfg1      - Activate 'cfg1' in 'abc'
    ctx use abc           - Interactive select for 'abc'
    ctx show asd          - Show current context for 'asd'
    ctx show              - Show current contexts for all categories
```