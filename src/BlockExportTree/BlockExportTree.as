
array<string> ParseBlackListString(string blacklistStr) {
    auto split = blacklistStr.Split(",");

    array<string> blacklistItems;
    for (uint i = 0; i < split.Length; i++) {
        auto trimmed = split[i].Trim();
        if (trimmed.Length > 0) {
            blacklistItems.InsertLast(trimmed);
        }
    }

    return blacklistItems;
}

class BlockExportTree {
    TreeNode@ root = TreeNode("Root");
    
    BlockExportTree() {}
    BlockExportTree(array<BlockExportData@> blocks) {
        for (uint i = 0; i < blocks.Length; i++) {
            AddBlock(blocks[i]);
        }
    }

    void RenderInterface() {
        if (root !is null) {
            if (root.children.Length == 0) {
                UI::Text("No blocks found, please refresh.");
            }
            // Use custom render interface on all children to avoid rendering the root node
            for (uint i = 0; i < root.children.Length; i++) {
                if (root.children[i] !is null) {
                    root.children[i].RenderInterface();
                }
            }
        }
    }

    void AddBlock(BlockExportData@ block) {
        root.AddBlock(block, block.blockItemPath);
    }

    void NotifyBlockChange(BlockExportData@ block) {
        TreeNode@ blockNode = root.FindNodeAtPath(block.blockItemPath);

        if (blockNode is null) {
            return;
        }

        print("Found node: " + blockNode.name);
        blockNode.NotifyBlockChange(block);
    }

    void PropagateBlacklist(string blacklistStr) {
        array<string> blacklistItems = ParseBlackListString(blacklistStr);
        root.PropagateBlacklistItems(blacklistItems);

        // Blacklist nodes with direct nodes in blacklist
        for (int i = 0; i < blacklistItems.Length; i++) {
            auto node = root.FindNodeAtPath(blacklistItems[i]);
            if (node !is null) {
                node.Blacklist();
            }
        }
    }
}
