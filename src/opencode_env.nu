# OpenCode Environment Variables Passthrough
#
# This module defines OpenCode-specific environment variables that should be
# passed through from the host environment to the container when they exist.
#
# Variables are organized by category for maintainability.

# Returns a list of all OpenCode environment variable names that should be
# passed through from the host to the container.
export def get-passthrough-vars [] {
    [
        # LLM Provider API Keys & Credentials
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GOOGLE_GENERATIVE_AI_API_KEY",
        "AZURE_OPENAI_API_KEY",
        "AWS_BEARER_TOKEN_BEDROCK",
        "AWS_REGION",
        "AWS_PROFILE",
        "OPENROUTER_API_KEY",
        "MISTRAL_API_KEY",
        "GROQ_API_KEY",
        "XAI_API_KEY",
        "DEEPSEEK_API_KEY",
        "TOGETHER_API_KEY",
        "PERPLEXITY_API_KEY",
        "FIREWORKS_API_KEY",
        "AICORE_SERVICE_KEY",
        "AICORE_DEPLOYMENT_ID",
        "GITLAB_TOKEN",
        "GITLAB_INSTANCE_URL",
        
        # External Integration & Third Party
        "GITHUB_TOKEN",
        "USE_GITHUB_TOKEN",
        
        # System & Proxy Settings
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "SHELL",
        "EDITOR",
        "VISUAL",
        "TMUX",
        "STY",
        "LANG",
        "LC_ALL",
        
        # Core Configuration Flags
        "OPENCODE_AUTO_SHARE",
        "OPENCODE_DISABLE_AUTOUPDATE",
        "OPENCODE_DISABLE_PRUNE",
        "OPENCODE_DISABLE_AUTOCOMPACT",
        "OPENCODE_DISABLE_TERMINAL_TITLE",
        "OPENCODE_DISABLE_PROJECT_CONFIG",
        "OPENCODE_DISABLE_SHARE",
        "OPENCODE_EXPERIMENTAL",
        "OPENCODE_PERMISSION",
        "OPENCODE_MODELS_URL",
        "OPENCODE_GIT_BASH_PATH",
        "OPENCODE_SERVER_USERNAME",
        "OPENCODE_SERVER_PASSWORD",
        
        # Configuration with Paths (users must provide container paths)
        "OPENCODE_CONFIG",
        "OPENCODE_CONFIG_DIR",
        "OPENCODE_CONFIG_CONTENT",
        "OPENCODE_MODELS_PATH",
    ]
}

# Generates docker run arguments for OpenCode environment variables.
# Only includes variables that are actually set in the host environment.
#
# Returns: A list of strings in the format ["-e", "VAR_NAME", "-e", "VAR_NAME", ...]
export def generate-docker-args [] {
    mut args = []
    
    for var_name in (get-passthrough-vars) {
        # Check if the variable exists in the host environment
        let var_value = (do -i { $env | get -o $var_name })
        
        if $var_value != null {
            $args = ($args | append ["-e" $var_name])
        }
    }
    
    $args
}
