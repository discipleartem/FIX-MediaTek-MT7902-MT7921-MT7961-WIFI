#!/bin/bash

# Script for submitting patch to Linux kernel
# Follow the patch submission guide: https://www.kernel.org/doc/html/latest/process/submitting-patches.html

set -e

echo "📤 Preparing patch submission to Linux kernel"
echo "=========================================="

# 1. Environment check
echo "1. Checking environment..."

# Check git
if ! command -v git &> /dev/null; then
    echo "❌ Git not installed"
    exit 1
fi

# Check get_maintainer.pl
if ! command -v scripts/get_maintainer.pl &> /dev/null; then
    echo "❌ scripts/get_maintainer.pl not found. Make sure you're in kernel source tree"
    exit 1
fi

# Check patch
if [ ! -f "patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch" ]; then
    echo "❌ Patch not found"
    exit 1
fi

echo "✅ Environment checked"

# 2. Check patch format
echo "2. Checking patch format..."
if ! scripts/checkpatch.pl patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch; then
    echo "❌ Patch failed checkpatch.pl check"
    echo "Fix errors before submission"
    exit 1
fi

echo "✅ Patch format is correct"

# 3. Get maintainers list
echo "3. Getting maintainers list..."
MAINTAINERS=$(scripts/get_maintainer.pl patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch)

echo "📋 Found maintainers:"
echo "$MAINTAINERS"

# 4. Prepare email
echo "4. Preparing email..."

# Extract email addresses
TO_EMAIL=$(echo "$MAINTAINERS" | grep -E '<.*@.*>' | head -5 | tr '\n' ' ')
CC_LIST=$(echo "$MAINTAINERS" | grep -E '<.*@.*>' | tail -n +6 | tr '\n' ' ')

echo "📧 Email addresses:"
echo "To: $TO_EMAIL"
echo "Cc: $CC_LIST"

# 5. Create submission command
echo "5. Submission command:"
echo ""
echo "git send-email --to=\"$TO_EMAIL\" --cc=\"$CC_LIST\" \\"
echo "  --cc-cmd='scripts/get_maintainer.pl --norolestats patches/0001-*.patch' \\"
echo "  --subject-prefix='PATCH net-next' \\"
echo "  patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch"
echo ""

# 6. Check git configuration
echo "6. Checking git configuration..."
if ! git config user.name || ! git config user.email; then
    echo "⚠️  Configure git settings:"
    echo "   git config --global user.name 'Your Name'"
    echo "   git config --global user.email 'your.email@example.com'"
    echo ""
    echo "Or use:"
    echo "   export GIT_COMMITTER_NAME='Your Name'"
    echo "   export GIT_COMMITTER_EMAIL='your.email@example.com'"
fi

echo ""
echo "✅ Preparation completed!"
echo ""
echo "📋 Next steps:"
echo "1. Make sure you're in Linux kernel source tree"
echo "2. Configure git settings (name and email)"
echo "3. Run the command above to send patch"
echo ""
echo "📖 Additional information:"
echo "- Guide: https://www.kernel.org/doc/html/latest/process/submitting-patches.html"
echo "- Mailing list: linux-wireless@vger.kernel.org"
echo "- Maintainers: Felix Fietkau <nbd@nbd.name>, Lorenzo Bianconi <lorenzo@kernel.org>"
