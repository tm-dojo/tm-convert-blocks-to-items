class TreeBlock : TreeNode {
    TreeBlock(string name, BlockExportData@ block) {
        super(name);
        @this.block = block;
    }

    void RenderInterface() override {
        if (UI::Button("Export###" + name)) {
            print("Exporting " + name + "...");
        }
        UI::SameLine();

        if (UI::TreeNode(Icons::Cube + " " + name, UI::TreeNodeFlags::Leaf)) {
            block.block.Icon;
            UI::TreePop();
        }
    }
}

class TreeNode {
    string name;
    BlockExportData@ block;
    array<TreeNode@> children;

    int totalBlocks = 0;

    TreeNode(string name) {
        this.name = name;
    }

    TreeNode@ GetChild(string name) {
        for (int i = 0; i < children.Length; i++) {
            if (children[i] !is null && children[i].name == name) {
                return children[i];
            }
        }
        return null;
    }

    // Add node to children
    void AddChildNode(TreeNode@ node) {
        if (node is null) return;
        children.InsertLast(node);
    }

    // Recursively add block to this and children nodes, given a path like "Nadeo/RoadTech/Main/BlockName.Item.Gbx" 
    //  If the path contains multiple folders, it adds the block to a child node or creates a child node if it doesn't exist
    //  If the path only contains the file name, it adds the block as a TreeBlock to the current children
    void AddBlock(BlockExportData@ block, string path) {
        totalBlocks += 1;
        auto parts = path.Split("/");
        if (parts.Length == 1) {
            // Only one part left (blockName.Item.Gbx), add block as TreeBlock
            AddChildNode(TreeBlock(parts[0], block));
        } else {
            // More parts left, add a new TreeNode and recurse
            auto node = GetChild(parts[0]);
            if (node is null) {
                // If node doesn't exist, create it and add it to the current children
                @node = TreeNode(parts[0]);
                AddChildNode(node);
            }
            node.AddBlock(block, path.SubStr(parts[0].Length + 1));
        }
    }

    void RenderInterface() {
        if (UI::Button("Export###" + name)) {
            print("Exporting " + name + "...");
        }
        UI::SameLine();

        if (UI::TreeNode(name + " (" + totalBlocks + ")")) {
            for (uint i = 0; i < children.Length; i++) {
                if (children[i] !is null) {
                    children[i].RenderInterface();
                }
            }
            UI::TreePop();
        }
    }
}
