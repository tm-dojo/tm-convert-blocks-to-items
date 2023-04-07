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
        if (UI::Button("Check###check-" + name)) {
            this.CheckBlockExportPaths();
        }
        UI::SameLine();

        if (block.exported) {
            UI::PushStyleColor(UI::Col::Text, vec4(0.0, 1.0, 0.0, 1.0));
        }

        if (UI::TreeNode(Icons::Cube + " " + name, UI::TreeNodeFlags::Leaf)) {
            block.block.Icon;
            UI::TreePop();
        }
        if (block.exported) {
            UI::PopStyleColor();
        }
    }
    
    // GetAllBlocks from this node will return an array with only this block
    array<BlockExportData@> GetAllBlocks() override {
        return { block };
    }

    // Checks the export path of this block and updates the exported flag
    void CheckBlockExportPaths() override {
        block.exported = ConfirmBlockExport(block);
    }

    // As a leaf node, this block will return 1 or 0 depending on whether the block is exported
    int NumExportedBlocks() override {
        return block.exported ? 1 : 0;
    }
}

class TreeNode {
    // Node member veriables
    string name;
    BlockExportData@ block;
    array<TreeNode@> children;

    // Accumulated member variables
    int totalBlocks = 0;
    int exportedBlocks = 0;

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
        children.InsertLast(node);
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

        // Check exports button
        if (UI::Button("Check###check-" + name)) {
            this.CheckBlockExportPaths();
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

        if (UI::TreeNode(name + " (" + exportedBlocks + "/" + totalBlocks + ")")) {
            // Temporarily push previous color to children
            UI::PushStyleColor(UI::Col::Text, prevColor);
            for (uint i = 0; i < children.Length; i++) {
                if (children[i] !is null) {
                    children[i].RenderInterface();
                }
            }
            UI::PopStyleColor();

            UI::TreePop();
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
    
    // Recursively check all children if the blocks are exported at the export path
    void CheckBlockExportPaths() {
        for (uint i = 0; i < children.Length; i++) {
            if (children[i] is null) continue;
            children[i].CheckBlockExportPaths();
        }
        UpdateNumExportedBlocks();
    }

    // Recursively update all children's total number of exported blocks
    void UpdateNumExportedBlocks() {
        exportedBlocks = NumExportedBlocks();
        for (int i = 0; i < children.Length; i++) {
            if (children[i] is null) continue;
            children[i].UpdateNumExportedBlocks();
        }
    }

    // Recursively count all exported blocks in children
    int NumExportedBlocks() {
        int totalExportedBlocks = 0;
        for (uint i = 0; i < children.Length; i++) {
            if (children[i] is null) continue;
            totalExportedBlocks += children[i].NumExportedBlocks();
        }
        return totalExportedBlocks;
    }
}
