# ctx - Configuration Context Switcher

`ctx` helps you manage multiple configuration sets (contexts) for your projects or environments. Each context is stored as a folder with an `activate` script that applies its settings when you switch to it.


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



## How It Works

1. **Directory Structure**  
   All contexts live under `~/.config/<category>/<context_name>/activate`.  
   For example:

   ```bash
   ~/.config/
     network/
       home/
         activate
       office/
         activate
     editor/
       vim/
         activate
       emacs/
         activate
   ```

2. **Commands**  
   - `ctx list [<category>]`  
     Without arguments, lists all available categories. If you specify a category, lists all contexts in that category.  
   - `ctx use <category> [<context>]`  
     Activates a context. If you omit `<context>`, you get an interactive menu to choose one.  
   - `ctx show [<category>]`  
     Shows the currently active context for all categories, or for a single category if provided.  
   - `ctx help`, `ctx -h`, `ctx --help`  
     Shows this help message.

3. **Context Activation**  
   When you run:

   ```bash
   ctx use network home
   ```

   the script:  
   - Sources `~/.config/network/home/activate`, applying its environment variables and settings.  
   - Records `network=home` in `~/.config/.current_contexts` so you can view it later with `ctx show`.

4. **Interactive Selection**  
   If you run:

   ```bash
   ctx use editor
   ```

   without specifying a context, a numbered menu appears, letting you pick `vim`, `emacs`, or any other context defined in `~/.config/editor/`.

## Adding New Contexts

1. Create a new category folder (if needed):

   ```bash
   mkdir -p ~/.config/<category>
   ```

2. Create a new context directory:

   ```bash
   mkdir -p ~/.config/<category>/<context_name>
   ```

3. Add an `activate` script inside it