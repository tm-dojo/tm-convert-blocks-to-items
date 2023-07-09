void PreloadItemFIDs() {
    auto items = FindAllItemsInEditorInventory();  
    for (uint i = 0; i < items.Length; i++) {
        auto item = items[i];
        auto article = cast<CGameCtnArticle>(item.ArticlePtr);

        if (article is null) {
            warn("Block " + item.Name + " has no article");
            UI::ShowNotification(
                "Failed to preload item: " + (i + 1) + "/" + items.Length, 
                5000
            );
            continue;
        }

        Fids::Preload(article.CollectorFid);

        UI::ShowNotification(
            "Preloaded item: " + (i + 1) + "/" + items.Length, 
            1000
        );
    }
}

void PreloadBlockFIDs() {
    blocks = FindAllBlocksInEditorInventory();
    for (uint i = 0; i < blocks.Length; i++) {
        auto block = blocks[i].block;
        auto article = cast<CGameCtnArticle>(block.ArticlePtr);

        if (article is null) {
            warn("Block " + block.Name + " has no article");
            UI::ShowNotification(
                "Failed to preload block: " + (i + 1) + "/" + blocks.Length + " (" + block.Name + ")", 
                5000
            );
            continue;
        }

        Fids::Preload(article.CollectorFid);

        UI::ShowNotification(
            "Preloaded block: " + (i + 1) + "/" + blocks.Length, 
            1000
        );
    }
}