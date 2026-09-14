#!/usr/bin/env bash
# Claude Skill: Repository Restructurer & Cleaner
# This script standardizes the company AI repo according to Monorepo Best Practices.
# It handles moving nested AWS toolkits, setting up uniform plugin folders, 
# and establishing clear paths for child skills.

set -e

echo "🚀 Starting AI Repository Restructuring..."

# 1. Create the new best-practice directory tree
echo "📂 Creating clean target directory layout..."
mkdir -p .claude
mkdir -p docs
mkdir -p plugins/aws
mkdir -p plugins/atlassian/skills

# 2. Safely move the AWS nested assets if they exist in the old location
# Old path: agent-toolkit-for-aws/plugins/* -> New path: plugins/aws/*
if [ -d "agent-toolkit-for-aws/plugins" ]; then
    echo "📦 Moving and flattening AWS toolkit modules..."
    
    # Process aws-core
    if [ -d "agent-toolkit-for-aws/plugins/aws-core" ]; then
        mv agent-toolkit-for-aws/plugins/aws-core plugins/aws/
        echo "   ✅ Moved aws-core"
    fi
    
    # Process aws-agents
    if [ -d "agent-toolkit-for-aws/plugins/aws-agents" ]; then
        mv agent-toolkit-for-aws/plugins/aws-agents plugins/aws/
        echo "   ✅ Moved aws-agents"
    fi
    
    # Process aws-data-analytics
    if [ -d "agent-toolkit-for-aws/plugins/aws-data-analytics" ]; then
        mv agent-toolkit-for-aws/plugins/aws-data-analytics plugins/aws/
        echo "   ✅ Moved aws-data-analytics"
    fi
    
    # Process aws-agents-for-devsecops
    if [ -d "agent-toolkit-for-aws/plugins/aws-agents-for-devsecops" ]; then
        mv agent-toolkit-for-aws/plugins/aws-agents-for-devsecops plugins/aws/
        echo "   ✅ Moved aws-agents-for-devsecops"
    fi
    
    # Cleanup empty tracking folder
    rmdir -p agent-toolkit-for-aws/plugins 2>/dev/null || true
else
    echo "⚠️  'agent-toolkit-for-aws/plugins' directory not found. Skipping move or already restructured."
fi

# 3. Restructure Atlassian Child Skills if any exist loosely
# Ensure everything loose under atlassian that belongs to a skill is properly isolated
if [ -d "plugins/atlassian" ]; then
    echo "🔧 Structuring Atlassian plugin environment..."
    # If they have loose markdown skill files, move them to the skills subfolder
    find plugins/atlassian -maxdepth 1 -name "*.md" -not -name "README.md" -exec mv {} plugins/atlassian/skills/ \; 2>/dev/null || true
fi

echo "✨ Directory structural optimization complete!"
echo "💡 NEXT STEP: Run Claude Code to generate your CLAUDE.md and REGISTRY.md maps."
