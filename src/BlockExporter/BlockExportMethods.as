
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

bool abortExporting = false;

array<vec3> POTENTIAL_CAMERA_SETTINGS = {
    vec3(Math::ToRad(45), Math::ToRad(45), 20),
    vec3(Math::ToRad(135), Math::ToRad(45), 20),
    vec3(Math::ToRad(225), Math::ToRad(45), 20),
    vec3(Math::ToRad(315), Math::ToRad(45), 20),
    vec3(Math::ToRad(0),   Math::ToRad(90), 20),
    vec3(Math::ToRad(90),  Math::ToRad(90), 20),
    vec3(Math::ToRad(180), Math::ToRad(90), 20),
    vec3(Math::ToRad(270), Math::ToRad(90), 20),
    vec3(Math::ToRad(0),   Math::ToRad(0), 20),
    vec3(Math::ToRad(90),  Math::ToRad(0), 20),
    vec3(Math::ToRad(180), Math::ToRad(0), 20),
    vec3(Math::ToRad(270), Math::ToRad(0), 20)
};

void SetCamSetting(CGameEditorPluginMapMapType@ pmt, vec3 camSetting) {    
    pmt.CameraHAngle = camSetting.x;
    pmt.CameraVAngle = camSetting.y;
    pmt.CameraToTargetDistance = camSetting.z;
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

class ConvertMultipleBlockToItemCoroutineHandle {
    array<BlockExportData@> blocks;
    bool moveMouseManually = false;
}
void ConvertMultipleBlockToItemCoroutine(ref@ refHandle) {
    ConvertMultipleBlockToItemCoroutineHandle handle = cast<ConvertMultipleBlockToItemCoroutineHandle>(refHandle);
    // TODO: Use queueing system to convert blocks
    for (uint i = 0; i < handle.blocks.Length; i++) {
        try {
            ConvertBlockToItem(handle.blocks[i], handle.moveMouseManually);
            
            handle.blocks[i].exported = ConfirmBlockExport(handle.blocks[i]);
            handle.blocks[i].errorMessage = "";
        } catch {
            string exception = getExceptionInfo();
            if (!IsBlockException(exception)) {
                throw(exception);
            }
            
            string blockExceptionMessage = RemoveBlockExceptionPrefix(exception);
            error("Block export failed: " + blockExceptionMessage);

            handle.blocks[i].exported = false;
            handle.blocks[i].errorMessage = blockExceptionMessage;
        }
        
        // Notify block export tree that block has changed
        blockExportTree.NotifyBlockChange(handle.blocks[i]);

        UI::ShowNotification(
            "Exported block: " + (i + 1) + "/" + handle.blocks.Length + " (press " + tostring(ABORT_KEY) + " to abort)", 
            1000
        );

        if (abortExporting) {
            UI::ShowNotification("Stopped exporting blocks", 5000);
            abortExporting = false;
            break;
        }
    }
}

class ConvertBlockToItemCoroutineHandle {
    BlockExportData@ blockExportData;
}
void ConvertBlockToItemCoroutine(ref@ refHandle) {
    ConvertBlockToItemCoroutineHandle handle = cast<ConvertBlockToItemCoroutineHandle>(refHandle);
    ConvertBlockToItem(handle.blockExportData);
}

void ConvertBlockToItem(BlockExportData@ blockExportData, bool moveMouseManually = false) {
    CGameCtnBlockInfo@ block = blockExportData.block;
    string desiredItemLocation = blockExportData.blockFileExportPath;

    // ThrowBlockException("Failed to click block");
    
    // Click screen at position to enter "create new item" UI
    auto xClick = screenWidth / 2;
    auto yClick = screenHeight / 2;
    print("Clicking at: " + xClick + ", " + yClick);

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    auto pmt = editor.PluginMapType;
    

    MyYield("Removing all blocks");
    pmt.RemoveAll();

    MyYield("Placing ghost block");
    auto placeLocation = int3(20, 20, 20);
    pmt.PlaceGhostBlock(block, placeLocation, CGameEditorPluginMap::ECardinalDirections::North);

    MyYield("Block placed, attempting to click button open item editor UI");
    // TODO: Checking for error of "Can't convert this block into a custom block." can be caught
    // In app.ActiveMenus, the menus go from 0 to 1 if this error appears. So we can check 
    // the first menu and look for the string "Can't convert this block into a custom block." or some ID
    if (pmt.EditMode != CGameEditorPluginMap::EditMode::Pick) {
        editor.ButtonItemCreateFromBlockModeOnClick();
    }

    MyYield("Setting up camera");
    pmt.CameraTargetPosition = vec3(655, 98, 655);
    int curCamIndex = 0;

    MyYield("Waiting for picked block to be the correct block");
    auto startBlockPick = Time::Now;
    while (editor.PickedBlock is null || editor.PickedBlock.BlockModel.Id.GetName() != block.Id.GetName()) {
        if (!moveMouseManually) {
            MyYield("Trying camera angle " + (curCamIndex + 1));
            vec3 curCamSetting = POTENTIAL_CAMERA_SETTINGS[curCamIndex];
            SetCamSetting(pmt, curCamSetting);
            curCamIndex = (curCamIndex + 1) % POTENTIAL_CAMERA_SETTINGS.Length;
            
            mousePosFun.Call(xClick, yClick);
            sleep(10);
            mousePosFun.Call(xClick + 5, yClick);
            sleep(10);
            mousePosFun.Call(xClick + 10, yClick);
        }
        // Change time limit depending on whether we are moving the mouse manually
        auto timeLimit = moveMouseManually ? TIME_TO_PICK_BLOCK_MANUAL : TIME_TO_PICK_BLOCK;
        if (Time::Now - startBlockPick > timeLimit) {
            ThrowBlockException("Failed to pick block in time (" + TIME_TO_PICK_BLOCK + "ms)");
        }
        MyYield("Waiting for picked block to be the correct block");
    }

    MyYield("Waiting for item editor UI to open");
    auto startOpenItemEditor = Time::Now;
    while (cast<CGameEditorItem>(app.Editor) is null) {
        @editor = cast<CGameCtnEditorCommon@>(app.Editor);
        if (editor !is null && editor.PickedBlock !is null && editor.PickedBlock.BlockModel.Id.GetName() == block.Id.GetName()) {
            justClickFun.Call(true);
        }
        if (Time::Now - startOpenItemEditor > TIME_TO_OPEN_ITEM_EDITOR) {
            ThrowBlockException("Failed to open item editor in time (" + TIME_TO_OPEN_ITEM_EDITOR + "ms)");
        }
        // This is most likely the "Cannot convert this block into an item." error, abort
        if (app.ActiveMenus.Length > 0) {
            MyYield("Cannot convert this block to an item, aborting...");
            MyYield("Clicking OK on error dialog");
            app.BasicDialogs.Message_Ok();
            MyYield("Removing all blocks");
            pmt.RemoveAll();
            ThrowBlockException("Cannot convert this block into an item");
        }
        MyYield("Waiting for item editor UI to open");
    }

    auto editorItem = cast<CGameEditorItem@>(app.Editor);

    // Rough failsafe to abort if a grass model is detected
    if (editorItem.ItemModel !is null && editorItem.ItemModel.EntityModelEdition !is null) {
        auto itemModelEdition = cast<CGameCommonItemEntityModelEdition>(editorItem.ItemModel.EntityModelEdition);
        if (itemModelEdition !is null) {
            auto meshCrystal = itemModelEdition.MeshCrystal;
            if (meshCrystal.CrystalEdgeCount == 12 &&
                meshCrystal.CrystalVertexCount == 9 &&
                meshCrystal.CrystalFaceCount == 4) {
                // A model with these properties is most likely a grass model, abort export                
                MyYield("Aborting export - grass model detected");
                cast<CGameEditorItem>(app.Editor).Exit();

                MyYield("Aborting export - Waiting for confirm dialog to open");
                while (app.ActiveMenus.Length == 0) {
                    MyYield("Waiting for confirm dialog to open");
                }    

                MyYield("Aborting export - Waiting for item editor to exit");
                while(cast<CGameCtnEditorCommon@>(app.Editor) is null) {
                    MyYield("Aborting export - Waiting for item editor to exit");
                    GetApp().BasicDialogs.AskYesNo_No();
                }
                

                MyYield("Aborting export - Remove all blocks");
                @editor = cast<CGameCtnEditorCommon@>(app.Editor);
                @pmt = editor.PluginMapType;
                pmt.RemoveAll();
                return;
            }
        }
    }

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

    MyYield("Waiting for dialog to open");
    while (app.ActiveMenus.Length == 0) {
        MyYield("Waiting for dialog to open");
    }

    MyYield("Clicking direction button");
    // TODO: Add more error catching for the following code:
    CGameMenu@ activeMenus = app.ActiveMenus[0];
    CGameMenuFrame@ currentFrame = activeMenus.CurrentFrame;
    CControlFrame@ frameContent = cast<CControlFrame>(currentFrame.Childs[0]);
    CControlFrame@ frameDialog = cast<CControlFrame>(frameContent.Childs[0]);
    CControlGrid@ gridButtons = cast<CControlGrid>(frameDialog.Childs[2]);
    CGameControlCardGeneric@ button1 = cast<CGameControlCardGeneric>(gridButtons.Childs[1]);
    CControlButton@ buttonSelection = cast<CControlButton>(button1.Childs[0]);
    buttonSelection.OnAction();

    MyYield("Clicking Item Save As button");
    editorItem.FileSaveAs();
    
    MyYield("Waiting for save as dialog to open");
    while (app.BasicDialogs.String == "" || app.ActiveMenus.Length == 0) {
        MyYield("Waiting for save as dialog to open");
    }

    MyYield("Setting desired item save location at: " + desiredItemLocation);    
    // This will save the item to  User/Trackmania2020/Items/ + the desiredItemLocation
    app.BasicDialogs.String = desiredItemLocation;
   
    MyYield("Waiting for dialog to update path");
    while (app.BasicDialogs.String != desiredItemLocation) {
        MyYield("Waiting for dialog to update path");
    }

    MyYield("Click Save As button");
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield("Click Save As button (confirm overwrite)");
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield("Exiting item editor");
    cast<CGameEditorItem>(app.Editor).Exit();

    MyYield("Waiting for item editor to exit");
    while(cast<CGameCtnEditorCommon@>(app.Editor) is null) {
        MyYield("Waiting for item editor to exit");
    }

    MyYield("Remove all blocks");
    @editor = cast<CGameCtnEditorCommon@>(app.Editor);
    @pmt = editor.PluginMapType;
    pmt.RemoveAll();
}


class PlaceAndRemoveBlocksCoroutineHandle {
    array<BlockExportData@> blocks;
}
void PlaceAndRemoveBlocksCoroutine(ref@ refHandle) {
    PlaceAndRemoveBlocksCoroutineHandle handle = cast<PlaceAndRemoveBlocksCoroutineHandle>(refHandle);

    auto blocks = handle.blocks;

    for (uint i = 0; i < blocks.Length; i++) {
        PlaceAndRemoveBlock(blocks[i]);

        UI::ShowNotification(
            "Placed block: " + (i + 1) + "/" + handle.blocks.Length, 
            1000
        );
    }
}

void PlaceAndRemoveBlock(BlockExportData@ blockExportData) {
    CGameCtnBlockInfo@ block = blockExportData.block;

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    auto pmt = editor.PluginMapType;    

    MyYield("Clearing all blocks before placing");
    pmt.RemoveAll();

    uint blocksBefore = editor.Challenge.Blocks.Length;

    MyYield("Placing ghost block: " + block.IdName);
    auto placeLocation = int3(20, 20, 20);
    pmt.PlaceGhostBlock(block, placeLocation, CGameEditorPluginMap::ECardinalDirections::North);

    MyYield("Block placed: " + block.IdName);
    while(editor.Challenge.Blocks.Length == blocksBefore) {
        MyYield("Waiting for block to be placed");
    }

    MyYield("Removing all blocks after placing");
    pmt.RemoveAll();
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

bool ConfirmBlockExport(BlockExportData@ block) {
    string path = IO::FromUserGameFolder("Items/" + block.blockFileExportPath);
    return IO::FileExists(path);
}