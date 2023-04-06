
Import::Library@ lib = null;
Import::Function@ clickFun = null;
Import::Function@ mousePosFun = null;
Import::Function@ justClickFun = null;

// blacklist include terms, these cause crashes
string[] blacklist = {"GateSpecialTurbo", "GateSpecialBoost"};

int screenWidth = 1;
int screenHeight = 1;

int2 ICON_BUTTON_POS = int2(594, 557);
int2 ICON_DIRECTION_BUTTON_POS = int2(1311, 736);

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

void ClickPos(int2 pos) {
    int x = int(float(pos.x) / 2560. * screenWidth);
    int y = int(float(pos.y) / 1440. * screenHeight);
    clickFun.Call(true, x, y);
}

bool InitializeBlockExporter() {
    screenHeight = Draw::GetHeight();
    screenWidth = Draw::GetWidth();
    
    return InitializeLib();
}

array<BlockExportData@> FindAllBlocksInEditorInventory()
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

class ConvertBlockToItemHandle {
    BlockExportData blockExportData;
}

void ConvertBlockToItemCoroutine(ref@ refHandle) {
    ConvertBlockToItemHandle handle = cast<ConvertBlockToItemHandle>(refHandle);
    ConvertBlockToItem(handle.blockExportData);
}

void ConvertBlockToItem(BlockExportData blockExportData) {
    CGameCtnBlockInfo@ block = blockExportData.block;
    string desiredItemLocation = blockExportData.blockFileExportPath;
    
    // Click screen at position to enter "create new item" UI
    auto xClick = screenWidth / 2;
    auto yClick = screenHeight / 2;
    print("Clicking at: " + xClick + ", " + yClick);

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    auto pmt = editor.PluginMapType;
    auto placeLocation = int3(20, 15, 20);

    MyYield("Setting place mode to block");
    pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;

    MyYield("Setting cursor block model");
    @pmt.CursorBlockModel = block;
    int nBlocks = pmt.Blocks.Length;
    while(nBlocks == pmt.Blocks.Length) {
        clickFun.Call(true, xClick, yClick);
        MyYield("Waiting for block to be placed");
    }

    // pmt.PlaceBlock_NoDestruction(block, placeLocation, CGameEditorPluginMap::ECardinalDirections::North);
    MyYield("Block placed, attempting to click button open item editor UI");

    // TODO: Checking for error of "Can't convert this block into a custom block." can be caught
    // In app.ActiveMenus, the menus go from 0 to 1 if this error appears. So we can check 
    // the first menu and look for the string "Can't convert this block into a custom block." or some ID

    editor.ButtonItemCreateFromBlockModeOnClick();
    while (cast<CGameEditorItem>(app.Editor) is null) {
        @editor = cast<CGameCtnEditorCommon@>(app.Editor);
        if (editor !is null && editor.PickedBlock !is null && editor.PickedBlock.BlockInfo.IdName == block.IdName) {
            // justClickFun.Call(true);
            clickFun.Call(true, xClick + Math::Rand(-10.0, 10.0), yClick + Math::Rand(-10.0, 10.0));
        }
        MyYield("Waiting for item editor UI to open");
    }

    auto editorItem = cast<CGameEditorItem@>(app.Editor);
    editorItem.PlacementParamGridHorizontalSize = 32;
    editorItem.PlacementParamGridVerticalSize = 8;
    editorItem.PlacementParamFlyStep = 8;

    MyYield("Clicking icon button");

    // Click icon button
    // Old code, click pos:
    // ClickPos(ICON_BUTTON_POS);    
    // TODO: Add more error catching and early aborts for the following code:
    CControlFrame@ frameClassEditor = cast<CControlFrame>(editorItem.FrameRoot.Childs[4]);
    CControlFrame@ framePropertiesContainer = cast<CControlFrame>(frameClassEditor.Childs[1]);
    CControlFrame@ frameProperties = cast<CControlFrame>(framePropertiesContainer.Childs[0]);
    CControlListCard@ listCardProperties = cast<CControlListCard>(frameProperties.Childs[1]);
    for (uint i = 0; i < listCardProperties.ListCards.Length; i++) {
        CControlFrame@ frame = cast<CControlFrame>(listCardProperties.ListCards[i]);
        if (frame.Childs.Length == 6) {
            CControlLabel@ label = cast<CControlLabel>(frame.Childs[0]);
            if (label.Label == "|ItemProperty|Icon") {
                CControlFrame@ cardParamNod = cast<CControlFrame>(frame.Childs[5]);
                CControlButton@ buttonNew = cast<CControlButton>(cardParamNod.Childs[3]);
                buttonNew.OnAction();
                break;
            }
        }
    }

    MyYield("Clicking direction button");

    // Click direction button
    // Old code, click pos:
    // ClickPos(ICON_DIRECTION_BUTTON_POS);

    while (app.ActiveMenus.Length == 0) {
        MyYield("Waiting for dialog to open");
    }

    // TODO: Add more error catching for the following code:
    CGameMenu@ activeMenus = app.ActiveMenus[0];
    CGameMenuFrame@ currentFrame = activeMenus.CurrentFrame;
    CControlFrame@ frameContent = cast<CControlFrame>(currentFrame.Childs[0]);
    CControlFrame@ frameDialog = cast<CControlFrame>(frameContent.Childs[0]);
    CControlGrid@ gridButtons = cast<CControlGrid>(frameDialog.Childs[2]);
    CGameControlCardGeneric@ button1 = cast<CGameControlCardGeneric>(gridButtons.Childs[1]);
    CControlButton@ buttonSelection = cast<CControlButton>(button1.Childs[0]);
    buttonSelection.OnAction();

    MyYield("Clicking Save As button");

    editorItem.FileSaveAs();
    
    MyYield("Setting desired item save location at: " + desiredItemLocation);
    print("Before: " + app.BasicDialogs.String);
    while (app.BasicDialogs.String == "") {
        MyYield("Waiting for dialog to open");
    }
    
    app.BasicDialogs.String = desiredItemLocation;
    print("After: " + app.BasicDialogs.String);
   
    while (app.BasicDialogs.String != desiredItemLocation) {
        MyYield("Waiting for dialog to update path");
    }

    MyYield("Click Save As button");
    MyYield("Click Save As button");

    MyYield("Click Save As button");
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield("Click Save As button");
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield("Exiting item editor");
    cast<CGameEditorItem>(app.Editor).Exit();

    while(cast<CGameCtnEditorCommon@>(app.Editor) is null) {
        MyYield("Waiting to exit item editor");
    }

    MyYield("Undo block placement");
    @editor = cast<CGameCtnEditorCommon@>(app.Editor);
    @pmt = editor.PluginMapType;
    pmt.Undo();
}


void MyYield() {
    yield();
}
void MyYield(string msg) {
    print("Yield Msg: " + msg);
    MyYield();
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