class TreeBlock : TreeNode {
    TreeBlock(string name, BlockExportData@ block) {
        super(name);
        @this.block = block;
    }

    void RenderInterface() override {
        if (UI::Button("Export###export-" + name)) {
            this.Export();
        }
        UI::SameLine();

        bool pushedColor = false;
        if (block.exported) {
            UI::PushStyleColor(UI::Col::Text, vec4(0.0, 1.0, 0.0, 1.0));
            pushedColor = true;
        } else if (block.errorMessage != "") {
            UI::PushStyleColor(UI::Col::Text, vec4(1.0, 0.0, 0.0, 1.0));
            pushedColor = true;
        }

        string nodeText = Icons::Cube + " " + name;
        if (block.errorMessage != "") {
            nodeText += " (" + block.errorMessage + ")";
        }
        if (UI::TreeNode(nodeText, UI::TreeNodeFlags::Leaf)) {
            UI::TreePop();
        }

        if (pushedColor) {
            UI::PopStyleColor();
        }
    }
    
    // GetAllBlocks from this node will return an array with only this block
    array<BlockExportData@> GetAllBlocks() override {
        return { block };
    }

    void NotifyBlockChange(BlockExportData@ block) override {
        exportedBlocks = block.exported ? 1 : 0;
        erroredBlocks = block.errorMessage != "" ? 1 : 0;
        
        if (parent !is null) {
            parent.NotifyBlockChange(block);
        }
    }
}

class TreeNode {
    // Node member veriables
    string name;
    BlockExportData@ block;
    array<TreeNode@> children;
    TreeNode@ parent;

    // Accumulated member variables
    int totalBlocks = 0;
    int exportedBlocks = 0;
    int erroredBlocks = 0;

    // Remember tree open/close state
    bool wasOpen = false;

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

    array<BlockExportData@> GetAllBlocks() {
        array<BlockExportData@> allBlocks;
        for (int i = 0; i < children.Length; i++) {
            if (children[i] is null) continue;

            array<BlockExportData@> subBlocks = children[i].GetAllBlocks();
            for (int j = 0; j < subBlocks.Length; j++) {
                allBlocks.InsertLast(subBlocks[j]);
            }
        }
        return allBlocks;
    }

    // Add node to children
    void AddChildNode(TreeNode@ node) {
        if (node is null) return;
        @node.parent = this;
        children.InsertLast(node);
    }

    // Recursively finds a node in its children from this node given a path like "Nadeo/RoadTech/Main/BlockName.Item.Gbx"
    TreeNode@ FindNodeAtPath(string path) {
        array<string> parts = path.Split("/");

        // Return null if path is empty
        if (parts.Length == 0) return null;

        TreeNode@ node = GetChild(parts[0]);
        if (node is null) return null;
        
        if (parts.Length == 1) {
            // Only one part left (blockName.Item.Gbx), return this node if the name matches
            if (parts[0] == node.name) {
                return node;
            } else {
                return null;
            }
        } else {
            // Recursively find node with the rest of the path, removing the first part
            return node.FindNodeAtPath(path.SubStr(parts[0].Length + 1));
        }
    }

    // Recursively add block to this and children nodes, given a path like "Nadeo/RoadTech/Main/BlockName.Item.Gbx" 
    //  If the path contains multiple folders, it adds the block to a child node or creates a child node if it doesn't exist
    //  If the path only contains the file name, it adds the block as a TreeBlock to the current children
    void AddBlock(BlockExportData@ block, string path) {
        totalBlocks += 1;
        if (block.exported) exportedBlocks += 1;

        array<string> parts = path.Split("/");
        if (parts.Length == 1) {
            // Only one part left (blockName.Item.Gbx), add block as TreeBlock
            AddChildNode(TreeBlock(parts[0], block));
        } else {
            // More parts left, add a new TreeNode and recurse
            TreeNode@ node = GetChild(parts[0]);
            if (node is null) {
                // If node doesn't exist, create it and add it to the current children
                @node = TreeNode(parts[0]);
                AddChildNode(node);
            }

            // Recursively add blocks with the rest of the path, removing the first part
            string restPath = path.SubStr(parts[0].Length + 1);
            node.AddBlock(block, restPath);
        }
    }

    void RenderInterface() {
        // Export button
        if (UI::Button("Export###export-" + name)) {
            this.Export();
        }
        UI::SameLine();

        // Render node and children
        vec4 prevColor = UI::GetStyleColor(UI::Col::Text);

        bool pushedColor = false;
        if (exportedBlocks > 0) {
            if (exportedBlocks == totalBlocks) {
                UI::PushStyleColor(UI::Col::Text, vec4(0.0, 1.0, 0.0, 1.0));
            } else {
                UI::PushStyleColor(UI::Col::Text, vec4(1.0, 1.0, 0.0, 1.0));
            }
            pushedColor = true;
        }
        if (erroredBlocks == totalBlocks) {
            UI::PushStyleColor(UI::Col::Text, vec4(1.0, 0.0, 0.0, 1.0));
            pushedColor = true;
        }

        string nodeText = name + " (" + exportedBlocks + "/" + totalBlocks + " exported, " + erroredBlocks +" errors)";
        if (UI::TreeNode(nodeText, wasOpen ? UI::TreeNodeFlags::DefaultOpen : UI::TreeNodeFlags::None)) {
            wasOpen = true;

            // Temporarily push previous color to children
            UI::PushStyleColor(UI::Col::Text, prevColor);
            for (uint i = 0; i < children.Length; i++) {
                if (children[i] !is null) {
                    children[i].RenderInterface();
                }
            }
            UI::PopStyleColor();

            UI::TreePop();
        } else {
            wasOpen = false;
        }

        if (pushedColor) {
            UI::PopStyleColor();
        }
    }

    // Collect all blocks in children and start export on all those blocks
    void Export() {
        array<BlockExportData@> allBlocks = GetAllBlocks();

        // Remove all block that have already been exported
        array<BlockExportData@> blocksToExport;
        for (int i = 0; i < allBlocks.Length; i++) {
            if (!allBlocks[i].exported) {
                blocksToExport.InsertLast(allBlocks[i]);
            }
        }
        
        print("Exporting " + blocksToExport.Length + " blocks...");

        ConvertMultipleBlockToItemCoroutineHandle@ handle = cast<ConvertMultipleBlockToItemCoroutineHandle>(ConvertMultipleBlockToItemCoroutineHandle());
        handle.blocks = blocksToExport;
        startnew(ConvertMultipleBlockToItemCoroutine, handle);
    }

    void NotifyBlockChange(BlockExportData@ block) {
        int newExportedBlocks = 0;
        int newErroredBlocks = 0;
        for (int i = 0; i < children.Length; i++) {
            if (children[i] !is null) {
                newExportedBlocks += children[i].exportedBlocks;
                newErroredBlocks += children[i].erroredBlocks;
            }
        }
        exportedBlocks = newExportedBlocks;
        erroredBlocks = newErroredBlocks;

        if (parent !is null) {
            parent.NotifyBlockChange(block);
        }
    }
}
