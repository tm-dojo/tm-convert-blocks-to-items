void Main() {
    // CreateBlockItems();
    print("test");
}

void UpdateAllBlocks() {
    bool initLib = InitializeLib();
    if(!initLib) return;

    blocks = FindAllBlocksInEditorInventory();
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
            blocks = {};
        }

        if (UI::BeginTable("blocks", 6)) {
            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoSort);
            UI::TableSetupColumn("Blacklist", UI::TableColumnFlags::WidthFixed);
            UI::TableSetupColumn("Exported", UI::TableColumnFlags::WidthFixed);
            UI::TableSetupColumn("Block Name", UI::TableColumnFlags::WidthFixed);   
            UI::TableSetupColumn("Block Item Path", UI::TableColumnFlags::WidthFixed);   
            UI::TableSetupColumn("Block File Export Path", UI::TableColumnFlags::WidthFixed);    
            UI::TableHeadersRow();
            for (uint i = 0; i < blocks.Length; i++) {
                UI::TableNextRow();
                UI::TableSetColumnIndex(0);
                if (UI::Button("Export" + "###" + i)) {
                    print("Exporting " + blocks[i].block.Name);
                }
                UI::TableSetColumnIndex(1);
                UI::Text("no");
                UI::TableSetColumnIndex(2);
                UI::Text("no");
                UI::TableSetColumnIndex(3);
                UI::Text(blocks[i].block.Name);
                UI::TableSetColumnIndex(4);
                UI::Text(blocks[i].blockItemPath);
                UI::TableSetColumnIndex(5);
                UI::Text(blocks[i].blockFileExportPath);
            }
            UI::EndTable();
        }
        UI::End();
    }
}

Import::Library@ lib = null;
Import::Function@ clickFun = null;
Import::Function@ mousePosFun = null;
Import::Function@ justClickFun = null;

bool windowOpen = true;
array<BlockExportData> blocks;

// blacklist include terms, these cause crashes
string[] blacklist = {"GateSpecialTurbo", "GateSpecialBoost"};

int totalBlocks = 2360;
int count = 0;
int screenWidth = 1;
int screenHeight = 1;

string GetBlockItemPath(string blockFolder) {
    return 'Nadeo/' + blockFolder + '.Item.Gbx';
}

string GetBlockFilePath(string blockItemPath) {
    return IO::FromStorageFolder("Exports/" + blockItemPath);
}

class BlockExportData {
    CGameCtnBlockInfo@ block;
    string blockFolder;
    string blockItemPath;
    string blockFileExportPath;

    BlockExportData() {}
    BlockExportData(CGameCtnBlockInfo@ block, string blockFolder) {
        @this.block = block;
        this.blockFolder = blockFolder;
        this.blockItemPath = GetBlockItemPath(blockFolder);
        this.blockFileExportPath = GetBlockFilePath(this.blockItemPath);
    }
}

bool InitializeLib() {
    @lib = GetZippedLibrary("lib/libclick.dll");

    if (lib is null) {
        warn("libclick.dll not found, exiting");
        return false;
    }

    @clickFun = lib.GetFunction("clickPos");
    @justClickFun = lib.GetFunction("click");
    @mousePosFun = lib.GetFunction("moveMouse");
    return true;
}

array<BlockExportData> FindAllBlocksInEditorInventory()
{
    auto app = GetApp();
    if (app is null) {
        warn("app is null");
        return {};
    }
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    if (editor is null) {
        warn("app.Editor is null");
        return {};
    }
    auto pmt = editor.PluginMapType;
    if (editor is null) {
        warn("editor.PluginMapType is null");
        return {};
    }
    auto inventory = pmt.Inventory;
    if (inventory is null) {
        warn("pmt.Inventory is null");
        return {};
    }
    
    if (inventory.RootNodes.Length == 0) {
        warn("inventory.RootNodes is empty");
        return {};
    }
    auto blocksNode = cast<CGameCtnArticleNodeDirectory@>(inventory.RootNodes[0]);
    auto blocks = FindAllBlocks(blocksNode);
    return blocks;
}

array<BlockExportData> FindAllBlocks(CGameCtnArticleNodeDirectory@ parentNode, string folder = "")
{
    array<BlockExportData> blocks;
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

void CreateBlockItems() {
    bool initLib = InitializeLib();
    if(!initLib) return;

    screenHeight = Draw::GetHeight();
    screenWidth = Draw::GetWidth();

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    auto pmt = editor.PluginMapType;
    auto inventory = pmt.Inventory;

    // ClearMap();

    auto blocksNode = cast<CGameCtnArticleNodeDirectory@>(inventory.RootNodes[0]);
    totalBlocks = CountBlocks(blocksNode);
    ExploreNode(blocksNode);
}

void ExploreNode(CGameCtnArticleNodeDirectory@ parentNode, string folder = "") {
    for(uint i = 0; i < parentNode.ChildNodes.Length; i++) {
        auto node = parentNode.ChildNodes[i];
        if(node.IsDirectory) {
            ExploreNode(cast<CGameCtnArticleNodeDirectory@>(node), folder + node.Name + '/');
        } else {
            auto ana = cast<CGameCtnArticleNodeArticle@>(node);
            if(ana.Article is null || ana.Article.IdName.ToLower().EndsWith("customblock")) {
                warn("Block: " + ana.Name + " is not nadeo, skipping");
                continue;
            }
            string itemLoc = 'Nadeo/' + folder + ana.Name + '.Item.Gbx';
            count++;
            auto fullItemPath = IO::FromUserGameFolder("Items/" + itemLoc);
            if(IO::FileExists(fullItemPath)) {
                print("item: " + itemLoc + ", already exists!");
                // MyYield();
            } else {
                auto block = cast<CGameCtnBlockInfo@>(ana.Article.LoadedNod);
                if(block is null) {
                    warn("Block " + ana.Name + " is null!");
                    continue;
                }
                if(string(block.Name).ToLower().Contains("water")) {
                    warn("Water can't be converted!");
                    continue;
                }
                bool blacklisted = false;
                for(uint i = 0; i < blacklist.Length; i++) {
                    if(block.Name.Contains(blacklist[i])) {
                        blacklisted = true;
                        break;
                    }
                }
                if(blacklisted) {
                    warn(block.Name + " not converting, is blacklisted");
                    continue;
                }
                print("Converting block: " + block.Name + " " + count + " / " + totalBlocks);
                ConvertBlockToItem(block, itemLoc);
            }
        }
    }
}

int2 iconButton = int2(594, 557);
int2 iconDirectionButton = int2(1311, 736);

void ConvertBlockToItem(CGameCtnBlockInfo@ block, string desiredItemLocation) {
    // Click screen at position to enter "create new item" UI
    auto xClick = screenWidth / 2;
    auto yClick = screenHeight / 2;

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    auto pmt = editor.PluginMapType;
    auto placeLocation = int3(20, 15, 20);
    MyYield();
    pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
    MyYield();
    @pmt.CursorBlockModel = block;
    int nBlocks = pmt.Blocks.Length;
    while(nBlocks == pmt.Blocks.Length) {
        clickFun.Call(true, xClick, yClick);
        MyYield();
    }
    // pmt.PlaceBlock_NoDestruction(block, placeLocation, CGameEditorPluginMap::ECardinalDirections::North);
    editor.ButtonItemCreateFromBlockModeOnClick();
    MyYield();
    while(cast<CGameEditorItem>(app.Editor) is null) {
        @editor = cast<CGameCtnEditorCommon@>(app.Editor);
        if(editor !is null && editor.PickedBlock !is null && editor.PickedBlock.BlockInfo.IdName == block.IdName) {
            justClickFun.Call(true);
        }
        MyYield();
    }
    auto editorItem = cast<CGameEditorItem@>(app.Editor);
    editorItem.PlacementParamGridHorizontalSize = 32;
    editorItem.PlacementParamGridVerticalSize = 8;
    editorItem.PlacementParamFlyStep = 8;

    ClickPos(iconButton);
    MyYield();
    ClickPos(iconDirectionButton);
    MyYield();

    editorItem.FileSaveAs();
    
    MyYield();
    
    MyYield();
    app.BasicDialogs.String = desiredItemLocation;
    
    MyYield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield();
    cast<CGameEditorItem>(app.Editor).Exit();

    while(cast<CGameCtnEditorCommon@>(app.Editor) is null) {
        MyYield();
    }
    @editor = cast<CGameCtnEditorCommon@>(app.Editor);
    @pmt = editor.PluginMapType;
    pmt.Undo();
}

void ClickPos(int2 pos) {
    int x = int(float(pos.x) / 2560. * screenWidth);
    int y = int(float(pos.y) / 1440. * screenHeight);
    clickFun.Call(true, x, y);
}

void MyYield() {
    yield();
}

Import::Library@ GetZippedLibrary(const string &in relativeDllPath) {
    bool preventCache = false;

    auto parts = relativeDllPath.Split("/");
    string fileName = parts[parts.Length - 1];
    const string baseFolder = IO::FromDataFolder('');
    const string dllFolder = baseFolder + 'lib/';
    const string localDllFile = dllFolder + fileName;

    if(!IO::FolderExists(dllFolder)) {
        IO::CreateFolder(dllFolder);
    }

    if(preventCache || !IO::FileExists(localDllFile)) {
        try {
            IO::FileSource zippedDll(relativeDllPath);
            auto buffer = zippedDll.Read(zippedDll.Size());
            IO::File toItem(localDllFile, IO::FileMode::Write);
            toItem.Write(buffer);
            toItem.Close();
        } catch {
            return null;
        }
    }

    return Import::GetLibrary(localDllFile);
}


int CountBlocks(CGameCtnArticleNodeDirectory@ parentNode) {
    int count = 0;
    for(uint i = 0; i < parentNode.ChildNodes.Length; i++) {
        auto node = parentNode.ChildNodes[i];
        if(node.IsDirectory) {
            count += CountBlocks(cast<CGameCtnArticleNodeDirectory@>(node));
        } else {
            count++;
        }
    }
    return count;
}

void ClearMap() {
    auto editor = Editor();
    if(editor is null) return;    
    editor.PluginMapType.RemoveAllBlocks();
    // there may be items left in the map, remove as follows:
    if(editor.Challenge.AnchoredObjects.Length > 0) {
        auto placeMode = editor.PluginMapType.PlaceMode;
        CutMap();
        editor.PluginMapType.PlaceMode = placeMode;
    }
}

bool CutMap() {
    auto editor = Editor();
    if(editor is null) return false;
    editor.PluginMapType.CopyPaste_SelectAll();
    if(editor.PluginMapType.CopyPaste_GetSelectedCoordsCount() != 0) {
        editor.PluginMapType.CopyPaste_Cut();
        return true;
    }
    return false;
}

CGameCtnEditorCommon@ Editor() {
    auto app = GetApp();
    return cast<CGameCtnEditorCommon@>(app.Editor);
}