void Main() {
    InitializeBlockExporter();
}

void UpdateAllBlocks() {
    bool initLib = InitializeLib();
    if(!initLib) return;

    blocks = FindAllBlocksInEditorInventory();    
    blockExportTree = BlockExportTree(blocks);
}

void ResetBlocks() {
    blocks = {};
    blockExportTree = BlockExportTree();
}

void RenderMenu() {
    if (UI::MenuItem("Blocks To Items", "", windowOpen, true)) {
        windowOpen = !windowOpen;
    }
}

void RenderInterface() {
    if (windowOpen && UI::Begin("Blocks To Items", windowOpen)) {
        UI::Text("Total blocks: " + blocks.Length);
        if (UI::Button("Refresh blocks")) {
            UpdateAllBlocks();
        }
        UI::SameLine();
        if (UI::Button("Reset blocks")) {
            ResetBlocks();
        }
        UI::SameLine();
        if (UI::Button("Set item path")) {
            auto app = GetApp();
            app.BasicDialogs.String = "Test path";
        }

        blockExportTree.RenderInterface();

        // if (UI::BeginTable("blocks", 5)) {
        //     UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoSort);
        //     UI::TableSetupColumn("Blacklist", UI::TableColumnFlags::WidthFixed);
        //     UI::TableSetupColumn("Exported", UI::TableColumnFlags::WidthFixed);
        //     UI::TableSetupColumn("Block Name", UI::TableColumnFlags::WidthFixed);   
        //     UI::TableSetupColumn("Block Item Path", UI::TableColumnFlags::WidthFixed);   
        //     UI::TableHeadersRow();
        //     for (uint i = 0; i < blocks.Length; i++) {
        //         UI::TableNextRow();
        //         UI::TableSetColumnIndex(0);
        //         bool buttonClicked = UI::Button("Export" + "###" + i);
        //         if(UI::IsItemHovered()) {
        //             UI::BeginTooltip();
        //             UI::Text("Export to: " + blocks[i].blockFileExportPath);
        //             UI::EndTooltip();
        //         }
        //         if(buttonClicked) {
        //             print("Exporting " + blocks[i].block.Name);
        //             ConvertBlockToItemHandle@ handle = cast<ConvertBlockToItemHandle>(ConvertBlockToItemHandle());
        //             handle.blockExportData = blocks[i];
        //             startnew(ConvertBlockToItemCoroutine, handle);
        //         }
        //         UI::TableSetColumnIndex(1);
        //         UI::Text("no");
        //         UI::TableSetColumnIndex(2);
        //         UI::Text("no");
        //         UI::TableSetColumnIndex(3);
        //         UI::Text(blocks[i].block.Name);
        //         UI::TableSetColumnIndex(4);
        //         UI::Text(blocks[i].blockItemPath);
        //     }            
        //     UI::EndTable();
        // }

        UI::End();
    }
}

bool windowOpen = true;
array<BlockExportData@> blocks;
BlockExportTree blockExportTree;

string GetBlockItemPath(string blockFolder) {
    return 'Nadeo/' + blockFolder + '.Item.Gbx';
}

string GetBlockFilePath(string blockItemPath) {
    // return IO::FromStorageFolder("Exports/" + blockItemPath);
    return "BlockToItemExports/" + blockItemPath;
}

class BlockExportData {
    CGameCtnBlockInfo@ block;
    string blockFolder;
    string blockItemPath;
    string blockFileExportPath;

    bool exported = false;

    BlockExportData() {}
    BlockExportData(CGameCtnBlockInfo@ block, string blockFolder) {
        @this.block = block;
        this.blockFolder = blockFolder;
        this.blockItemPath = GetBlockItemPath(blockFolder);
        this.blockFileExportPath = GetBlockFilePath(this.blockItemPath);
        this.exported = false;
    }
}

array<BlockExportData@> FindAllBlocks(CGameCtnArticleNodeDirectory@ parentNode, string folder = "")
{
    array<BlockExportData@> blocks;
    for(uint i = 0; i < parentNode.ChildNodes.Length; i++) {
        auto node = parentNode.ChildNodes[i];
        if(node.IsDirectory) {
            auto childBlocks = FindAllBlocks(cast<CGameCtnArticleNodeDirectory@>(node), folder + node.Name + '/');
            for(uint j = 0; j < childBlocks.Length; j++) {
                blocks.InsertLast(childBlocks[j]);
            }
        } else {
            auto ana = cast<CGameCtnArticleNodeArticle@>(node);
            if(ana.Article is null || ana.Article.IdName.ToLower().EndsWith("customblock")) {
                warn("Block: " + ana.Name + " is not nadeo, skipping");
                continue;
            }

            auto block = cast<CGameCtnBlockInfo@>(ana.Article.LoadedNod);
            if(block is null) {
                warn("Block " + ana.Name + " is null!");
                continue;
            }

            string blockFolder = folder + ana.Name;

            auto blockInfo = BlockExportData(block, blockFolder);
            blocks.InsertLast(blockInfo);
        }
    }
    return blocks;
}
