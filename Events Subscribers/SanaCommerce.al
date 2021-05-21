codeunit 82530 "PIMX SC Subscriber"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"SC - Product Functions", 'OnBeforeGetProducts', '', true, true)]
    local procedure SCProduct_OnBeforeGetProducts(var XMLNodeBuff: Record "SC - XML Buffer (dotNET)"; var Item: Record Item; var Params: Record "SC - Parameters Collection");
    var
        publLine: Record "PIMX Publication Line";
        publHeader: Record "PIMX Publication Header";
        TempFilterList: Record "SC - Key Value" temporary;
        lock: List of [Text];
        i: Integer;
        q: Query "PIMX SC Items or Groups";
    begin
        if not publHeader.GetByExternalCode(Params.WebsiteId) then
            exit;
        Params.GetFilterList(TempFilterList);
        if not TempFilterList.Get('SC Last Date/Time Modified') then begin
            Session.LogMessage('PIMXSC02', 'Publication ' + Params.WebsiteId, Verbosity::Normal, DataClassification::EndUserPseudonymousIdentifiers, TelemetryScope::All, 'filter', format(TempFilterList.Count()));
            exit;
        end;

        for i := 1 to 2 do begin
            q.SetRange(item_Zeilenart, publLine.Zeilenart::Artikel); //
            q.SetRange(item_Code, publHeader.Code);
            case i of
                1:
                    q.SetFilter(data_Data_Updated_On, TempFilterList.Value);
                2:
                    q.SetFilter(item_Data_Updated_On, TempFilterList.Value);
            end;
            if q.Open() then
                while q.Read() do
                    if not lock.Contains(q.item_Nummer) then begin
                        Item.SetRange("No.", q.item_Nummer);
                        if Item.FINDFIRST() then
                            Item.Mark(true);
                        lock.Add(q.item_Nummer);
                    end;
            item.SetRange("No.");
        end;
        Session.LogMessage('PIMXSC01', 'Publication ' + Params.WebsiteId, Verbosity::Normal, DataClassification::EndUserPseudonymousIdentifiers, TelemetryScope::All, 'itemQty', format(lock.Count()), 'filter', TempFilterList.Value);
        Params.IndexRecords := 0;
    end;
}