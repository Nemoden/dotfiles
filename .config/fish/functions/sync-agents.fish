function _sync-agents-claude --description "Install/sync Claude Code plugins"
    if not command -v claude > /dev/null
        echo "claude not installed, skipping"
        return
    end
    echo "==> Claude Code"
    claude /plugin install oh-my-claudecode@omc
    claude /plugin install superpowers@claude-plugins-official
end

function _sync-agents-skills --description "Install/sync universal agent skills via npx"
    if not command -v npx > /dev/null
        echo "npx not installed, skipping skills"
        return
    end
    echo "==> Universal skills"
    # Stripe: https://docs.stripe.com/building-with-ai?agent=claudecode
    npx skills add https://docs.stripe.com --yes
end

function sync-agents --description "Install/sync AI agent plugins across installed agents"
    _sync-agents-skills
    _sync-agents-claude
end
