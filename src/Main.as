void Main() {
    InitializeBlockExporter();
}

VirtualKey ABORT_KEY = VirtualKey::B;
void OnKeyPress(bool down, VirtualKey key) {
    if (key == ABORT_KEY && down) {
        UI::ShowNotification("Aborting block exporter after next block...");
        abortExporting = true;
    }
}

void UpdateAllBlocks() {
    bool initLib = InitializeLib();
    if(!initLib) return;

    blocks = FindAllBlocksInEditorInventory();    
    blockExportTree = BlockExportTree(blocks);
    blockExportTree.PropagateBlacklist(blacklistStr);
}

void GoToEditor() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null) return;
    app.ManiaTitleControlScriptAPI.EditNewMap2(
        "Stadium", "48x48Day", "", "CarSport", "", false, "", ""
    );
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
        if (blockExportTree.root !is null) {
            auto root = blockExportTree.root;
            UI::Text("Total blocks: " + root.totalBlocks);
            UI::Text("Total blacklisted: " + root.blacklistedBlocks);
            float exportProgress = 0.0;
            if (root.totalBlocks - root.blacklistedBlocks > 0) {
                exportProgress = float(root.exportedBlocks) / (float(root.totalBlocks) - float(root.blacklistedBlocks));
            }
            exportProgress = Math::Round(exportProgress * 10000) / 10000;
            UI::Text("Export progress: " + root.exportedBlocks + "/" + (root.totalBlocks - root.blacklistedBlocks) + " (" + (exportProgress * 100) + "%)");
        }

        UI::Separator();

        UI::Text("Blacklist (string or folder, comma separated):");
        blacklistStr = UI::InputText("##", blacklistStr, blacklistChanged);
        if (blacklistChanged) {
            blockExportTree.PropagateBlacklist(blacklistStr);
        }

        UI::Separator();

        if (GetApp().RootMap is null) {
            if (UI::Button("Go To Editor")) {
                GoToEditor();
            }
        }

        if (UI::Button("Refresh blocks")) {
            UpdateAllBlocks();
        }
        UI::SameLine();
        if (UI::Button("Clear blocks")) {
            ResetBlocks();
        }

        UI::Separator();
        if (UI::Button("Preload Block FIDs")) {
            PreloadBlockFIDs();
        }
        UI::SameLine();
        if (UI::Button("Preload Item FIDs")) {
            PreloadItemFIDs();
        }

        UI::Separator();

        blockExportTree.RenderInterface();

        UI::End();
    }
}

bool windowOpen = true;
string blacklistStr = "water, Nadeo/RoadIce/Racing, StageDiagIn.Item.Gbx, StageCurve1Out.Item.Gbx, StageCurve2Out.Item.Gbx, StageCurve3Out.Item.Gbx, StageCurve1In.Item.Gbx, StageCurve2In.Item.Gbx, StageCurve3In.Item.Gbx";
bool blacklistChanged = false;
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
    string errorMessage = "";

    bool blacklisted = false;

    BlockExportData() {}
    BlockExportData(CGameCtnBlockInfo@ block, string blockFolder) {
        @this.block = block;
        this.blockFolder = blockFolder;
        this.blockItemPath = GetBlockItemPath(blockFolder);
        this.blockFileExportPath = GetBlockFilePath(this.blockItemPath);
        this.exported = ConfirmBlockExport(this);
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

array<CGameItemModel@> FindAllItems(CGameCtnArticleNodeDirectory@ parentNode, string folder = "")
{
    array<CGameItemModel@> items;
    for(uint i = 0; i < parentNode.ChildNodes.Length; i++) {
        auto node = parentNode.ChildNodes[i];
        if(node.IsDirectory) {
            auto childItems = FindAllItems(cast<CGameCtnArticleNodeDirectory@>(node), folder + node.Name + '/');
            for(uint j = 0; j < childItems.Length; j++) {
                items.InsertLast(childItems[j]);
            }
        } else {
            auto ana = cast<CGameCtnArticleNodeArticle@>(node);

            if (ana.Name.StartsWith("BlockToItemExports\\")) continue;

            if(ana.Article is null || ana.Article.IdName.ToLower().EndsWith("customblock")) {
                warn("Block: " + ana.Name + " is not nadeo, skipping");
                continue;
            }

            auto item = cast<CGameItemModel@>(ana.Article.LoadedNod);
            if(item is null) {
                warn("Block " + ana.Name + " is null!");
                continue;
            }

            // string blockFolder = folder + ana.Name;

            // auto blockInfo = BlockExportData(item, blockFolder);
            items.InsertLast(item);
        }
    }
    return items;
}
